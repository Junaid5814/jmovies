import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';

// In-Memory TMDB Credentials (Zero file dependency)
const String _tmdbEnv = '''
TMDB_ACCESS_TOKEN=eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJkYWMwNzY2MjA4M2RlY2YyNjE2YzRlNjhkMjIzNDJjOSIsIm5iZiI6MTc4OTI5NDQ3My45NDgsInN1YiI6IjZhYTY3Nzg5YjFmNzgyMjZjYjU3ODAyNSIsInNjb3BlcyI6WyJhcGlfcmVhZCJdLCJ2ZXJzaW9uIjoxfQ.nXRm_2AAufGAeHFBuMLf4Dg5yViQ-jlTEF2CkYp6WL4
TMDB_API_KEY=dac07662083decf2616c4e68d22342c9
BASE_URL=https://api.themoviedb.org/3
IMAGE_BASE_URL=https://image.tmdb.org/t/p/w500
''';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Safe Loader: File mile to theek, warna direct memory se initialize karega
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  try {
    if (!dotenv.isInitialized || (dotenv.env['TMDB_ACCESS_TOKEN'] ?? '').isEmpty) {
      dotenv.testLoad(fileInput: _tmdbEnv);
    }
  } catch (_) {
    dotenv.testLoad(fileInput: _tmdbEnv);
  }

  // Set orientation
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (_) {}

  // Run App
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
