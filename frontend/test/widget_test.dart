import 'package:flutter_test/flutter_test.dart';
import 'package:diet_health_tracker/main.dart';

void main() {
  testWidgets('DietTrackerApp Smoke Test', (WidgetTester tester) async {
    // 驗證 DietTrackerApp 可以正常載入
    await tester.pumpWidget(const DietTrackerApp());
    expect(find.byType(DietTrackerApp), findsOneWidget);
  });
}
