import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/movie_providers.dart';
import '../home/home_screen.dart';

/// Cinematic launch screen. Runs for ~2 seconds — long enough to prefetch
/// the Movies tab's hero/cinema feed into the Riverpod cache so Home opens
/// with data already warm, short enough to never feel like a stall.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  static const _minDisplayDuration = Duration(milliseconds: 2000);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final stopwatch = Stopwatch()..start();

    // Pre-fetch the Movies tab's initial feed so Home renders instantly.
    // Failures here are swallowed — Home's own providers will retry and
    // surface any real error there; the splash screen must never hang or
    // crash on a slow/offline network.
    try {
      await ref.read(nowPlayingInCinemaProvider.future);
    } catch (_) {
      // Ignore — Home screen handles its own loading/error states.
    }

    final elapsed = stopwatch.elapsed;
    if (elapsed < _minDisplayDuration) {
      await Future.delayed(_minDisplayDuration - elapsed);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: HomeScreen(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.crimson.withOpacity(0.35),
                        blurRadius: 40,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/jmovies_logo.svg',
                    height: 120,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'JMOVIES',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'POWERED BY JUNAID JAVED',
                  style: TextStyle(
                    color: AppColors.crimson,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
