import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loads TMDB_ACCESS_TOKEN (and optionally STREAM_BACKEND_URL) from a
  // local .env file that is NOT committed to source control.
  await dotenv.load(fileName: '.env');

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: JmoviesApp()));
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
