# KhataDost — Architecture

---

## Overview

KhataDost is a monorepo containing two independent projects:

- **`/app`** — Flutter mobile client
- **`/backend`** — Go REST API

They communicate over HTTP. The app holds no business logic — all validation, computation, and persistence lives in the backend. The app's job is to present data and dispatch user intent.

---

## Mobile Client (`/app`)

### Pattern: Feature-first Clean Architecture + Pure BLoC

The app is organised by feature. Each feature is self-contained with its own data, domain, and presentation layers. Nothing leaks across feature boundaries except through `core/`.

```
lib/
├── main.dart                          ← global BlocProviders + runApp
├── app.dart                           ← MaterialApp.router + GoRouter init
│
├── core/
│   ├── constants/
│   │   ├── api_constants.dart         ← base URL + all endpoint paths
│   │   └── app_constants.dart
│   ├── di/
│   │   └── injection.dart             ← GetIt: all blocs, repos, datasources
│   ├── errors/
│   │   ├── failures.dart              ← ServerFailure, NetworkFailure, AuthFailure
│   │   └── exceptions.dart
│   ├── network/
│   │   ├── dio_client.dart            ← Dio singleton
│   │   └── interceptors/
│   │       ├── auth_interceptor.dart  ← attach JWT to every request
│   │       └── error_interceptor.dart ← 401 → logout, 5xx → Failure
│   ├── router/
│   │   └── app_router.dart            ← GoRouter config + redirect guard
│   ├── storage/
│   │   └── secure_storage.dart        ← flutter_secure_storage wrapper
│   ├── theme/
│   └── widgets/                       ← shared: AppButton, AppTextField, etc.
│
└── features/
    ├── auth/
    ├── dashboard/
    ├── inventory/
    ├── billing/
    ├── customers/
    └── settings/
```

### Inside every feature

```
feature_name/
├── data/
│   ├── models/             ← freezed DTOs (fromJson / toJson)
│   ├── datasources/        ← RemoteDatasource: Dio calls, returns models
│   └── repositories/       ← RepositoryImpl: maps models → entities, handles errors
├── domain/
│   ├── entities/           ← pure Dart, no serialisation
│   └── repositories/       ← abstract class (the contract BLoC depends on)
└── presentation/
    ├── bloc/
    │   ├── feature_bloc.dart
    │   ├── feature_event.dart
    │   └── feature_state.dart
    ├── pages/
    └── widgets/
```

### State management — Pure BLoC

Explicit event classes, explicit state classes. No Cubits. State transitions are traceable and predictable.

```dart
// What happened
class LoginRequested extends AuthEvent {
  final String email;
  final String password;
}

// What the UI renders
class AuthSuccess extends AuthState {
  final User user;
}
```

States use a single-class `copyWith` pattern.

### Navigation — GoRouter

Two distinct responsibilities, handled separately:

- **Redirect guard** (declarative) — if no JWT, any `/home/...` redirects to `/login`. If JWT exists, `/login` and `/register` redirect to `/home/dashboard`. Purely reactive to AuthBloc state.
- **NavigationCubit** (imperative) — all intentional navigation after user actions goes through a central NavigationCubit. Pages never call `context.go()` directly.

### Routes

```
/                           SplashPage
/login                      LoginPage
/register                   RegisterPage
/home                       MainShell (StatefulShellRoute + bottom nav)
  /home/dashboard           DashboardPage
  /home/inventory           InventoryPage
  /home/inventory/add       AddEditItemPage
  /home/inventory/:id       AddEditItemPage (edit mode)
  /home/bills               BillsPage
  /home/bills/scan          ScanPage
  /home/bills/history/:id   BillDetailPage
  /home/customers           CustomersPage
  /home/customers/add       AddCustomerPage
  /home/customers/:id       CustomerDetailPage
  /home/settings            SettingsPage
```

Bottom nav: Home | Bills | [Scan — centre floating] | Customers | Settings

### Dependency Injection — GetIt

All dependencies registered in `core/di/injection.dart`. Adding a feature never requires touching `main.dart`. Mock-to-real migration for any datasource is one line changed in `injection.dart`.

---

