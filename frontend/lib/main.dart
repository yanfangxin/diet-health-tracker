import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 載入 .env 檔案（在 Web 環境若讀取失敗則使用預設值防崩潰）
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("dotenv load warning: $e");
  }

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'https://qsfvzxesniylhqqsekbi.supabase.co';
  final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'] ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFzZnZ6eGVzbml5bGhxcXNla2JpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQyNjk0NTIsImV4cCI6MjA5OTg0NTQ1Mn0.5FsYOcjijuJ37nsDQX0pA8GLFVhVIYe59kyETNEhBJE';

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseKey,
  );

  runApp(const DietTrackerApp());
}

class DietTrackerApp extends StatefulWidget {
  const DietTrackerApp({super.key});

  @override
  State<DietTrackerApp> createState() => _DietTrackerAppState();
}

class _DietTrackerAppState extends State<DietTrackerApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme(ThemeMode themeMode) {
    setState(() => _themeMode = themeMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '個人飲食健康管理',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: MainNavigationScreen(
        currentThemeMode: _themeMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}