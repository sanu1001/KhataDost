# Settings — Feature Doc
**Project:** KhataDost
**Status:** Ready to build (design locked via grill, 2026-06-11)
**Scope:** The app's last placeholder screen — Profile, Logout, Preferences (stubs), About, + a Change Password placeholder scaffold for later.

---

## What this feature does

The Settings page is reached from the gear icon (`ShellActions`) in the app bar, which already calls `NavigationCubit.pushSettings()` → the existing top-level `/settings` route. It currently renders `FeaturePlaceholderPage`. This feature replaces that placeholder with a real settings screen for a kirana shopkeeper: see his shop/profile info, log out safely, see what preferences are coming, and read an About block. It is deliberately small — no new Flutter dependencies, one new backend endpoint, no migrations, and no changes to any frozen feature's internals.

---

## Locked decisions (from the grill) + rationale

1. **Profile source of truth = a new `GET /v1/me` endpoint.**
   - *Why not JWT claims:* the token carries only `sub` (user UUID), `exp`, `iat` (`auth_service.go::generateJWT`). There is no shop name / owner / phone in the token.
   - *Why not in-memory `AuthState.user`:* login/register returns the full `User`, but only the **token** is persisted to secure storage. On a cold start `AppStarted` reads just the token and leaves `state.user` null (the bloc even comments *"Phase 4: call a /me endpoint here"*). After the app is killed and reopened — the everyday case — there is no profile in memory.
   - *Decision:* the Settings feature owns its **own** datasource → repo → bloc that calls `GET /v1/me` on page open. Frozen `auth` is never touched. No caching (Settings is a rarely-opened screen).
   - Displayed: **shop name, owner name, phone.**

2. **Logout = tile + confirm dialog → existing `LogoutRequested`.**
   - Reuses the frozen `AuthBloc`'s public `LogoutRequested` event (already wired: `_repo.logout()` clears the token → emits `unauthenticated` → GoRouter redirect sends the user to `/welcome`). Pulled into the page via `BlocProvider.value(value: GetIt.I<AuthBloc>())`. **Read-only reuse — no auth edits.**
   - An `AlertDialog` ("Log out of KhataDost?" · Cancel / Log out) guards the destructive, session-ending action — one tap prevents accidental logout on a shared shop phone.

3. **Preferences = visible-but-disabled "Coming soon" stubs.**
   - Language (Hindi/English) and Theme render as greyed tiles with a "Coming soon" subtitle and no `onTap`.
   - *Why stubs:* real i18n needs `flutter_localizations` + ARB files + re-stringing the four frozen features; real theming needs a `ThemeMode` controller at the `MaterialApp` root. Both are disproportionate for this session and brush against frozen UI.
   - **Nothing persists → no `shared_preferences`, no `flutter_localizations`, no `MaterialApp` changes.**

4. **Server URL = not surfaced anywhere in Settings.**
   - `AppConstants.baseUrl` is hardcoded to the physical phone's LAN IP and can't change at runtime; it's testing-only and irrelevant to a shopkeeper.
   - *Git hygiene (done):* committed value in `HEAD` is the safe emulator default `http://10.0.2.2:8080`; the LAN IP exists only as an uncommitted working-tree edit. `git update-index --skip-worktree app/lib/core/constants/app_constants.dart` has been set so the local IP edit can never be staged. (Reversible with `--no-skip-worktree`. `baseUrl` code untouched — guardrail holds.)

5. **About = dep-free block.**
   - App name + tagline, a hardcoded version const (`v1.0.0`, e.g. `AppConstants.appVersion`), "Built with Flutter & Go", and the repo URL as **selectable / long-press-to-copy** text (no `url_launcher`). No new deps.

6. **Backend work = yes, exactly one endpoint.** `GET /v1/me`. No schema/migration impact (see §"API").

