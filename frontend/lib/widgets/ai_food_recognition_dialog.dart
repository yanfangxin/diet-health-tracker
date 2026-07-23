import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/food_log.dart';
import '../services/ai_food_service.dart';

class AiFoodRecognitionDialog extends StatefulWidget {
  final String dateStr;
  final Future<void> Function(FoodLog foodLog) onSave;

  const AiFoodRecognitionDialog({
    super.key,
    required this.dateStr,
    required this.onSave,
  });

  @override
  State<AiFoodRecognitionDialog> createState() => _AiFoodRecognitionDialogState();
}

class _AiFoodRecognitionDialogState extends State<AiFoodRecognitionDialog> {
  final ImagePicker _picker = ImagePicker();
  final AiFoodService _aiService = AiFoodService();

  AiRecognitionMode _mode = AiRecognitionMode.food;
  Uint8List? _imageBytes;
  String _imageMime = 'image/jpeg';

  bool _isAnalyzing = false;
  bool _isSaving = false;

  final _userNoteController = TextEditingController();
  final _foodNameController = TextEditingController();
  final _caloriesController = TextEditingController();

  String _description = '';
  double? _protein;
  double? _fat;
  double? _carbs;
  String? _servingInfo;
  List<String> _alternativeNames = [];
  String? _healthTip;
  int _confidence = 92;
  NutritionVerification? _verification;

  // 基準卡路里（用於份量微調）
  int _baseCalories = 450;
  double _portionScale = 1.0;

  // 快捷標籤（加速手機點選）
  final List<String> _quickTags = ['微糖', '無糖', '大份便當', '小份', '炸物', '少油', '7-11/全家'];

