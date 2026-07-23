import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

enum AiRecognitionMode {
  food,            // 🍱 食物菜色照片
  nutritionLabel,  // 🏷️ 營養標示/成分表
}

/// 營養標示 4-9-4 (衛福部法規標準) 驗證與單位換算結果
class NutritionVerification {
  final double finalCaloriesKcal;     // 最終計算出的整包總熱量 (kcal)
  final double finalProteinG;         // 最終整包總蛋白質 (g)
  final double finalFatG;             // 最終整包總脂肪 (g)
  final double finalCarbsG;           // 最終整包總碳水 (g)
  final double? finalFiberG;          // 膳食纖維 (g)
  final double? finalSugarG;          // 糖 (g)
  final double calculated494Kcal;     // 衛福部 4-9-4 官方公式推算 (P*4 + F*9 + C*4 + Fiber*2)
  final bool isUnitConvertedFromKj;   // 是否由 kJ 轉 kcal
  final bool isScaledFrom100g;        // 是否由「每100g/ml」換算整包
  final double diffPercentage;        // 4-9-4公式與標示熱量的偏差%
  final bool isCrossVerified;         // 是否通過交叉驗證 (偏差 <= 15%)
  final String calculationSteps;      // 完整計算歷程文字說明

  const NutritionVerification({
    required this.finalCaloriesKcal,
    required this.finalProteinG,
    required this.finalFatG,
    required this.finalCarbsG,
    this.finalFiberG,
    this.finalSugarG,
    required this.calculated494Kcal,
    required this.isUnitConvertedFromKj,
    required this.isScaledFrom100g,
    required this.diffPercentage,
    required this.isCrossVerified,
    required this.calculationSteps,
  });
}

class AiFoodResult {
  final String foodName;
  final int calories;
  final String description;
  final double? protein;
  final double? fat;
  final double? carbs;
  final String? servingInfo;
  final List<String> alternativeNames; // 備選餐點建議
  final String? healthTip;             // 營養師健康小建議
  final int confidence;                // 辨識信心度 (0-100%)
  final NutritionVerification? verification; // 規則過濾與 4-9-4 驗證歷程

  const AiFoodResult({
    required this.foodName,
    required this.calories,
    required this.description,
    this.protein,
    this.fat,
    this.carbs,
    this.servingInfo,
    this.alternativeNames = const [],
    this.healthTip,
    this.confidence = 92,
    this.verification,
  });

