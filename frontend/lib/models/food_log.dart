class FoodLog {
  final String? id;
  final String loggedDate;
  final String? foodName;
  final int calories;

  const FoodLog({
    this.id,
    required this.loggedDate,
    this.foodName,
    required this.calories,
  });

  factory FoodLog.fromJson(Map<String, dynamic> json) {
    return FoodLog(
      id: json['id'] as String?,
      loggedDate: json['logged_date'] as String? ?? '',
      foodName: json['food_name'] as String?,
      calories: (json['calories'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'logged_date': loggedDate,
      if (foodName != null) 'food_name': foodName,
      'calories': calories,
    };
  }
}
