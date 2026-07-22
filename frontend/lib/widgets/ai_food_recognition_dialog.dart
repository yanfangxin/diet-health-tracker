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

  Uint8List? _imageBytes;

  bool _isAnalyzing = false;
  bool _isSaving = false;

  final _foodNameController = TextEditingController();
  final _caloriesController = TextEditingController();
  String _description = '';

  @override
  void dispose() {
    _foodNameController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      final mime = file.mimeType ?? 'image/jpeg';

      setState(() {
        _imageBytes = bytes;
        _isAnalyzing = true;
      });

      // 呼叫 Gemini AI 分析
      final result = await _aiService.analyzeFoodImage(bytes, mime);

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _foodNameController.text = result.foodName;
          _caloriesController.text = result.calories.toString();
          _description = result.description;
        });
      }
    } catch (e) {
      debugPrint("選擇圖片失敗: $e");
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('照片處理失敗: $e'), backgroundColor: Colors.red),
        );
      }
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_awesome, color: Colors.orange.shade800),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Gemini AI 拍照辨識飲食',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 未拍照時顯示拍照/選圖按鈕
            if (_imageBytes == null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    Icon(Icons.camera_alt_outlined, size: 54, color: Colors.grey.shade500),
                    const SizedBox(height: 12),
                    Text(
                      '拍攝或上傳食物照片\nAI 自動估算餐點與卡路里',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('拍照'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // 已選取照片預覽
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  _imageBytes!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),

              if (_isAnalyzing) ...[
                Column(
                  children: [
                    const CircularProgressIndicator(color: Colors.orange),
                    const SizedBox(height: 12),
                    Text(
                      '✨ Gemini AI 正在分析食物照片...',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                    ),
                  ],
                ),
              ] else ...[
                // AI 分析結果可編輯區
                TextField(
                  controller: _foodNameController,
                  decoration: const InputDecoration(
                    labelText: '辨識出的餐點名稱',
                    prefixIcon: Icon(Icons.restaurant, color: Colors.orange),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _caloriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '預估熱量 (kcal)',
                    prefixIcon: Icon(Icons.local_fire_department, color: Colors.deepOrange),
                    suffixText: 'kcal',
                  ),
                ),
                if (_description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '💡 說明：$_description',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _imageBytes = null;
                        });
                      },
                      child: const Text('重拍照片'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleConfirmSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        foregroundColor: Colors.white,
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
