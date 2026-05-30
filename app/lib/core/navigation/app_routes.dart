/// Single source of truth for every route string in the app.
///
/// Adding a new feature = add one constant here.
/// Never type a route string anywhere else in the codebase.
abstract class AppRoutes {
  // ── Auth ──────────────────────────────────────────────────────────────────
  static const splash   = '/';
  static const welcome  = '/welcome';
  static const login    = '/login';
  static const register = '/register';

  // ── App (post-login) ──────────────────────────────────────────────────────
  static const String dashboard = '/home/dashboard';
  static const String bills = '/home/bills';
  static const String inventory = '/home/inventory';

  static const String customers = '/home/customers';
  static const String customersAdd = '/home/customers/add';
  // Detail and edit take an :id param — these are PATTERNS for GoRoute.
  // Build concrete paths with the helpers below.
  static const String customerDetail = '/home/customers/:id';
  static const String customerEdit = '/home/customers/:id/edit';

  // Path builders — turn an id into a concrete navigable path.
  static String customerDetailPath(String id) => '/home/customers/$id';
  static String customerEditPath(String id) => '/home/customers/$id/edit';


// ── Settings (top-level, outside shell) ───────────────────────────────────
  static const String settings = '/settings';
}