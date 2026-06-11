import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:khata_dost/features/bills/presentation/pages/bills_page.dart';
import 'package:khata_dost/features/customers/presentation/pages/customers_page.dart';
import 'package:khata_dost/features/inventory/presentation/pages/inventory_page.dart';

import '../../features/inventory/presentation/bloc/inventory_bloc.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/change_password/presentation/pages/change_password_page.dart';
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

import '../../features/customers/presentation/bloc/customers_bloc.dart';
import '../../features/customers/presentation/pages/customer_detail_page.dart';
import '../../features/customers/presentation/pages/customer_form_page.dart';

import '../../features/inventory/presentation/pages/item_detail_page.dart';
import '../../features/inventory/presentation/pages/item_form_page.dart';

import '../../features/bills/presentation/bloc/bill_builder_bloc.dart';
import '../../features/bills/presentation/bloc/bills_bloc.dart';
import '../../features/bills/presentation/pages/bill_builder_page.dart';
import '../../features/bills/presentation/pages/settle_page.dart';

import '../../features/khata/presentation/bloc/khata_bloc.dart';
import '../../features/khata/presentation/pages/customer_khata_page.dart';


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
          // Sub-routes (new / new/settle) push WITHIN this branch.
          // Every billing route pulls the SAME GetIt singletons, so the
          // FAB's scan path and the manual "+" path share ONE draft bill.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.bills,
                builder: (_, __) => BlocProvider.value(
                  value: GetIt.I<BillsBloc>(),
                  child: const BillsPage(),
                ),
                routes: [
                  GoRoute(
                    path: 'new', // relative → /home/bills/new
                    builder: (_, state) => MultiBlocProvider(
                      providers: [
                        BlocProvider.value(value: GetIt.I<BillBuilderBloc>()),
                        // Manual on-ramp searches inventory (read-only).
                        BlocProvider.value(value: GetIt.I<InventoryBloc>()),
                      ],
                      child: BillBuilderPage(
                        // FAB path arrives as ?scan=1 → auto-open capture.
                        scanOnOpen:
                            state.uri.queryParameters['scan'] == '1',
                      ),
                    ),
                    routes: [
                      GoRoute(
                        path: 'settle', // → /home/bills/new/settle
                        builder: (_, __) => MultiBlocProvider(
                          providers: [
                            BlocProvider.value(
                                value: GetIt.I<BillBuilderBloc>()),
                            // Customer picker (read-only reuse).
                            BlocProvider.value(
                                value: GetIt.I<CustomersBloc>()),
                            // Refreshed after a successful settle.
                            BlocProvider.value(value: GetIt.I<BillsBloc>()),
                          ],
                          child: const SettlePage(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Branch 2 — Inventory
          // Branch 2 — Inventory
          // Branch 2 — Inventory
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.inventory,
                builder: (_, __) => BlocProvider.value(
                  value: GetIt.I<InventoryBloc>(),
                  child: const InventoryPage(),
                ),
                routes: [
                  GoRoute(
                    path: 'add',
                    builder: (_, __) => BlocProvider.value(
                      value: GetIt.I<InventoryBloc>(),
                      child: const ItemFormPage(),
                    ),
                  ),
                  GoRoute(
                    path: ':id/edit',
                    builder: (_, state) => BlocProvider.value(
                      value: GetIt.I<InventoryBloc>(),
                      child: ItemFormPage(
                        itemId: state.pathParameters['id'],
                      ),
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => BlocProvider.value(
                      value: GetIt.I<InventoryBloc>(),
                      child: ItemDetailPage(
                        itemId: state.pathParameters['id']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Branch 3 — Customers
          // Branch 3 — Customers
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.customers,
                builder: (_, __) => BlocProvider.value(
                  value: GetIt.I<CustomersBloc>(),
                  child: const CustomersPage(),
                ),
                routes: [
                  // Sub-routes are CHILDREN of /home/customers, so they push
                  // WITHIN branch 3 — the bottom nav stays visible and the
                  // branch's own stack is preserved.
                  GoRoute(
                    path: 'add', // relative → /home/customers/add
                    builder: (_, __) => BlocProvider.value(
                      value: GetIt.I<CustomersBloc>(),
                      child: const CustomerFormPage(),
                    ),
                  ),
                  GoRoute(
                    path: ':id/edit', // relative → /home/customers/:id/edit
                    builder: (_, state) => BlocProvider.value(
                      value: GetIt.I<CustomersBloc>(),
                      child: CustomerFormPage(
                        customerId: state.pathParameters['id'],
                      ),
                    ),
                  ),
                  // Phase 5: the detail page's grown stub — the khata page
                  // pushes WITHIN branch 3 (back lands on the detail page).
                  // Listed before ':id' alongside ':id/edit' (two-segment
                  // patterns match before the one-segment detail route).
                  GoRoute(
                    path: ':id/khata', // relative → /home/customers/:id/khata
                    builder: (_, state) => MultiBlocProvider(
                      providers: [
                        BlocProvider.value(value: GetIt.I<KhataBloc>()),
                        // Customer name + has_dues refresh (read-only reuse).
                        BlocProvider.value(value: GetIt.I<CustomersBloc>()),
                      ],
                      child: CustomerKhataPage(
                        customerId: state.pathParameters['id']!,
                      ),
                    ),
                  ),
                  GoRoute(
                    path: ':id', // relative → /home/customers/:id
                    builder: (_, state) => BlocProvider.value(
                      value: GetIt.I<CustomersBloc>(),
                      child: CustomerDetailPage(
                        customerId: state.pathParameters['id']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // ── Settings (top-level, outside shell) ───────────────────────────────────
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, __) => const SettingsPage(),
        routes: [
          // Placeholder change-password flow — its own bloc, provided locally
          // inside the page (not GetIt). → /settings/change-password
          GoRoute(
            path: 'change-password',
            builder: (_, __) => const ChangePasswordPage(),
          ),
        ],
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
