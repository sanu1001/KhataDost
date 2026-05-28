import 'package:equatable/equatable.dart';

class NavigationState extends Equatable {
  const NavigationState({
    this.currentRoute = '/',
    this.previousRoute,
    this.stack = const ['/'],
    this.activeTabIndex = 0,
    this.refreshTick = 0,
  });

  final String currentRoute;
  final String? previousRoute;
  final List<String> stack;

  /// Which shell branch (tab) is currently active.
  /// 0 = Home, 1 = Bills, 2 = Inventory, 3 = Customers.
  /// Only meaningful when [isInHome] is true.
  final int activeTabIndex;

  /// Increments every time the already-active tab is re-tapped.
  /// BlocListeners compare previous vs current tick to detect re-tap intent.
  /// The actual value is meaningless — only changes matter.
  final int refreshTick;

  // ── Convenience getters ──────────────────────────────────────────────────

  bool get canGoBack => stack.length > 1;

  bool get isInHome => currentRoute.startsWith('/home');

  bool get isInAuth =>
      currentRoute == '/' ||
          currentRoute == '/welcome' ||
          currentRoute == '/login' ||
          currentRoute == '/register';

  // ── Update helpers ───────────────────────────────────────────────────────

  NavigationState pushed(String route) => NavigationState(
    currentRoute: route,
    previousRoute: currentRoute,
    stack: [...stack, route],
    activeTabIndex: activeTabIndex,
    refreshTick: refreshTick,
  );

  NavigationState replaced(String route) => NavigationState(
    currentRoute: route,
    previousRoute: currentRoute,
    stack: [route],
    activeTabIndex: activeTabIndex,
    refreshTick: refreshTick,
  );

  NavigationState popped() {
    if (stack.length <= 1) return this;
    final newStack = stack.sublist(0, stack.length - 1);
    return NavigationState(
      currentRoute: newStack.last,
      previousRoute: stack.length >= 2 ? stack[stack.length - 2] : null,
      stack: newStack,
      activeTabIndex: activeTabIndex,
      refreshTick: refreshTick,
    );
  }

  NavigationState copyWith({
    String? currentRoute,
    String? previousRoute,
    List<String>? stack,
    int? activeTabIndex,
    int? refreshTick,
  }) =>
      NavigationState(
        currentRoute: currentRoute ?? this.currentRoute,
        previousRoute: previousRoute ?? this.previousRoute,
        stack: stack ?? this.stack,
        activeTabIndex: activeTabIndex ?? this.activeTabIndex,
        refreshTick: refreshTick ?? this.refreshTick,
      );

  @override
  List<Object?> get props => [
    currentRoute,
    previousRoute,
    stack,
    activeTabIndex,
    refreshTick,
  ];
}