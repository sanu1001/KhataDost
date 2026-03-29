import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../navigation/app_routes.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_state.dart';
import '../../features/auth/views/pages/login_page.dart';
import '../../features/auth/views/pages/register_page.dart';
import '../../features/auth/views/pages/splash_page.dart';
import '../../features/auth/views/pages/welcome_page.dart';

/// Owns the [GoRouter] instance and the auth redirect guard.
///
/// Responsibility split:
///   AppRouter   → WHAT pages exist + auth guard (declarative, automatic)
///   NavigationCubit → HOW to get there (imperative, called by the UI)
///
/// The guard is kept here because it's a safety net — even if a bug
/// somehow calls context.go('/home/dashboard') without auth, the guard
/// bounces it back. Defence in depth.
class AppRouter {
  AppRouter({required AuthBloc authBloc}) : _authBloc = authBloc;

  final AuthBloc _authBloc;

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _BlocRefreshStream(_authBloc.stream),
    redirect: _redirect,
    routes: [
      GoRoute(path: AppRoutes.splash,    builder: (_, __) => const SplashPage()),
      GoRoute(path: AppRoutes.welcome,   builder: (_, __) => const WelcomePage()),
      GoRoute(path: AppRoutes.login,     builder: (_, __) => const LoginPage()),
      GoRoute(path: AppRoutes.register,  builder: (_, __) => const RegisterPage()),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (_, __) => const _PlaceholderDashboard(),
      ),
      // New features: add a GoRoute here + a method in NavigationCubit.
    ],
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    final authStatus = _authBloc.state.status;
    final loc        = state.matchedLocation;

    if (loc == AppRoutes.splash) return null;

    final isAuthenticated = authStatus == AuthStatus.authenticated;
    final isOnAuthPages   = loc == AppRoutes.welcome ||
        loc == AppRoutes.login   ||
        loc == AppRoutes.register;
    final isOnHome        = loc.startsWith('/home');

    if (!isAuthenticated && isOnHome)      return AppRoutes.welcome;
    if (isAuthenticated  && isOnAuthPages) return AppRoutes.dashboard;

    return null;
  }
}

// ── Adapter: Stream → ChangeNotifier ─────────────────────────────────────────

class _BlocRefreshStream extends ChangeNotifier {
  _BlocRefreshStream(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

// ── Placeholder ───────────────────────────────────────────────────────────────

class _PlaceholderDashboard extends StatelessWidget {
  const _PlaceholderDashboard();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Dashboard — coming soon', style: TextStyle(fontSize: 22)),
      ),
    );
  }
}