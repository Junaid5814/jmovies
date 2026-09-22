import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart'; // YEH IMPORT LAZMI HAI

// Aapke baqi imports (screens waghaira)
import 'screens/splash/splash_screen.dart';
import 'core/theme/app_theme.dart';

void main() async {
  // 1. Flutter bindings zaroori hain
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. MediaKit Native Player ko initialize karein
  MediaKit.ensureInitialized(); 

  // 3. App Run karein
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JMovies',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme, // Aapki apni theme yahan aayegi
      home: const SplashScreen(),
    );
  }
}
