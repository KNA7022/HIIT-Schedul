import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/schedule_screen.dart';
import 'services/storage_service.dart';
import 'services/api_service.dart';
import 'screens/about_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '课程表',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: Typography.dense2021.apply(
          bodyColor: Colors.black87,
          displayColor: Colors.black87,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const StartupScreen(),
        '/login': (context) => const LoginScreen(),
        '/schedule': (context) => const ScheduleScreen(),
        '/about': (context) => const AboutScreen(), // 添加关于页面路由
      },
    );
  }
}

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await StorageService().isLoggedIn();
    if (isLoggedIn) {
      final isValid = await ApiService().initializeFromStorage();
      if (isValid && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ScheduleScreen()),
        );
        return;
      }
    }
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
