import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final double? progress; // 0.0 ~ 1.0 (null 表示不顯示進度條，如體重)
  final String? subtitle; // 例如: "目標 2000 ml"

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.progress,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress?.clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: color.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 標題與圖示列
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 18, color: color),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                if (clampedProgress != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${(clampedProgress * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
              ],
            ),

            // 數值與單位列
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),

            // 進度條與副標題列 (若有進度)
            if (clampedProgress != null) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: clampedProgress,
                      minHeight: 6,
                      backgroundColor: color.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ] else if (subtitle != null) ...[
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
