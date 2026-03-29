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

  /// Called from SplashPage once the token check resolves with no token.
  void goToWelcome() {
    _router.go(AppRoutes.welcome);
    emit(state.replaced(AppRoutes.welcome));
  }

  /// Called from WelcomePage "Log in" button.
  void pushLogin() {
    _router.push(AppRoutes.login);
    emit(state.pushed(AppRoutes.login));
  }

  /// Called from WelcomePage "Sign up" button.
  void pushRegister() {
    _router.push(AppRoutes.register);
    emit(state.pushed(AppRoutes.register));
  }

  /// Called from LoginPage "Sign up" link (replaces login, keeps welcome below).
  void replaceWithRegister() {
    _router.pushReplacement(AppRoutes.register);
    final newStack = [...state.stack.sublist(0, state.stack.length - 1), AppRoutes.register];
    emit(NavigationState(
      currentRoute: AppRoutes.register,
      previousRoute: state.previousRoute,
      stack: newStack,
    ));
  }

  /// Called from RegisterPage "Log in" link (replaces register, keeps welcome below).
  void replaceWithLogin() {
    _router.pushReplacement(AppRoutes.login);
    final newStack = [...state.stack.sublist(0, state.stack.length - 1), AppRoutes.login];
    emit(NavigationState(
      currentRoute: AppRoutes.login,
      previousRoute: state.previousRoute,
      stack: newStack,
    ));
  }

  // ── Post-auth ─────────────────────────────────────────────────────────────

  /// Called after successful login or register.
  /// Replaces the entire auth stack — back is no longer possible.
  void goToDashboard() {
    _router.go(AppRoutes.dashboard);
    emit(state.replaced(AppRoutes.dashboard));
  }

  /// Called from Settings logout.
  /// Clears the stack and lands on Welcome.
  void goToWelcomeOnLogout() {
    _router.go(AppRoutes.welcome);
    emit(state.replaced(AppRoutes.welcome));
  }

  // ── Generic ───────────────────────────────────────────────────────────────

  /// Go back one step. Safe — checks [canGoBack] first.
  void goBack() {
    if (!state.canGoBack) return;
    _router.pop();
    emit(state.popped());
  }

// ── Future home-section navigation goes here ──────────────────────────────
// void goToLedger()    { _router.go(AppRoutes.ledger);    emit(state.replaced(AppRoutes.ledger)); }
// void goToSettings()  { _router.push(AppRoutes.settings); emit(state.pushed(AppRoutes.settings)); }
// void goToCustomers() { _router.go(AppRoutes.customers);  emit(state.replaced(AppRoutes.customers)); }
}