  @override
  void dispose() {
    _userNoteController.dispose();
    _foodNameController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600, // HD 清晰照片
        maxHeight: 1600,
        imageQuality: 90,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      final mime = file.mimeType ?? 'image/jpeg';

      setState(() {
        _imageBytes = bytes;
        _imageMime = mime;
      });

      await _runAnalysis();
    } catch (e) {
      debugPrint("選擇圖片失敗: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('照片處理失敗: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _runAnalysis() async {
    if (_imageBytes == null) return;

    setState(() => _isAnalyzing = true);

    final userNote = _userNoteController.text.trim();
    final result = await _aiService.analyzeFoodImage(
      _imageBytes!,
      _imageMime,
      mode: _mode,
      userNote: userNote.isNotEmpty ? userNote : null,
    );

    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        _foodNameController.text = result.foodName;
        _baseCalories = result.calories;
        _portionScale = 1.0;
        _caloriesController.text = result.calories.toString();
        _description = result.description;
        _protein = result.protein;
        _fat = result.fat;
        _carbs = result.carbs;
        _servingInfo = result.servingInfo;
        _alternativeNames = result.alternativeNames;
        _healthTip = result.healthTip;
        _confidence = result.confidence;
        _verification = result.verification;
      });
    }
  }

  void _applyPortionScale(double scale) {
    setState(() {
      _portionScale = scale;
      final scaledCalories = (_baseCalories * scale).round();
      _caloriesController.text = scaledCalories.toString();
    });
  }

  void _addQuickTag(String tag) {
    final current = _userNoteController.text.trim();
    if (current.contains(tag)) return;
    setState(() {
      _userNoteController.text = current.isEmpty ? tag : '$current $tag';
    });
    if (_imageBytes != null && !_isAnalyzing) {
      _runAnalysis();
    }
  }

  Future<void> _handleConfirmSave() async {
    final name = _foodNameController.text.trim();
    final calories = int.tryParse(_caloriesController.text.trim());

    if (name.isEmpty || calories == null || calories <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請確保餐點名稱與卡路里輸入正確！')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final foodLog = FoodLog(
        loggedDate: widget.dateStr,
        foodName: name,
        calories: calories,
      );

      await widget.onSave(foodLog);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNutritionMode = _mode == AiRecognitionMode.nutritionLabel;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 標題列
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isNutritionMode ? Colors.blue.shade100 : Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isNutritionMode ? Icons.qr_code_scanner : Icons.auto_awesome,
                    color: isNutritionMode ? Colors.blue.shade800 : Colors.orange.shade800,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isNutritionMode ? 'Gemini AI 規則算式標示解析' : 'Gemini AI 雙階段高精辨識',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 模式切換器 (食物照片 vs 營養標示表)
            SegmentedButton<AiRecognitionMode>(
              segments: const [
                ButtonSegment<AiRecognitionMode>(
                  value: AiRecognitionMode.food,
                  label: Text('🍱 食物菜色'),
                  icon: Icon(Icons.restaurant),
                ),
                ButtonSegment<AiRecognitionMode>(
                  value: AiRecognitionMode.nutritionLabel,
                  label: Text('🏷️ 營養標示/成分表'),
                  icon: Icon(Icons.receipt_long),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (Set<AiRecognitionMode> newSelection) {
                setState(() {
                  _mode = newSelection.first;
                });
                if (_imageBytes != null && !_isAnalyzing) {
                  _runAnalysis();
                }
              },
            ),
            const SizedBox(height: 14),

            // 補充文字描述 + 快捷 Tag 標籤
            TextField(
              controller: _userNoteController,
              decoration: InputDecoration(
                labelText: isNutritionMode ? '✍️ 補充食品名稱 (選填)' : '✍️ 補充文字描述 (極高精度校準)',
                hintText: isNutritionMode ? '如：義美高纖豆漿' : '如：大份排骨便當 / 微糖去冰',
                prefixIcon: const Icon(Icons.edit_note),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (_) {
                if (_imageBytes != null && !_isAnalyzing) {
                  _runAnalysis();
                }
              },
            ),
            const SizedBox(height: 8),

            // 快捷 Tag 點選按鈕
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickTags.map((tag) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(tag, style: const TextStyle(fontSize: 11)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onPressed: () => _addQuickTag(tag),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // 未拍照時顯示拍照/上傳區
            if (_imageBytes == null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                decoration: BoxDecoration(
                  color: isNutritionMode ? Colors.blue.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isNutritionMode ? Colors.blue.shade200 : Colors.orange.shade200,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      isNutritionMode ? Icons.calculate_outlined : Icons.camera_alt_outlined,
                      size: 48,
                      color: isNutritionMode ? Colors.blue.shade700 : Colors.orange.shade700,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isNutritionMode
                          ? '拍攝包裝「營養標示/成分表」\n內建「kJ➔kcal單位轉換」、「每100g換算」與「4-9-4 交叉驗證」！'
                          : '拍攝食物照片\n搭載台灣外食權威熱量基準表，精確拆解食材！',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isNutritionMode ? Colors.blue.shade900 : Colors.orange.shade900,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('拍照'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isNutritionMode ? Colors.blue.shade700 : Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('相簿選擇'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // 已選取照片預覽
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      _imageBytes!,
                      height: 170,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        tooltip: '重拍/換圖',
                        onPressed: () {
                          setState(() {
                            _imageBytes = null;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (_isAnalyzing) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      CircularProgressIndicator(
                        color: isNutritionMode ? Colors.blue : Colors.orange,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isNutritionMode ? '✨ 正在執行千焦耳/100g過濾換算與 4-9-4 驗證...' : '✨ 雙階段 AI 正在比對台灣外食熱量基準庫...',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isNutritionMode ? Colors.blue.shade800 : Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // 信心度 Badge
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _confidence >= 90
                        ? Colors.green.shade50
                        : (_confidence >= 80 ? Colors.amber.shade50 : Colors.orange.shade50),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _confidence >= 90
                          ? Colors.green.shade400
                          : (_confidence >= 80 ? Colors.amber.shade400 : Colors.orange.shade300),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _confidence >= 90 ? Icons.verified : Icons.speed,
                        size: 16,
                        color: _confidence >= 90
                            ? Colors.green.shade800
                            : (_confidence >= 80 ? Colors.amber.shade900 : Colors.orange.shade900),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'AI 辨識信心度：$_confidence%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _confidence >= 90
                              ? Colors.green.shade900
                              : (_confidence >= 80 ? Colors.amber.shade900 : Colors.orange.shade900),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _confidence >= 90 ? '極高精確' : '提供多項備選',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),

                // 若包含 4-9-4 交叉驗證結果卡片
                if (_verification != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _verification!.isCrossVerified ? Colors.green.shade50 : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _verification!.isCrossVerified ? Colors.green.shade300 : Colors.amber.shade400,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _verification!.isCrossVerified ? Icons.check_circle : Icons.warning_amber_rounded,
                              color: _verification!.isCrossVerified ? Colors.green.shade800 : Colors.amber.shade900,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _verification!.isCrossVerified
                                    ? '4-9-4 三大營養素交叉驗證成功！'
                                    : '4-9-4 三大營養素運算提醒',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _verification!.isCrossVerified ? Colors.green.shade900 : Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '🧮 公式推算 (P×4 + F×9 + C×4)：${_verification!.calculated494Kcal.toStringAsFixed(0)} kcal\n'
                          '🏷️ 標示換算總熱量：${_verification!.finalCaloriesKcal.toStringAsFixed(0)} kcal (偏差 ${_verification!.diffPercentage.toStringAsFixed(1)}%)',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade900, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],

                // AI 辨識結果與單鍵切換選項
                TextField(
                  controller: _foodNameController,
                  decoration: InputDecoration(
                    labelText: isNutritionMode ? '辨識出的商品/食品名稱' : '辨識出的餐點名稱',
                    prefixIcon: const Icon(Icons.restaurant, color: Colors.orange),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                // 若有備選餐點名稱（1鍵點擊切換）
                if (_alternativeNames.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('💡 猜你想找：', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _alternativeNames.map((alt) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(alt, style: const TextStyle(fontSize: 11)),
                                  selected: _foodNameController.text == alt,
                                  onSelected: (_) {
                                    setState(() {
                                      _foodNameController.text = alt;
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 10),
                TextField(
                  controller: _caloriesController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isNutritionMode ? '解析計算總熱量 (kcal)' : '估算總熱量 (kcal)',
                    prefixIcon: const Icon(Icons.local_fire_department, color: Colors.deepOrange),
                    suffixText: 'kcal',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                // 份量一鍵乘算微調 (0.5x / 1.0x / 1.5x / 2.0x)
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('⚖️ 份量微調：', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                    const SizedBox(width: 4),
                    _PortionChip(
                      label: '0.5x 半份',
                      isSelected: _portionScale == 0.5,
                      onTap: () => _applyPortionScale(0.5),
                    ),
                    _PortionChip(
                      label: '1.0x 標準',
                      isSelected: _portionScale == 1.0,
                      onTap: () => _applyPortionScale(1.0),
                    ),
                    _PortionChip(
                      label: '1.5x 大份',
                      isSelected: _portionScale == 1.5,
                      onTap: () => _applyPortionScale(1.5),
                    ),
                    _PortionChip(
                      label: '2.0x 雙份',
                      isSelected: _portionScale == 2.0,
                      onTap: () => _applyPortionScale(2.0),
                    ),
                  ],
                ),

                // 三大營養素與份量標示
                if (_protein != null || _fat != null || _carbs != null || _servingInfo != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_servingInfo != null && _servingInfo!.isNotEmpty) ...[
                          Text(
                            '📦 份量標示：$_servingInfo',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade900, fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            if (_protein != null)
                              _NutrientChip(label: '蛋白質', value: '${(_protein! * _portionScale).toStringAsFixed(1)}g', color: Colors.red.shade700),
                            if (_fat != null)
                              _NutrientChip(label: '脂肪', value: '${(_fat! * _portionScale).toStringAsFixed(1)}g', color: Colors.amber.shade900),
                            if (_carbs != null)
                              _NutrientChip(label: '碳水', value: '${(_carbs! * _portionScale).toStringAsFixed(1)}g', color: Colors.green.shade800),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // 詳細規則演算法換算歷程
                if (_description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isNutritionMode ? Colors.blue.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isNutritionMode ? '📐 規則換算與驗證歷程：\n$_description' : '📝 熱量拆解：$_description',
                      style: TextStyle(
                        fontSize: 12,
                        color: isNutritionMode ? Colors.blue.shade900 : Colors.orange.shade900,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],

                // 營養師健康小建議
                if (_healthTip != null && _healthTip!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🥗 ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            '營養師小建議：$_healthTip',
                            style: TextStyle(fontSize: 12, color: Colors.green.shade900, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _runAnalysis,
                      icon: const Icon(Icons.sync, size: 16),
                      label: const Text('重新辨識'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleConfirmSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isNutritionMode ? Colors.blue.shade700 : Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('加入飲食紀錄'),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _PortionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PortionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.orange.shade700 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.orange.shade800 : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.white : Colors.grey.shade800,
            ),
          ),
        ),
      ),
    );
  }
}

class _NutrientChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _NutrientChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