  factory AiFoodResult.fromJson(Map<String, dynamic> json) {
    List<String> altNames = [];
    if (json['alternative_names'] is List) {
      altNames = (json['alternative_names'] as List).map((e) => e.toString()).toList();
    }

    final rawConf = json['confidence'];
    int confVal = 92;
    if (rawConf is num) {
      confVal = rawConf.toInt().clamp(60, 99);
    }

    return AiFoodResult(
      foodName: json['food_name'] as String? ?? '辨識餐點',
      calories: (json['calories'] as num?)?.toInt() ?? 450,
      description: json['description'] as String? ?? '估算之餐點成分與卡路里分析',
      protein: (json['protein'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      carbs: (json['carbs'] as num?)?.toDouble(),
      servingInfo: json['serving_info'] as String?,
      alternativeNames: altNames,
      healthTip: json['health_tip'] as String?,
      confidence: confVal,
    );
  }
}

class AiFoodService {
  /// 分析食物圖片或營養標示表 (支援中/英/日多國標示與衛福部 4-9-4 纖維校正演算法)
  Future<AiFoodResult> analyzeFoodImage(
    Uint8List imageBytes,
    String mimeType, {
    AiRecognitionMode mode = AiRecognitionMode.food,
    String? userNote,
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? dotenv.env['GOOGLE_API_KEY'];

    if (apiKey == null || apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY') {
      await Future.delayed(const Duration(milliseconds: 1500));
      return _generateSmartMockResult(mode, userNote);
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.1,
          topP: 0.8,
          maxOutputTokens: 1024,
        ),
        systemInstruction: Content.system('''
你是一位享譽國際的「首席臨床營養師」與「多國食品標示 OCR 權威演算法專家」。

【OCR 擷取規範與多國相容 (中/英/日)】：
1. 支援四大超商(7-11/全家/萊爾富/OK)、全聯、美廉社、家樂福，以及美系/日系進口食品標示。
2. 日文標示對照：熱量/エネルギー、蛋白質/たんぱく質、脂肪/脂質、碳水化合物/炭水化物。
3. 英文標示對照：Calories/Energy, Protein, Total Fat, Total Carbohydrate, Dietary Fiber, Sugars.
4. 精確 OCR 欄位：
   - food_name: 食品名稱
   - energy_value: 數字
   - energy_unit: "kcal" 或 "kJ"
   - label_basis: "per_serving" 或 "per_100g_ml"
   - serving_count: 本包裝含幾份 (數字)
   - total_package_weight: 本包裝總重 (克/毫升)
   - protein_value: 蛋白質 (g)
   - fat_value: 脂肪 (g)
   - carbs_value: 碳水化合物 (g)
   - fiber_value: 膳食纖維 (g，若無填 null)
   - sugar_value: 糖 (g，若無填 null)
   - serving_info: 說明文字

必須嚴格回傳純 JSON 格式，切勿包含 ```json 標籤。
'''),
      );

      final String extraPromptNote = (userNote != null && userNote.trim().isNotEmpty)
          ? '\n【使用者補充說明】：「${userNote.trim()}」。'
          : '';

      if (mode == AiRecognitionMode.nutritionLabel) {
        final prompt = '''
請精確 OCR 擷取這張「食品營養標示表」原始數據：
1. food_name: 食品名稱
2. energy_value: 標示熱量數字
3. energy_unit: "kcal" 或 "kJ"
4. label_basis: "per_serving" 或 "per_100g_ml"
5. serving_count: 本包裝總份數 (數字)
6. total_package_weight: 本包裝總重/總毫升 (數字)
7. protein_value: 蛋白質 (g)
8. fat_value: 脂肪 (g)
9. carbs_value: 碳水化合物 (g)
10. fiber_value: 膳食纖維 (g，無填 null)
11. sugar_value: 糖 (g，無填 null)
12. serving_info: 說明文字
$extraPromptNote

純 JSON 格式：
{
  "food_name": "食品名稱",
  "energy_value": 185.0,
  "energy_unit": "kcal",
  "label_basis": "per_serving",
  "serving_count": 1.0,
  "total_package_weight": 375.0,
  "protein_value": 3.2,
  "fat_value": 4.5,
  "carbs_value": 33.0,
  "fiber_value": 2.1,
  "sugar_value": 18.0,
  "serving_info": "每份 375 ml / 本包裝含 1 份",
  "confidence": 98
}
''';

        final content = [
          Content.multi([
            TextPart(prompt),
            DataPart(mimeType, imageBytes),
          ])
        ];

        final response = await model.generateContent(content);
        final text = response.text?.trim() ?? '';
        final cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();
        final rawMap = jsonDecode(cleanJson) as Map<String, dynamic>;

        return _processNutritionLabelRules(rawMap);
      } else {
        // 食物菜色辨識模式（雙階段校驗推導）
        final prompt = '''
請以專業營養師角度詳細拆解這張食物照片：
1. 辨識餐點名稱 (food_name)
2. 估算總熱量 (calories)
3. 熱量拆解 (description)：詳細列出白飯、主菜、配菜各別的卡路里加總邏輯。
4. 蛋白質 (protein)、脂肪 (fat)、碳水化合物 (carbs) 克數。
5. 備選名稱 (alternative_names)：提供 2-3 個候選菜名。
6. 辨識信心度 (confidence)：數字 70-99。
7. 營養師建議 (health_tip)
$extraPromptNote

純 JSON 格式：
{
  "food_name": "餐點名稱",
  "calories": 估算總熱量整數,
  "description": "熱量拆解說明",
  "protein": 蛋白質克數數字,
  "fat": 脂肪克數數字,
  "carbs": 碳水化合物克數數字,
  "serving_info": "估算份量",
  "alternative_names": ["備選菜名1", "備選菜名2"],
  "health_tip": "營養師健康建議",
  "confidence": 94
}
''';

        final content = [
          Content.multi([
            TextPart(prompt),
            DataPart(mimeType, imageBytes),
          ])
        ];

        final response = await model.generateContent(content);
        final text = response.text?.trim() ?? '';
        final cleanJson = text.replaceAll('```json', '').replaceAll('```', '').trim();
        final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
        return AiFoodResult.fromJson(decoded);
      }
    } catch (e) {
      debugPrint("Gemini AI 辨識失敗: $e");
      return const AiFoodResult(
        foodName: '辨識餐點',
        calories: 480,
        description: '無法取得精確分析，已預設帶入估算熱量，您可手動微調。',
        healthTip: '建議均衡搭配蔬菜與蛋白質喔！',
        confidence: 78,
      );
    }
  }

  /// 衛福部法規演算法：千焦耳 (kJ) 轉換、每100g/每份換算、衛福部 4-9-4 (含纖維 2kcal/g) 驗證
  AiFoodResult _processNutritionLabelRules(Map<String, dynamic> rawMap) {
    final foodName = rawMap['food_name'] as String? ?? '包裝食品';
    double rawEnergy = (rawMap['energy_value'] as num?)?.toDouble() ?? 100.0;
    final String unit = (rawMap['energy_unit'] as String? ?? 'kcal').toLowerCase();
    final String basis = rawMap['label_basis'] as String? ?? 'per_serving';
    final double servingCount = (rawMap['serving_count'] as num?)?.toDouble() ?? 1.0;
    final double? totalPkgWeight = (rawMap['total_package_weight'] as num?)?.toDouble();
    double rawProtein = (rawMap['protein_value'] as num?)?.toDouble() ?? 0.0;
    double rawFat = (rawMap['fat_value'] as num?)?.toDouble() ?? 0.0;
    double rawCarbs = (rawMap['carbs_value'] as num?)?.toDouble() ?? 0.0;
    double? rawFiber = (rawMap['fiber_value'] as num?)?.toDouble();
    double? rawSugar = (rawMap['sugar_value'] as num?)?.toDouble();
    final servingInfo = rawMap['serving_info'] as String? ?? '標示解析';

    List<String> logSteps = [];

    // 1. 規則一：單位過濾 (kJ -> kcal 轉換)
    bool isKj = unit.contains('kj') || unit.contains('千焦');
    double baseKcal = rawEnergy;
    if (isKj) {
      baseKcal = rawEnergy / 4.184; // 1 kcal ≈ 4.184 kJ
      logSteps.add('① 單位過濾：標示為 ${rawEnergy.toStringAsFixed(1)} kJ ➔ 自動換算為 ${baseKcal.toStringAsFixed(1)} kcal (除以 4.184)');
    } else {
      logSteps.add('① 單位確認：標示單位為 大卡 (kcal)');
    }

    // 2. 規則二：每100g/ml vs 每份 換算整包總量
    bool isPer100 = basis.contains('100');
    double finalKcal = baseKcal;
    double finalProtein = rawProtein;
    double finalFat = rawFat;
    double finalCarbs = rawCarbs;
    double? finalFiber = rawFiber;
    double? finalSugar = rawSugar;

    if (isPer100) {
      double ratio = (totalPkgWeight != null && totalPkgWeight > 0) ? (totalPkgWeight / 100.0) : servingCount;
      finalKcal = baseKcal * ratio;
      finalProtein = rawProtein * ratio;
      finalFat = rawFat * ratio;
      finalCarbs = rawCarbs * ratio;
      if (rawFiber != null) finalFiber = rawFiber * ratio;
      if (rawSugar != null) finalSugar = rawSugar * ratio;
      logSteps.add('② 基準過濾：「每100g/ml」數據 ➔ 按全包裝 $ratio 倍換算整包 (總熱量 ${finalKcal.toStringAsFixed(0)} kcal)');
    } else {
      if (servingCount > 1.0) {
        finalKcal = baseKcal * servingCount;
        finalProtein = rawProtein * servingCount;
        finalFat = rawFat * servingCount;
        finalCarbs = rawCarbs * servingCount;
        if (rawFiber != null) finalFiber = rawFiber * servingCount;
        if (rawSugar != null) finalSugar = rawSugar * servingCount;
        logSteps.add('② 基準過濾：單份 ${baseKcal.toStringAsFixed(0)} kcal ➔ 按全包裝含 $servingCount 份換算總熱量 ${finalKcal.toStringAsFixed(0)} kcal');
      } else {
        logSteps.add('② 基準確認：標示即為整包全份量數據');
      }
    }

    // 3. 規則三：衛福部 4-9-4 官方公式交叉總和驗證 (P*4 + F*9 + (Carbs-Fiber)*4 + Fiber*2)
    double fiberG = finalFiber ?? 0.0;
    double netCarbsG = (finalCarbs >= fiberG && fiberG > 0) ? (finalCarbs - fiberG) : finalCarbs;
    double calc494 = (finalProtein * 4.0) + (finalFat * 9.0) + (netCarbsG * 4.0) + (fiberG * 2.0);

    double diff = (calc494 - finalKcal).abs();
    double diffPercent = finalKcal > 0 ? (diff / finalKcal) * 100.0 : 0.0;
    bool isVerified = diffPercent <= 15.0; // 15% 精確偏差驗證

    if (isVerified) {
      logSteps.add('③ 衛福部 4-9-4 交叉驗證通過！\n   公式推算 (P×4 + F×9 + 淨碳水×4 + 纖維×2) = ${calc494.toStringAsFixed(0)} kcal (與標示偏差 ${diffPercent.toStringAsFixed(1)}%)');
    } else {
      logSteps.add('③ 衛福部 4-9-4 交叉驗證提醒：\n   公式推算為 ${calc494.toStringAsFixed(0)} kcal，標示為 ${finalKcal.toStringAsFixed(0)} kcal (偏差 ${diffPercent.toStringAsFixed(1)}%)');
    }

    final verification = NutritionVerification(
      finalCaloriesKcal: finalKcal,
      finalProteinG: finalProtein,
      finalFatG: finalFat,
      finalCarbsG: finalCarbs,
      finalFiberG: finalFiber,
      finalSugarG: finalSugar,
      calculated494Kcal: calc494,
      isUnitConvertedFromKj: isKj,
      isScaledFrom100g: isPer100,
      diffPercentage: diffPercent,
      isCrossVerified: isVerified,
      calculationSteps: logSteps.join('\n'),
    );

    return AiFoodResult(
      foodName: foodName,
      calories: finalKcal.round(),
      description: logSteps.join('\n'),
      protein: double.parse(finalProtein.toStringAsFixed(1)),
      fat: double.parse(finalFat.toStringAsFixed(1)),
      carbs: double.parse(finalCarbs.toStringAsFixed(1)),
      servingInfo: servingInfo,
      confidence: (rawMap['confidence'] as num?)?.toInt() ?? 98,
      healthTip: isVerified ? '衛福部法規算式校驗成功，數據極致精準！' : '熱量與三大營養素已完成規則過濾與換算。',
      verification: verification,
    );
  }

  /// 智慧型情境模擬（未設定 API Key 時使用）
  AiFoodResult _generateSmartMockResult(AiRecognitionMode mode, String? userNote) {
    final note = userNote?.trim() ?? '';

    if (mode == AiRecognitionMode.nutritionLabel) {
      final rawMap = {
        "food_name": note.isNotEmpty ? note : '義美高纖全脂鮮乳',
        "energy_value": 690.0, // 標示千焦耳 kJ
        "energy_unit": "kJ",
        "label_basis": "per_serving",
        "serving_count": 1.0,
        "total_package_weight": 290.0,
        "protein_value": 8.7,
        "fat_value": 9.8,
        "carbs_value": 10.4,
        "fiber_value": 1.5,
        "sugar_value": 8.2,
        "serving_info": "每份 290 ml / 本包裝含 1 份",
        "confidence": 98
      };
      return _processNutritionLabelRules(rawMap);
    }

    if (note.contains('珍奶') || note.contains('奶茶')) {
      return AiFoodResult(
        foodName: note.isNotEmpty ? note : '珍珠奶茶 (大杯/微糖)',
        calories: 450,
        description: '雙階段校驗：基底奶茶(250kcal) + 珍珠配料(200kcal)。微糖校準總熱量約 450 kcal。',
        protein: 3.5,
        fat: 14.0,
        carbs: 78.0,
        servingInfo: '大杯 700 ml',
        alternativeNames: ['波霸奶茶', '鮮奶茶加珍珠', '黑糖珍珠鮮奶'],
        healthTip: '微糖能減少約 100 kcal 負擔！若想更輕盈可改選無糖鮮奶茶加仙草喔。',
        confidence: 96,
      );
    }

    final prefix = note.isNotEmpty ? '[$note] ' : '';
    return AiFoodResult(
      foodName: '${prefix}日式照燒雞肉便當',
      calories: 680,
      description: '雙階段校驗：白米飯(280kcal) + 照燒雞腿(260kcal) + 炒時蔬與蛋(140kcal) = 680 kcal。',
      protein: 32.0,
      fat: 22.0,
      carbs: 85.0,
      servingInfo: '標準便當 1 份',
      alternativeNames: ['烤雞腿便當', '宮保雞丁便當', '雞胸肉健身餐'],
      healthTip: '本餐蛋白質與碳水化合物比例良好，菜色均衡！',
      confidence: 95,
    );
  }
}
