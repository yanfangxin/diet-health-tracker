class UserGoals {
  final int targetCalories;
  final int targetWaterMl;
  final double targetSleepHours;

  const UserGoals({
    this.targetCalories = 2000,
    this.targetWaterMl = 2000,
    this.targetSleepHours = 8.0,
  });

  UserGoals copyWith({
    int? targetCalories,
    int? targetWaterMl,
    double? targetSleepHours,
  }) {
    return UserGoals(
      targetCalories: targetCalories ?? this.targetCalories,
      targetWaterMl: targetWaterMl ?? this.targetWaterMl,
      targetSleepHours: targetSleepHours ?? this.targetSleepHours,
    );
  }
}
