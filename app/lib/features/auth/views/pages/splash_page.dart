import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import '../../../../core/navigation/navigation_cubit.dart';
import '../../../../core/theme/app_theme.dart';
import '../../bloc/auth_bloc.dart';
import '../../bloc/auth_event.dart';
import '../../bloc/auth_state.dart';

/// Animated in-app splash.
///
/// Flow: the NATIVE splash (solid violet) holds until our first frame, then
/// this page fades the logo mark + wordmark in while [AppStarted] checks the
/// saved token. Navigation waits for BOTH the auth result AND a minimum
/// on-screen time, so the animation never gets cut off mid-play.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  static const _minSplashTime = Duration(milliseconds: 1500);

  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _wordmarkFade;
  late final Animation<Offset> _wordmarkSlide;

  late final DateTime _shownAt;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _shownAt = DateTime.now();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _logoScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
    ).drive(Tween(begin: 0.7, end: 1.0));

    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );

    _wordmarkFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
    );

    _wordmarkSlide = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
    ).drive(Tween(begin: const Offset(0, 0.35), end: Offset.zero));

    // Swap native splash → animated splash on the very first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      _controller.forward();
    });

    context.read<AuthBloc>().add(const AppStarted());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Navigate once: after the auth result AND the minimum splash time.
  Future<void> _leaveTo(void Function(NavigationCubit nav) go) async {
    if (_navigated) return;
    _navigated = true;

    final nav = context.read<NavigationCubit>();
    final remaining = _minSplashTime - DateTime.now().difference(_shownAt);
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
    if (!mounted) return;
    go(nav);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.authenticated) {
          _leaveTo((nav) => nav.goToDashboard());
        } else if (state.status == AuthStatus.unauthenticated) {
          _leaveTo((nav) => nav.goToWelcome());
        }
      },
      // White status-bar icons while the violet splash is up.
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          body: Container(
            // Expand: a Container with a child otherwise shrink-wraps to its
            // widest child, leaving the gradient covering only part of the
            // screen.
            constraints: const BoxConstraints.expand(),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 5),

                  // ── Logo mark ──────────────────────────────────────────
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 24,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Wordmark ───────────────────────────────────────────
                  FadeTransition(
                    opacity: _wordmarkFade,
                    child: SlideTransition(
                      position: _wordmarkSlide,
                      child: Column(
                        children: [
                          const Text(
                            'KhataDost',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Apki dukaan ka hisaab, ab aasaan.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(.85),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 4),

                  // ── Footer ─────────────────────────────────────────────
                  FadeTransition(
                    opacity: _wordmarkFade,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: Text(
                        'Point  ·  Scan  ·  Bill',
                        style: TextStyle(
                          color: Colors.white.withOpacity(.65),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