7. **Deferred from v1:** change password, delete account, data export.
   - **Change Password** gets a **complete routed sub-section scaffold** — a self-contained `change_password/` slice inside the settings feature with its own `domain/data/presentation` + bloc + page, all as placeholders with TODO markers, reached via its own nested route. The backend endpoint and real logic are the user's to build later as a learning exercise; the scaffold gives a ready-to-flesh-out feature slice (events/state/datasource/repo stubbed, form UI laid out, submit disabled/TODO).
   - Delete account and data export get **no** scaffold — fully deferred.

---

## User flows

### Open Settings
```
Any tab → gear icon (ShellActions)
  → NavigationCubit.pushSettings()  [already wired]
  → /settings  [top-level route, already registered]
  → SettingsPage
     → SettingsBloc dispatches LoadProfile on init
     → GET /v1/me → shop name / owner / phone shown
        ↓ loading  → skeleton / spinner in the profile card
        ↓ failure  → inline error + Retry (logout/about still usable)
```

### Logout
```
Settings → tap "Log out"
  → AlertDialog (Cancel / Log out)
     ↓ Cancel  → dismiss, stay on Settings
     ↓ Log out → dispatch AuthBloc.LogoutRequested  [frozen, public event]
        → token cleared → AuthStatus.unauthenticated
        → GoRouter redirect → /welcome
```

### Change Password (scaffolded sub-section, logic deferred)
```
Settings → tap "Change password"
  → NavigationCubit.pushChangePassword()  [new, additive]
  → /settings/change-password
  → ChangePasswordPage
     → its own ChangePasswordBloc (provided locally at the route, not GetIt yet)
     → form laid out (current / new / confirm); submit disabled + TODO
     → real PUT /v1/auth/password + validation = user builds later
```

---

## Screens / sections

`SettingsPage` is a single scrollable `ListView` of grouped sections (match the visual conventions of the built feature pages):

### Profile card (top)
- Shop name (prominent), owner name, phone.
- States: loading (skeleton), loaded, error (inline message + Retry).

### Account
- **Change password** → navigates to the placeholder page (above).
- **Log out** (destructive styling) → confirm dialog → `LogoutRequested`.

### Preferences (disabled)
- **Language** — "Coming soon", disabled.
- **Theme** — "Coming soon", disabled.

### About
- App name + tagline, version (`v1.0.0`), "Built with Flutter & Go", repo URL (selectable text).

---

## BLoC

Single-state class with a `status` enum + `copyWith` (+ `clearError`), per PROJECT_MAP §5. The only real state is the profile fetch.

### Events
```dart
sealed class SettingsEvent { }
final class LoadProfile extends SettingsEvent { }   // fired on page open / Retry
```
> Logout is NOT a SettingsEvent — it is dispatched on the frozen `AuthBloc` as `LogoutRequested`.

### State
```dart
enum SettingsStatus { initial, loading, loaded, failure }

class SettingsState {
  final SettingsStatus status;
  final ShopProfile? profile;   // non-null when loaded
  final String? errorMessage;   // non-null when failure
  // copyWith(..., bool clearError = false)
}
```

### Scope
- `SettingsBloc` is **page-scoped**, provided **inside `SettingsPage`** via `BlocProvider.value(value: GetIt.I<SettingsBloc>())` — so `app_router.dart`'s existing `/settings` route (`const SettingsPage()`) needs **no edit**.
- The frozen `AuthBloc` (already a GetIt singleton) is also pulled in via `BlocProvider.value` for the logout dispatch.

---

## Data

### `GET /v1/me` response
```json
{
  "id": "uuid",
  "name": "Ramesh",
  "shop_name": "Ramesh Kirana",
  "email": "ramesh@example.com",
  "phone": "9876543210"
}
```
> Same shape as the `user` object in the auth login/register response (minus password). Returned for the user identified by the JWT `sub` claim (via `middleware.UserIDFromContext`).

### Flutter domain entity
```dart
class ShopProfile extends Equatable {
  final String id, name, shopName, email, phone;
}
```

---

## API endpoints used

