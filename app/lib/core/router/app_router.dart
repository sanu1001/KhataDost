import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:khata_dost/features/bills/presentation/pages/bills_page.dart';
import 'package:khata_dost/features/customers/presentation/pages/customers_page.dart';
import 'package:khata_dost/features/inventory/presentation/pages/inventory_page.dart';

import '../../features/settings/presentation/pages/settings_page.dart';
import '../navigation/app_routes.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/bloc/auth_state.dart';
import '../../features/auth/views/pages/login_page.dart';
import '../../features/auth/views/pages/register_page.dart';
import '../../features/auth/views/pages/splash_page.dart';
import '../../features/auth/views/pages/welcome_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import '../../features/dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../shell/app_shell.dart';

class AppRouter {
  AppRouter({required AuthBloc authBloc}) : _authBloc = authBloc;

  final AuthBloc _authBloc;

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _BlocRefreshStream(_authBloc.stream),
    redirect: _redirect,
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashPage()),
      GoRoute(path: AppRoutes.welcome, builder: (_, __) => const WelcomePage()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginPage()),
      GoRoute(
          path: AppRoutes.register, builder: (_, __) => const RegisterPage()),

      // ── Shell ──────────────────────────────────────────────────────────────
      // StatefulShellRoute wraps all /home/* routes.
      // Each branch gets its own independent navigation stack.
      // The builder receives a StatefulNavigationShell widget which:
      //   - renders the active branch in its body
      //   - exposes currentIndex and goBranch() for the bottom nav
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          // AppShell doesn't exist yet — Placeholder keeps the app runnable
          // while we build the shell UI in the next step.
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0 — Home
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (_, __) => BlocProvider.value(
                  value: GetIt.I<DashboardBloc>(),
                  child: const DashboardPage(),
                ),
              ),
            ],
          ),

          // Branch 1 — Bills
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.bills,
                builder: (_, __) => const BillsPage(),
              ),
            ],
          ),

          // Branch 2 — Inventory
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.inventory,
                builder: (_, __) => const InventoryPage(),
              ),
            ],
          ),

          // Branch 3 — Customers
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.customers,
                builder: (_, __) => const CustomersPage(),
              ),
            ],
          ),
        ],
      ),
      // ── Settings (top-level, outside shell) ───────────────────────────────────
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsPage(),
      ),
    ],
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    final authStatus = _authBloc.state.status;
    final loc = state.matchedLocation;

    if (loc == AppRoutes.splash) return null;

    final isAuthenticated = authStatus == AuthStatus.authenticated;
    final isOnAuthPages = loc == AppRoutes.welcome ||
        loc == AppRoutes.login ||
        loc == AppRoutes.register;
    final isOnHome = loc.startsWith('/home');

    if (!isAuthenticated && isOnHome) return AppRoutes.welcome;
    if (isAuthenticated && isOnAuthPages) return AppRoutes.dashboard;

    return null;
  }
}

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