import 'package:flutter/material.dart';
import '../models/user_goals.dart';
import '../widgets/goal_settings_dialog.dart';
import 'analytics_screen.dart';
import 'dashboard_screen.dart';
import 'food_logs_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final ValueChanged<ThemeMode> onToggleTheme;
  final ThemeMode currentThemeMode;

  const MainNavigationScreen({
    super.key,
    required this.onToggleTheme,
    required this.currentThemeMode,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  UserGoals _userGoals = const UserGoals();

  void _showGoalSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => GoalSettingsDialog(
        currentGoals: _userGoals,
        onSave: (newGoals) {
          setState(() => _userGoals = newGoals);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('🎯 個人健康目標已成功更新！'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.currentThemeMode == ThemeMode.dark;

    final pages = [
      DashboardScreen(
        userGoals: _userGoals,
        onOpenGoalSettings: _showGoalSettingsDialog,
      ),
      const FoodLogsScreen(),
      const AnalyticsScreen(),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: Colors.teal.shade700,
          unselectedItemColor: Colors.grey.shade600,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: '今日儀表板',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_outlined),
              activeIcon: Icon(Icons.restaurant),
              label: '飲食明細',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.insights_outlined),
              activeIcon: Icon(Icons.insights),
              label: '7日趨勢',
            ),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade700, Colors.teal.shade900],
                ),
              ),
              accountName: const Text('個人健康日誌', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              accountEmail: const Text('Supabase 數據同步中 ✨'),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white24,
                child: Icon(Icons.person, color: Colors.white, size: 36),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.tune, color: Colors.teal),
              title: const Text('設定健康目標'),
              subtitle: Text('目前卡路里: ${_userGoals.targetCalories} kcal / 飲水: ${_userGoals.targetWaterMl} ml'),
              onTap: () {
                Navigator.pop(context);
                _showGoalSettingsDialog();
              },
            ),
            const Divider(),
            SwitchListTile(
              secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: Colors.orange),
              title: const Text('切換深色模式 (Dark Mode)'),
              value: isDark,
              onChanged: (val) {
                widget.onToggleTheme(val ? ThemeMode.dark : ThemeMode.light);
              },
            ),
          ],
        ),
      ),
    );
  }
}
