import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  await SystemChrome.setPreferredOrientations(
    const [
      DeviceOrientation.portraitUp,
    ],
  );

  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  String? configurationError;

  try {
    AppConfig.validate();
  } on StateError catch (error) {
    configurationError = error.message;
  } catch (error) {
    configurationError = error.toString();
  }

  runZonedGuarded(
    () {
      runApp(
        ProviderScope(
          child: JmoviesApp(
            configurationError: configurationError,
          ),
        ),
      );
    },
    (Object error, StackTrace stackTrace) {
      if (kDebugMode) {
        debugPrint('Uncaught application error: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    },
  );
}

class JmoviesApp extends StatelessWidget {
  final String? configurationError;

  const JmoviesApp({
    super.key,
    this.configurationError,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JMovies',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkCinema,
      darkTheme: AppTheme.darkCinema,
      themeMode: ThemeMode.dark,
      home: configurationError == null
          ? const SplashScreen()
          : ConfigurationErrorScreen(
              message: configurationError!,
            ),
    );
  }
}

class ConfigurationErrorScreen extends StatelessWidget {
  final String message;

  const ConfigurationErrorScreen({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 520,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF151515),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE50914),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.settings_suggest_rounded,
                      color: Color(0xFFE50914),
                      size: 52,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'JMovies configuration required',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFB3B3B3),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Add the required GitHub repository secret and rebuild the app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF808080),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
