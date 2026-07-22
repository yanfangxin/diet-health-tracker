class DailyLog {
  final String date;
  final int waterIntakeMl;
  final int sleepMinutes;
  final double weightKg;

  const DailyLog({
    required this.date,
    this.waterIntakeMl = 0,
    this.sleepMinutes = 0,
    this.weightKg = 0.0,
  });

  factory DailyLog.fromJson(Map<String, dynamic> json) {
    return DailyLog(
      date: json['date'] as String? ?? '',
      waterIntakeMl: (json['water_intake_ml'] as num?)?.toInt() ?? 0,
      sleepMinutes: (json['sleep_minutes'] as num?)?.toInt() ?? 0,
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'water_intake_ml': waterIntakeMl,
      'sleep_minutes': sleepMinutes,
      'weight_kg': weightKg > 0 ? weightKg : null,
    };
  }

  DailyLog copyWith({
    String? date,
    int? waterIntakeMl,
    int? sleepMinutes,
    double? weightKg,
  }) {
    return DailyLog(
      date: date ?? this.date,
      waterIntakeMl: waterIntakeMl ?? this.waterIntakeMl,
      sleepMinutes: sleepMinutes ?? this.sleepMinutes,
      weightKg: weightKg ?? this.weightKg,
    );
  }
}
