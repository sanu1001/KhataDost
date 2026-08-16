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

  // ── Khata (inside the Customers branch — the detail page's grown stub) ────
  static const String customerKhata = '/home/customers/:id/khata';
  static String customerKhataPath(String id) => '/home/customers/$id/khata';

  static const String inventoryAdd = '/home/inventory/add';
  // :id patterns for GoRoute
  static const String inventoryDetail = '/home/inventory/:id';
  static const String inventoryEdit = '/home/inventory/:id/edit';

  static String inventoryDetailPath(String id) => '/home/inventory/$id';
  static String inventoryEditPath(String id) => '/home/inventory/$id/edit';

  // ── Billing (inside the Bills branch) ─────────────────────────────────────
  static const String billsNew = '/home/bills/new';
  static const String billsSettle = '/home/bills/new/settle';
  // FAB path: same builder route, but auto-opens the capture sheet.
  static String billsNewScanPath() => '$billsNew?scan=1';


// ── Settings (top-level, outside shell) ───────────────────────────────────
  static const String settings = '/settings';
  // Change Password (placeholder sub-section, child of /settings).
  static const String settingsChangePassword = '/settings/change-password';
}
