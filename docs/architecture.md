# KhataDost — Architecture

This document covers the system design, folder structure, data flow, and key architectural decisions behind KhataDost.

---

## System Overview

KhataDost is split into two independent projects inside a monorepo:

- **`/app`** — Flutter mobile client (`mac` internally)
- **`/backend`** — Go REST API (`mas` internally)

They communicate over HTTP. The mobile app holds no business logic — all validation, computation, and persistence lives in the backend. The app's only job is to present data and dispatch user actions.

---

## Mobile Client (`/app`)

### Pattern: Feature-first Clean Architecture + BLoC

The app is organised by **feature**, not by layer. Every feature is self-contained with its own data, domain, and presentation layers. Nothing leaks across feature boundaries except through `core/`.

```
lib/
├── main.dart                       ← BlocProviders (global) + runApp
├── app.dart                        ← MaterialApp.router + GoRouter
│
├── core/
│   ├── constants/
│   │   ├── api_constants.dart      ← base URL + all endpoint paths
│   │   └── app_constants.dart
│   ├── di/
│   │   └── injection.dart          ← GetIt: registers all blocs, repos, datasources
│   ├── errors/
│   │   ├── failures.dart           ← ServerFailure, NetworkFailure, AuthFailure
│   │   └── exceptions.dart
│   ├── network/
│   │   ├── dio_client.dart         ← Dio singleton with base config
│   │   └── interceptors/
│   │       ├── auth_interceptor.dart   ← attaches JWT to every request
│   │       └── error_interceptor.dart  ← maps 401 → logout, 4xx/5xx → Failure
│   ├── router/
│   │   └── app_router.dart         ← GoRouter config + redirect guard
│   ├── storage/
│   │   └── secure_storage.dart     ← flutter_secure_storage wrapper
│   ├── theme/
│   │   ├── app_theme.dart
│   │   └── app_colors.dart
│   └── widgets/                    ← shared across all features
│       ├── app_button.dart
│       ├── app_text_field.dart
│       └── loading_overlay.dart
│
└── features/
    ├── auth/
    ├── dashboard/
    ├── inventory/
    ├── customers/
    ├── billing/
    ├── khata/
    └── settings/
```

### Inside every feature

```
feature_name/
├── data/
│   ├── models/             ← freezed DTOs with fromJson/toJson
│   ├── datasources/        ← RemoteDatasource: raw Dio calls, returns models
│   └── repositories/       ← RepositoryImpl: implements domain abstract, handles errors
├── domain/
│   ├── entities/           ← pure Dart classes, no serialization
│   └── repositories/       ← abstract class — the contract BLoC depends on
└── presentation/
    ├── bloc/
    │   ├── feature_bloc.dart
    │   ├── feature_event.dart
    │   └── feature_state.dart
    ├── pages/
    └── widgets/            ← widgets scoped to this feature only
```

### State management — Pure BLoC

Every feature uses the full BLoC pattern: explicit event classes, explicit state classes, no Cubits. This keeps state transitions auditable and predictable.

```dart
// Event — what happened
class LoginRequested extends AuthEvent {
  final String email;
  final String password;
}

// State — what the UI should show
class AuthSuccess extends AuthState {
  final User user;
}
```

States use a single-class `copyWith` pattern rather than sealed subclasses.

### Navigation — GoRouter

All routes are defined in `core/router/app_router.dart`. Navigation is handled in two distinct ways:

- **GoRouter redirect guard** — declarative auth protection. If no JWT exists, any `/home/...` route redirects to `/login`. If JWT exists, `/login` and `/register` redirect to `/home/dashboard`. The guard is purely reactive to `AuthBloc` state.
- **NavigationCubit** — all intentional, imperative navigation (e.g. after a form submits) goes through a `NavigationCubit` in `core/navigation/`. Pages never call `context.go()` directly.

### Dependency injection — GetIt

All dependencies are registered in `core/di/injection.dart`. The goal is that adding a new feature never requires touching `main.dart`. The mock-to-real migration for any feature's datasource is a one-line change in `injection.dart`.

