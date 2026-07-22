import 'package:flutter/material.dart';
import '../models/user_goals.dart';

class GoalSettingsDialog extends StatefulWidget {
  final UserGoals currentGoals;
  final ValueChanged<UserGoals> onSave;

  const GoalSettingsDialog({
    super.key,
    required this.currentGoals,
    required this.onSave,
  });

  @override
  State<GoalSettingsDialog> createState() => _GoalSettingsDialogState();
}

class _GoalSettingsDialogState extends State<GoalSettingsDialog> {
  late final TextEditingController _caloriesController;
  late final TextEditingController _waterController;
  late final TextEditingController _sleepController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _caloriesController = TextEditingController(text: widget.currentGoals.targetCalories.toString());
    _waterController = TextEditingController(text: widget.currentGoals.targetWaterMl.toString());
    _sleepController = TextEditingController(text: widget.currentGoals.targetSleepHours.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _waterController.dispose();
    _sleepController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    final targetCalories = int.parse(_caloriesController.text);
    final targetWater = int.parse(_waterController.text);
    final targetSleep = double.parse(_sleepController.text);

    widget.onSave(UserGoals(
      targetCalories: targetCalories,
      targetWaterMl: targetWater,
      targetSleepHours: targetSleep,
    ));

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.tune, color: Colors.teal),
          SizedBox(width: 8),
          Text('設定每日健康目標'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '每日熱量目標 (kcal)',
                  hintText: '例如: 2000',
                  prefixIcon: Icon(Icons.local_fire_department, color: Colors.deepOrange),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return '請輸入熱量目標';
                  final num = int.tryParse(val);
                  if (num == null || num <= 0 || num > 10000) return '請輸入有效熱量 (500~10000)';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _waterController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '每日飲水目標 (ml)',
                  hintText: '例如: 2000',
                  prefixIcon: Icon(Icons.water_drop, color: Colors.blue),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return '請輸入飲水目標';
                  final num = int.tryParse(val);
                  if (num == null || num <= 0 || num > 10000) return '請輸入有效飲水量 (500~10000)';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _sleepController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '每日睡眠目標 (小時)',
                  hintText: '例如: 8.0',
                  prefixIcon: Icon(Icons.bedtime, color: Colors.indigo),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return '請輸入睡眠目標';
                  final num = double.tryParse(val);
                  if (num == null || num <= 0 || num > 24) return '請輸入有效睡眠時數 (1~24)';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _handleSave,
          child: const Text('儲存目標'),
        ),
      ],
    );
  }
}