| Method | Path | Auth required | New? |
|--------|------|---------------|------|
| GET | /v1/me | Yes | **New** (this feature) |

**Backend (no migration):**
- `db/queries/me.sql` — **new file** (frozen `auth.sql` untouched):
  ```sql
  -- name: GetUserByID :one
  SELECT id, name, shop_name, phone, email FROM users WHERE id = $1;
  ```
  *(`password` deliberately excluded.)* `sqlc generate` only — no `goose` (the `users` table already has every column from migration 001).
- `internal/handler/me_handler.go` → `GET /v1/me` (read `user_id` from context, map domain → response).
- `internal/service/me_service.go` → fetch by id; sentinel `ErrUserNotFound` → 404.
- `internal/repository/me_repository.go` → `GetByID`, map sqlc struct → domain `User`.
- `cmd/main.go` — **additive** route inside the protected group: `r.Get("/v1/me", meHandler.Get)`, plus the repo→service→handler chain.

**Bruno:** happy-path (valid token → 200 + profile), 401 (no header / garbage token).

---

## Flutter routes

| Route | Page | New? |
|-------|------|------|
| /settings | SettingsPage | exists (registered, was placeholder) |
| /settings/change-password | ChangePasswordPage (placeholder) | **New** (additive nested route) |

Additive wiring only:
- `AppRoutes.settingsChangePassword = '/settings/change-password'` (+ a nested `GoRoute` under the existing settings route, or a top-level child — settings territory).
- `NavigationCubit.pushChangePassword()` (additive method).

---

## Flutter file map

```
features/settings/
├── domain/
│   ├── entities/
│   │   └── shop_profile.dart
│   └── repositories/
│       └── settings_repository.dart          (abstract)
├── data/
│   ├── models/
│   │   └── shop_profile_model.dart           (fromJson)
│   ├── datasources/
│   │   ├── settings_datasource.dart          (abstract)
│   │   ├── settings_mock_datasource.dart     (stays in-tree forever)
│   │   └── settings_remote_datasource.dart   (Dio → GET /v1/me)
│   └── repositories/
│       └── settings_repository_impl.dart
└── presentation/
    ├── bloc/
    │   ├── settings_bloc.dart
    │   ├── settings_event.dart
    │   └── settings_state.dart
    ├── pages/
    │   └── settings_page.dart                (replaces placeholder; provides bloc)
    └── widgets/
        ├── profile_card.dart
        ├── settings_tile.dart                (reusable row: icon, title, subtitle, onTap?)
        └── about_section.dart

features/settings/change_password/           ← complete routed sub-section (placeholders, TODO)
├── domain/
│   └── repositories/
│       └── change_password_repository.dart      (abstract — TODO)
├── data/
│   ├── datasources/
│   │   └── change_password_remote_datasource.dart  (TODO: PUT /v1/auth/password)
│   └── repositories/
│       └── change_password_repository_impl.dart   (TODO)
└── presentation/
    ├── bloc/
    │   ├── change_password_bloc.dart            (skeleton: handlers stubbed)
    │   ├── change_password_event.dart           (SubmitRequested(current,new) — TODO)
    │   └── change_password_state.dart           (status enum + copyWith)
    └── pages/
        └── change_password_page.dart            (form scaffold; submit disabled + TODO)
```

> The `change_password` slice is **not** registered in `injection.dart` yet — its bloc is provided locally at the nested route via `BlocProvider(create: ...)`. When the user builds the real endpoint, they move it to GetIt and comment-swap a real datasource, exactly like the other features. This keeps `injection.dart` clean of a non-functional registration.

**Mock-first:** datasource registered against its abstract type in `injection.dart`; mock vs remote chosen by comment-swap (keep both lines, one commented). Mock returns a canned `ShopProfile`. Comment unused imports so `flutter analyze` stays clean.

