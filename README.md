# KhataDost — Digital Ledger for Kirana Shops

> *"Your Ledger's Best Friend"*

KhataDost is a full-stack shop management system built for Indian kirana (local grocery) shopkeepers. It replaces the traditional paper-based *udhaar khata* (credit ledger) with a digital solution — covering billing, inventory, customer credit tracking, and analytics in one place.

---

## The Problem

Indian kirana shopkeepers manage 50+ regular customers on credit (*"udhaar de do"*). They track dues in physical notebooks — error-prone, easy to lose, and impossible to query. KhataDost digitizes this entirely.

---

## Features

| Feature | Description |
|---------|-------------|
| **Auth** | Shopkeeper registration with access-code gating, JWT-based login/logout |
| **Dashboard** | Today's earnings, monthly revenue, top-selling items, outstanding dues |
| **Inventory** | Add/edit/delete items with aliases, stock tracking, low-stock alerts |
| **Smart Billing** | Manual billing or camera scan via Gemini Vision API — mark as cash, udhaar, or partial |
| **Digital Khata** | Per-customer running ledger, payment history, WhatsApp/SMS reminders |
| **Settings** | Shop profile — name, address, UPI ID, phone |

---

## Tech Stack

### Mobile App (`/app`) — Flutter
| Package | Purpose |
|---------|---------|
| Flutter 3.24.3 · Dart 3.5.3 | Framework |
| `flutter_bloc` | State management (BLoC pattern) |
| `go_router` | Navigation + redirect guards |
| `dio` | HTTP client |
| `get_it` | Dependency injection |
| `flutter_secure_storage` | JWT persistence |
| `freezed` + `json_serializable` | Immutable models + JSON |
| `fl_chart` | Analytics charts |
| `camera` / `image_picker` | Billing scan flow |

### Backend (`/backend`) — Go
| Package | Purpose |
|---------|---------|
| Go 1.24.4 | Language |
| `go-chi/chi` | HTTP router |
| `pgx` + `sqlx` | PostgreSQL driver |
| `sqlc` | Type-safe query generation from raw SQL |
| `golang-migrate` | Database migrations |
| `golang-jwt` | JWT auth |
| `bcrypt` | Password hashing |
| `godotenv` | Environment config |
| `go-chi/cors` | CORS middleware |

### Infrastructure
- **Database:** PostgreSQL (local dev via pgAdmin 4)
- **AI Vision:** Google Gemini Vision API (billing scan)
- **SMS:** Fast2SMS (customer reminders)

---

## Architecture

This is a monorepo with two independent projects:

```
KhataDost/
├── app/        ← Flutter mobile client
├── backend/    ← Go REST API
└── docs/       ← Architecture, feature specs
```

### Mobile — Feature-first Clean Architecture

The Flutter app uses a strict feature-first structure with clean architecture layers inside each feature:

```
lib/
├── core/           ← DI, router, network, storage, theme, shared widgets
└── features/
    ├── auth/
    ├── dashboard/
    ├── inventory/
    ├── customers/
    ├── billing/
    ├── khata/
    └── settings/

Each feature/
├── data/           ← models, datasources (Dio), repository impl
├── domain/         ← entities, repository contracts (abstract)
└── presentation/   ← BLoC (events + states), pages, widgets
```

State management uses pure BLoC — explicit events, explicit states, no Cubit shortcuts.

### Backend — Layered Clean Architecture

```
backend/
├── cmd/api/        ← main.go entry point
├── internal/
│   ├── handler/    ← HTTP layer (parse request → call service)
│   ├── service/    ← Business logic
│   ├── repository/ ← DB queries (sqlc generated)
│   └── model/      ← Shared domain types
└── db/
    ├── migrations/ ← SQL migration files
    └── queries/    ← .sql source files for sqlc
```

Request flow: `Handler → Service → Repository → PostgreSQL`

### Data flow between client and backend

```
Flutter UI
  → BLoC event dispatched
  → BLoC calls Repository (domain contract)
  → Repository delegates to RemoteDatasource
  → Dio hits Go REST API
  → Handler → Service → Repository → Postgres
  → Response mapped to domain entity
  → BLoC emits new state
  → UI rebuilds
```

---

## API Overview

All protected routes require `Authorization: Bearer <jwt>`.

```
POST  /v1/register                      Public
POST  /v1/login                         Public

GET   /v1/shop                          Protected
PUT   /v1/shop                          Protected

GET   /v1/items                         Protected
POST  /v1/items                         Protected
PUT   /v1/items/:id                     Protected
DELETE /v1/items/:id                    Protected

GET   /v1/customers                     Protected
POST  /v1/customers                     Protected
GET   /v1/customers/:id                 Protected
POST  /v1/customers/:id/payment         Protected
POST  /v1/customers/:id/remind          Protected

POST  /v1/scan                          Protected  ← Gemini Vision
POST  /v1/bills                         Protected
GET   /v1/bills                         Protected
GET   /v1/bills/:id                     Protected

GET   /v1/analytics/summary             Protected
GET   /v1/analytics/top-items           Protected
GET   /v1/analytics/dues                Protected
```

---

## Docs

- [Architecture →](docs/architecture.md)
- [Auth feature spec →](docs/features/auth.md)

---

## Status

Actively in development. Auth is complete (Flutter + backend). Remaining features being built in order: Dashboard → Inventory → Customers → Billing → Khata → Settings.

---

## Author

Built by @sanu1001 — solo full-stack project.