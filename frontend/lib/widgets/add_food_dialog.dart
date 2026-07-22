import 'package:flutter/material.dart';
import '../models/food_log.dart';

class AddFoodDialog extends StatefulWidget {
  final String dateStr;
  final Future<void> Function(FoodLog foodLog) onAdd;

  const AddFoodDialog({
    super.key,
    required this.dateStr,
    required this.onAdd,
  });

  @override
  State<AddFoodDialog> createState() => _AddFoodDialogState();
}

class _AddFoodDialogState extends State<AddFoodDialog> {
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final name = _nameController.text.trim();
      final calories = int.parse(_caloriesController.text.trim());

      final foodLog = FoodLog(
        loggedDate: widget.dateStr,
        foodName: name,
        calories: calories,
      );

      await widget.onAdd(foodLog);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('新增飲食紀錄失敗: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.restaurant_menu, color: Colors.orange),
          SizedBox(width: 8),
          Text('新增飲食紀錄'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '食物名稱',
                hintText: '例如: 雞肉沙拉、牛肉麵',
                prefixIcon: Icon(Icons.fastfood),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return '請輸入食物名稱';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _caloriesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '估算熱量 (kcal)',
                hintText: '例如: 450',
                prefixIcon: Icon(Icons.local_fire_department, color: Colors.orange),
                suffixText: 'kcal',
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return '請輸入熱量';
                final num = int.tryParse(val.trim());
                if (num == null || num <= 0 || num > 5000) return '請輸入有效熱量 (1~5000)';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('新增紀錄'),
        ),
      ],
    );
  }
}