## Backend (`/backend`)

### Pattern: Layered Clean Architecture

```
backend/
├── cmd/api/
│   └── main.go              ← server bootstrap, middleware chain, route registration
├── internal/
│   ├── handler/             ← HTTP: parse request → call service → write response
│   ├── service/             ← Business logic: validation, hashing, JWT, orchestration
│   ├── repository/          ← Data: sqlc-generated type-safe queries
│   └── model/               ← Shared domain structs
├── db/
│   ├── migrations/          ← .up.sql / .down.sql pairs (golang-migrate)
│   └── queries/             ← raw .sql files sqlc reads to generate Go
├── go.mod
└── .env
```

### Request flow

```
HTTP Request
  → Chi router (CORS middleware, JWT middleware on protected routes)
  → Handler      (decode JSON body → validate → call service)
  → Service      (business logic → call repository)
  → Repository   (sqlc query → PostgreSQL)
  → Handler      (encode response JSON → write status)
```

### Database — PostgreSQL + sqlc

Raw SQL lives in `db/queries/*.sql`. sqlc reads these and generates fully type-safe Go functions. No ORM — every query is explicit and reviewable.

Migrations managed with golang-migrate. Each migration is a numbered `.up.sql` / `.down.sql` pair.

### Auth — JWT + bcrypt

- Passwords hashed with bcrypt before storage
- JWTs signed with HS256 using a secret from `.env`
- JWT middleware on all protected routes via Chi middleware chain
- Registration gated by a single access code env var (`ACCESS_CODE`)

### API endpoints

```
POST   /v1/register                     Public
POST   /v1/login                        Public

GET    /v1/shop                         🔒
PUT    /v1/shop                         🔒

GET    /v1/items                        🔒
POST   /v1/items                        🔒
PUT    /v1/items/:id                    🔒
DELETE /v1/items/:id                    🔒

GET    /v1/customers                    🔒
POST   /v1/customers                    🔒
GET    /v1/customers/:id                🔒
POST   /v1/customers/:id/payment        🔒

POST   /v1/scan                         🔒  ← image → Gemini → matched items
POST   /v1/bills                        🔒
GET    /v1/bills                        🔒
GET    /v1/bills/:id                    🔒

GET    /v1/analytics/summary            🔒
```

---

## End-to-End Data Flow (Scan Billing)

```
1.  Shopkeeper taps scan → camera opens (ScanPage)
2.  Image captured → ScanRequested event dispatched to BillingBloc
3.  BillingBloc calls BillingRepository.scan(imageBytes)
4.  RemoteDatasource sends POST /v1/scan with image
5.  Handler receives image → calls BillingService.scan()
6.  Service sends image to Gemini Vision API
7.  Gemini returns detected item names
8.  Service queries inventory: for each name, fuzzy match against shop's items
9.  Returns: matched items (with DB price + stock) + unmatched items (name only)
10. Handler writes JSON response
11. BillingBloc receives ScanSuccess(items)
12. UI renders review screen:
      - Matched items → quantity editable
      - Unmatched items → name + price editable, flagged as "Not in inventory"
13. Shopkeeper edits, taps Proceed
14. Customer selected (or walk-in)
15. Payment type: Cash or Udhaar
16. BillConfirmed event → POST /v1/bills
17. Backend: saves bill, deducts stock, updates khata if udhaar
18. BillingBloc emits BillSuccess → UI shows confirmation
```

---

## Key Decisions

**Flutter-first development.** Each feature is built UI-first with a mocked datasource. The backend is then built to satisfy the exact contract the Flutter code already defines. No guesswork on API design.

**One-line mock-to-real swap.** The only difference between mock and real is one registration line in `injection.dart`.

**Unmatched items are first-class.** When Gemini detects something not in the shop's inventory, it doesn't fail or get silently dropped — it surfaces in the review screen as an editable card. The shopkeeper stays in control.

**Cash or udhaar only.** No UPI or payment gateway integration. Keeps the billing flow fast and removes a significant surface area of complexity for a real-world demo.

**Feature docs before code.** Every feature has a spec in `docs/features/` defining flows, BLoC events/states, API contracts, and file maps before any code is written.