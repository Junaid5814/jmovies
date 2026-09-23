import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // MediaKit Native Video Engine Initialize
  MediaKit.ensureInitialized(); 

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
      // Standard dark theme use kiya hai taake missing theme ka error na aaye
      theme: ThemeData.dark(),
      home: const SplashScreen(),
    );
  }
}
