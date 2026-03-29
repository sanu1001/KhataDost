import 'package:equatable/equatable.dart';

/// Tracks exactly where the user is and the history of how they got there.
///
/// [currentRoute]  — the route string currently on screen.
/// [previousRoute] — the route before the current one (null at app start).
/// [stack]         — full ordered history, newest last.
///                   Use this for breadcrumbs, analytics, or back-logic.
class NavigationState extends Equatable {
  const NavigationState({
    this.currentRoute = '/',
    this.previousRoute,
    this.stack = const ['/'],
  });

  final String currentRoute;
  final String? previousRoute;
  final List<String> stack;

  // ── Convenience getters ──────────────────────────────────────────────────

  /// True when there is more than one entry in the stack (back is possible).
  bool get canGoBack => stack.length > 1;

  /// True when the user is anywhere inside the home section.
  bool get isInHome => currentRoute.startsWith('/home');

  /// True when the user is on any auth-flow page.
  bool get isInAuth =>
      currentRoute == '/' ||
          currentRoute == '/welcome' ||
          currentRoute == '/login' ||
          currentRoute == '/register';

  // ── Update helpers ───────────────────────────────────────────────────────

  /// Used when navigating WITH a back-stack (push).
  NavigationState pushed(String route) => NavigationState(
    currentRoute: route,
    previousRoute: currentRoute,
    stack: [...stack, route],
  );

  /// Used when replacing the entire stack (go / goNamed).
  NavigationState replaced(String route) => NavigationState(
    currentRoute: route,
    previousRoute: currentRoute,
    stack: [route],
  );

  /// Used when the user goes back one step.
  NavigationState popped() {
    if (stack.length <= 1) return this;
    final newStack = stack.sublist(0, stack.length - 1);
    return NavigationState(
      currentRoute: newStack.last,
      previousRoute: stack.length >= 2 ? stack[stack.length - 2] : null,
      stack: newStack,
    );
  }

  @override
  List<Object?> get props => [currentRoute, previousRoute, stack];
}