---

## Backend (`/backend`)

### Pattern: Layered Clean Architecture

```
backend/
├── cmd/
│   └── api/
│       └── main.go             ← entry point, server bootstrap
├── internal/
│   ├── handler/                ← HTTP layer: parse request, call service, write response
│   ├── service/                ← Business logic: validation, hashing, JWT, orchestration
│   ├── repository/             ← Data access: sqlc-generated queries over PostgreSQL
│   └── model/                  ← Shared domain structs
├── db/
│   ├── migrations/             ← SQL migration files (golang-migrate)
│   └── queries/                ← Raw .sql files — sqlc reads these to generate Go
├── go.mod
└── .env
```

### Request flow

```
HTTP Request
  → Chi Router (middleware: CORS, JWT validation)
  → Handler        (parse JSON → call service)
  → Service        (business logic → call repository)
  → Repository     (sqlc query → PostgreSQL)
  → Response       (service returns model → handler writes JSON)
```

The layers map intentionally to what a Flutter developer already knows:

| Backend layer | Flutter equivalent |
|---|---|
| Handler | UI / Page (receives input, sends output) |
| Service | BLoC (all the logic lives here) |
| Repository | Repository (data access abstraction) |

### Database — PostgreSQL + sqlc

Raw SQL is written in `db/queries/*.sql`. sqlc reads these and generates fully type-safe Go functions in `internal/repository/`. No ORM — queries are explicit and auditable.

Migrations are managed with `golang-migrate`. Each migration is a numbered pair of `.up.sql` and `.down.sql` files.

### Auth — JWT + bcrypt

- Passwords are hashed with bcrypt before storage
- JWTs are signed with a secret from `.env` (HS256)
- All protected routes pass through a JWT middleware registered on the Chi router
- Access code for registration is a single env var (`ACCESS_CODE=KHATA2025`)

---

## Data Flow — End to End

Taking login as a concrete example:

```
1. User types email + password → taps "Log in"
2. LoginPage dispatches LoginRequested event to AuthBloc
3. AuthBloc calls AuthRepository.login(email, password)
4. AuthRepositoryImpl delegates to AuthRemoteDatasource.login()
5. Dio sends POST /v1/login with JSON body
6. Chi router receives request → AuthHandler.login()
7. AuthHandler calls AuthService.login()
8. AuthService fetches user by email via AuthRepository (Go)
9. AuthService compares bcrypt hash → generates JWT
10. Handler writes { token, user } JSON response
11. Dio receives 200 → AuthRemoteDatasource returns AuthResponseModel
12. AuthRepositoryImpl maps model → User entity
13. AuthBloc saves JWT to SecureStorage → emits AuthSuccess(user)
14. GoRouter redirect guard sees AuthSuccess → pushes /home/dashboard
```

---

## Key Decisions

**Flutter-first development.** Each feature is built UI-first with a mocked datasource, then the backend is built to satisfy the exact contract the Flutter code already defines. This eliminates guesswork on the API design.

**One-line mock-to-real swap.** The only difference between a mocked and real datasource is one registration line in `injection.dart`. The rest of the feature code is identical.

**Feature docs before code.** Every feature has a spec in `docs/features/` that defines flows, BLoC events/states, API contracts, and file maps before a line is written. The doc is the source of truth.

**No cross-feature BLoC access.** Features do not read each other's BLoC state directly. Shared state (e.g. current user) lives in `AuthBloc` which is globally provided. Everything else is local to its feature.

---

## Feature Build Status

| Feature | Flutter | Backend | Wired |
|---------|---------|---------|-------|
| Auth | Done | Done | Done |
| Dashboard | Pending | Pending | Pending |
| Inventory | Pending | Pending | Pending |
| Customers | Pending | Pending | Pending |
| Billing | Pending | Pending | Pending |
| Khata | Pending | Pending | Pending |
| Settings | Pending | Pending | Pending |