**KNOWN TRAP (from memory):** any list parsed by a frozen model is a runtime `List<XModel>` — use loop-based lookups, never `firstWhere`/`singleWhere` with `orElse`. (Settings has no such list today, but the rule stands if one is introduced.)

---

## Backend file map

```
internal/
├── handler/
│   └── me_handler.go        ← GET /v1/me
├── service/
│   └── me_service.go        ← fetch by id; ErrUserNotFound
└── repository/
    └── me_repository.go     ← GetByID, map sqlc → domain

db/
└── queries/
    └── me.sql               ← GetUserByID :one  (NEW; auth.sql untouched)
```
No new migration. `cmd/main.go` route + chain added inside the protected group (additive).

---

## Guardrail compliance (BUILD_PLAN §0)

- **Frozen internals untouched:** auth/dashboard/customers/inventory (Flutter + Go) and their migrations/queries are read-only here. `auth.sql` not edited (new `me.sql` instead). `AuthBloc` reused via its existing public `LogoutRequested` only.
- **Sanctioned/permitted touches:**
  - `cmd/main.go` — additive route + chain for `/v1/me`.
  - `injection.dart` — additive registrations (settings datasource → repo → bloc).
  - `navigation_cubit.dart` — additive `pushChangePassword()`.
  - `app_routes.dart` — additive `settingsChangePassword` const.
  - `app_router.dart` — additive nested change-password route only; the existing `/settings` route is **not** edited (bloc provided inside `SettingsPage`).
- **Settings territory (free to replace):** `features/settings/**`, including the `settings_page.dart` placeholder.
- **`baseUrl` not touched** (skip-worktree guard set instead).
- **No new Flutter dependencies.** One new backend endpoint. Zero migrations.

---

## Build order

1. **Backend** — `me.sql` query → `sqlc generate`; `me_repository` → `me_service` → `me_handler`; wire `GET /v1/me` in `main.go`. `go build ./...`. Bruno: 200 + 401.
2. **Flutter domain/data** — `ShopProfile` entity + repo contract; mock datasource + repo impl.
3. **Flutter BLoC** — `SettingsBloc` (`LoadProfile` → loading → loaded/failure).
4. **Flutter pages/widgets** — `SettingsPage` (profile card, account, prefs stubs, about); provide `SettingsBloc` + `AuthBloc` inside the page.
4b. **Change Password sub-section scaffold** — `change_password/{domain,data,presentation}` placeholder slice (abstract repo, TODO datasource/impl, skeleton bloc/event/state, form page with submit disabled + TODO markers). Bloc provided locally at the route.
5. **Wiring** — `injection.dart` registrations (settings only); `navigation_cubit.pushChangePassword()`; `AppRoutes.settingsChangePassword` + nested route under `/settings`. Test on **mock**.
6. **Swap mock → real Dio** (`GET /v1/me`). End-to-end on a real phone.

---

## Definition of done

- `go build ./...` clean; `sqlc generate` clean; Bruno happy-path + 401 pass for `/v1/me`.
- `flutter analyze` clean — **only** the 4 pre-existing baseline infos (2× `depend_on_referenced_packages` in splash_page/main, 2× `prefer_const_constructors` in dashboard_page). These live in frozen files — do **not** "fix" them.
- All existing tests pass.
- Real-phone flow: gear → Settings → profile loads → prefs show "Coming soon" → About renders → Change password opens the placeholder → Log out clears the token and lands on `/welcome`.
- No frozen internals modified outside the additive wiring above.
- Commit `feat(settings): …` on Windows when green (don't push until green).

---

## What is deferred (not in this feature)

- **Change password** — backend endpoint (`PUT /v1/auth/password`) + real form logic. A complete routed Flutter sub-section scaffold (domain/data/presentation + bloc + form page) ships now; the user fleshes out the logic and backend later.
- **Delete account** — destructive cascade + backend + confirm flow. No scaffold.
- **Data export** — serialize bills/khata + share. No scaffold.
- **Real language / theme** — i18n + ThemeMode controller. Stubs only for now.
