import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';
import 'navigation_state.dart';

/// The single navigation authority for the entire app.
///
/// HOW IT WORKS
/// ─────────────
/// • Holds a reference to the [GoRouter] instance (injected in main.dart).
/// • Every navigation action in the app calls a method here — never
///   context.push / context.go directly from a page.
/// • Each method calls the appropriate GoRouter API AND emits an updated
///   [NavigationState] so the rest of the app always knows where the user is.
///
/// HOW TO ADD A NEW SCREEN (when you build the next feature)
/// ───────────────────────────────────────────────────────────
/// 1. Add the route constant to [AppRoutes].
/// 2. Add a [GoRoute] in [AppRouter].
/// 3. Add a method here (e.g. pushLedger(), goToSettings()).
/// 4. Call that method from your new page's button.
/// That's it. Nothing else changes.
class NavigationCubit extends Cubit<NavigationState> {
  NavigationCubit(this._router) : super(const NavigationState());

  final GoRouter _router;

  // ── Auth flow ─────────────────────────────────────────────────────────────

  void goToWelcome() {
    _router.go(AppRoutes.welcome);
    emit(state.replaced(AppRoutes.welcome));
  }

  void pushLogin() {
    _router.push(AppRoutes.login);
    emit(state.pushed(AppRoutes.login));
  }

  void pushRegister() {
    _router.push(AppRoutes.register);
    emit(state.pushed(AppRoutes.register));
  }

  /// Fixed: was constructing NavigationState directly, losing activeTabIndex
  /// and refreshTick. Now uses copyWith via the stack helpers.
  void replaceWithRegister() {
    _router.pushReplacement(AppRoutes.register);
    final newStack = [
      ...state.stack.sublist(0, state.stack.length - 1),
      AppRoutes.register,
    ];
    emit(state.copyWith(
      currentRoute: AppRoutes.register,
      previousRoute: state.previousRoute,
      stack: newStack,
    ));
  }

  void replaceWithLogin() {
    _router.pushReplacement(AppRoutes.login);
    final newStack = [
      ...state.stack.sublist(0, state.stack.length - 1),
      AppRoutes.login,
    ];
    emit(state.copyWith(
      currentRoute: AppRoutes.login,
      previousRoute: state.previousRoute,
      stack: newStack,
    ));
  }

  // ── Post-auth ─────────────────────────────────────────────────────────────

  void goToDashboard() {
    _router.go(AppRoutes.dashboard);
    emit(state.replaced(AppRoutes.dashboard));
  }

  void goToWelcomeOnLogout() {
    _router.go(AppRoutes.welcome);
    emit(state.replaced(AppRoutes.welcome));
  }

  // ── Generic ───────────────────────────────────────────────────────────────

  void goBack() {
    if (!state.canGoBack) return;
    _router.pop();
    emit(state.popped());
  }

  // ── Shell tab switching ───────────────────────────────────────────────────

  /// Switches the bottom-nav shell to a given branch (tab).
  ///
  /// isRetap: user tapped the tab they're already on.
  ///   → pops branch stack to root (initialLocation: true)
  ///   → increments refreshTick so BlocListeners on that tab fire
  ///
  /// Normal switch: no tick change, just update activeTabIndex.
  void goToTab(StatefulNavigationShell shell, int index) {
    final isRetap = index == shell.currentIndex;

    shell.goBranch(index, initialLocation: isRetap);

    emit(state.copyWith(
      activeTabIndex: index,
      refreshTick: isRetap ? state.refreshTick + 1 : state.refreshTick,
    ));
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  void pushSettings() {
    _router.push(AppRoutes.settings);
    emit(state.pushed(AppRoutes.settings));
  }

  // ── Customers ─────────────────────────────────────────────────────────────

  void pushAddCustomer() {
    _router.push(AppRoutes.customersAdd);
    emit(state.pushed(AppRoutes.customersAdd));
  }

  void pushCustomerDetail(String id) {
    final path = AppRoutes.customerDetailPath(id);
    _router.push(path);
    emit(state.pushed(path));
  }

  void pushCustomerEdit(String id) {
    final path = AppRoutes.customerEditPath(id);
    _router.push(path);
    emit(state.pushed(path));
  }
}