import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiFoodResult {
  final String foodName;
  final int calories;
  final String description;

  const AiFoodResult({
    required this.foodName,
    required this.calories,
    required this.description,
  });

  factory AiFoodResult.fromJson(Map<String, dynamic> json) {
    return AiFoodResult(
      foodName: json['food_name'] as String? ?? '辨識出的美食',
      calories: (json['calories'] as num?)?.toInt() ?? 350,
      description: json['description'] as String? ?? '估算之餐點成分與卡路里',
    );
  }
}

class AiFoodService {
  /// 分析食物圖片並估算卡路里
  Future<AiFoodResult> analyzeFoodImage(Uint8List imageBytes, String mimeType) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? dotenv.env['GOOGLE_API_KEY'];

    // 若未設定 API Key，使用模擬分析模式 (確保沒有 Key 也能體驗完整 UI 流程)
    if (apiKey == null || apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY') {
      await Future.delayed(const Duration(seconds: 2));
      return const AiFoodResult(
        foodName: '日式雞肉便當 (AI範例)',
        calories: 680,
        description: '內含烤雞腿、白米飯、溏心蛋與炒時蔬，估算熱量約 680 kcal。',
      );
    }

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      const prompt = '''
請分析這張食物照片，辨識出餐點名稱與估算卡路里熱量 (kcal)。
請嚴格以繁體中文且「純 JSON 格式」回應（勿包含 markdown 程式碼區塊符號如 ```json）：
{
  "food_name": "餐點名稱",
  "calories": 數字,
  "description": "簡短成分描述"
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

      // 清理可能包含的 markdown json 標籤
      final cleanJson = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final decoded = jsonDecode(cleanJson) as Map<String, dynamic>;
      return AiFoodResult.fromJson(decoded);
    } catch (e) {
      debugPrint("Gemini AI 辨識失敗: $e");
      // 異常時備用降級處理
      return const AiFoodResult(
        foodName: '辨識餐點',
        calories: 500,
        description: '無法取得精確分析，已預設帶入 500 kcal，您可自行手動微調。',
      );
    }
  }
}
