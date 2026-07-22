import 'package:flutter/material.dart';

class UpdateHealthDialog extends StatefulWidget {
  final double currentWeight;
  final int currentSleepMinutes;
  final Future<void> Function(double weight, int sleepMinutes) onSave;

  const UpdateHealthDialog({
    super.key,
    required this.currentWeight,
    required this.currentSleepMinutes,
    required this.onSave,
  });

  @override
  State<UpdateHealthDialog> createState() => _UpdateHealthDialogState();
}

class _UpdateHealthDialogState extends State<UpdateHealthDialog> {
  late final TextEditingController _weightController;
  late final TextEditingController _sleepHoursController;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: widget.currentWeight > 0 ? widget.currentWeight.toString() : '',
    );
    _sleepHoursController = TextEditingController(
      text: widget.currentSleepMinutes > 0
          ? (widget.currentSleepMinutes / 60).toStringAsFixed(1)
          : '',
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _sleepHoursController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final double inputWeight = double.tryParse(_weightController.text) ?? widget.currentWeight;
      final double? inputSleepHours = double.tryParse(_sleepHoursController.text);
      final int sleepMins = inputSleepHours != null ? (inputSleepHours * 60).round() : widget.currentSleepMinutes;

      await widget.onSave(inputWeight, sleepMins);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('儲存失敗：$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('記錄今日體重與睡眠'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '今日體重 (kg)',
                hintText: '例如: 65.5',
                suffixText: 'kg',
              ),
              validator: (val) {
                if (val != null && val.isNotEmpty) {
                  final num = double.tryParse(val);
                  if (num == null || num <= 0 || num > 300) {
                    return '請輸入有效的體重 (1~300)';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sleepHoursController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '昨晚睡眠時數 (小時)',
                hintText: '例如: 7.5',
                suffixText: '小時',
              ),
              validator: (val) {
                if (val != null && val.isNotEmpty) {
                  final num = double.tryParse(val);
                  if (num == null || num < 0 || num > 24) {
                    return '請輸入有效的睡眠時數 (0~24)';
                  }
                }
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
              : const Text('儲存'),
        ),
      ],
    );
  }
}
