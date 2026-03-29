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
  static const dashboard = '/home/dashboard';
// Future features drop in here:
// static const ledger   = '/home/ledger';
// static const settings = '/home/settings';
// static const customers = '/home/customers';
}