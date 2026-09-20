import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';

Future<void> main() async {
  // Catch any early framework errors
  WidgetsFlutterBinding.ensureInitialized();

  // Safe dotenv loader - App crash hone se bachata hai
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('dotenv loading error (continuing with defaults): $e');
  }

  // Orientation settings
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (_) {}

  // Har haal mein runApp run hona chahiye
  runApp(
    const ProviderScope(
      child: JmoviesApp(),
    ),
  );
}

class JmoviesApp extends StatelessWidget {
  const JmoviesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jmovies',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkCinema,
      themeMode: ThemeMode.dark,
      home: const SplashScreen(),
    );
  }
}
