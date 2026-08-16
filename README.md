# KhataDost — Digital Khata for Kirana Shops

> *"Your Ledger's Best Friend"*

[![Flutter](https://img.shields.io/badge/Flutter-3.24.3-blue?logo=flutter)](https://flutter.dev)
[![Go](https://img.shields.io/badge/Go-1.24-00ADD8?logo=go)](https://golang.org)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?logo=postgresql)](https://postgresql.org)

---

## The Problem

India has over 12 million kirana stores — small neighbourhood shops that sell everything from rice to shampoo. Every one of them runs on credit. A customer walks in, picks up groceries, says *"udhaar de do"* (put it on my tab), and the shopkeeper writes it down in a paper notebook.

That notebook gets lost. Numbers go wrong. And when 50 customers all have running tabs, there is no fast way to know who owes what.

KhataDost replaces that notebook — and makes it faster. The shopkeeper's mental model is his paper khata; AI and inventory only ever *pre-fill*, every value stays editable, and nothing locks.

---

## What It Does

A shopkeeper opens the app and points their phone camera at the products on the counter. The AI identifies each item, matches it to the shop's own inventory at the right price, and builds an editable bill. The shopkeeper reviews it, picks a customer (or walk-in), and settles as cash, UPI, or credit. If any amount is left unpaid, it goes on that customer's khata and their running balance updates instantly.

**Three core flows:**

**1. Smart billing via camera**
Point camera at products → Gemini identifies items → matched against the shop's own inventory → review and edit → settle. The Gemini key lives only in the Go backend; it never ships in the app.

**2. Manual billing**
Search inventory → add items → same review and settle screen. A floating scan button is always available to switch to the camera mid-bill.

**3. Digital khata**
Every customer has a running ledger. Balance is always *derived* (Σ credit − Σ payment), never hand-typed. Full transaction timeline, outstanding balance at a glance, one-tap record-payment.

---

## Features

| Screen | What the shopkeeper can do |
|--------|---------------------------|
| **Dashboard** | Today's sales hero card (with hide-amount toggle) and the most recent bills, refetched on tab focus |
| **Inventory** | A price book (not a stock ledger): items with named variants/prices (Type A) or a loose rate-per-unit (Type B). Add, edit, delete items and variants |
| **Bills** | Camera-scan billing, manual search billing, settle as cash / UPI / credit, full bill history with Paid/Partial/Credit badges |
| **Customers** | Add, edit, and search customers; dues-gated delete; each customer's khata ledger with record-payment |
| **Settings** | Shop profile (name, owner, phone), logout, preferences (Hindi/English + theme — coming soon), About. Change-password screen scaffolded |

---

## Design System (v1 UI refresh)

The whole app shares one visual language, defined in `app/lib/core/theme/app_theme.dart` and `app/lib/core/widgets/`:

- **Palette** — vivid violet primary (`#7C3AED`) on a lavender-white canvas, amber accents for dues, semantic green/red/amber for paid/credit/partial.
- **Splash** — solid-violet native splash that hands off to an animated in-app splash (logo mark scale-fade + wordmark slide) while the saved-token check runs.
- **Loading** — `skeletonizer` shimmer on every data screen (dashboard, bills, customers, khata, pick sheets) — no bare spinners on lists.
- **Feedback** — one `AppSnackbar` (success/error/info pills), one `showConfirmDialog` (destructive actions all confirm first), one `EmptyState` (empty + error bodies with retry).

---

## Tech Stack

### Mobile App (`/app`)
Flutter, feature-first clean architecture, single-state BLoC.

| Package | Purpose |
|---------|---------|
| Flutter · Dart | Framework |
| `flutter_bloc` | State management (single-state + `copyWith`) |
| `go_router` | Navigation shell + auth redirect guards |
| `dio` | HTTP client (shared client + JWT interceptor) |
| `get_it` | Dependency injection (mock ⇄ remote comment-swap) |
| `flutter_secure_storage` | JWT persistence |
| `equatable` | Value equality for state/entities |
| `collection` | Inverted-index + binary-search name lookup |
| `image_picker` | Camera / gallery capture for the scan flow |
| `skeletonizer` | Loading shimmer |
| `flutter_native_splash` | Native splash (brand violet, color-only) |

### Backend (`/backend`)
Go, layered Handler → Service → Repository → sqlc architecture.

| Package | Purpose |
|---------|---------|
| Go 1.24 | Language |
| `go-chi/chi` | HTTP router |
| `jackc/pgx` + `jmoiron/sqlx` | PostgreSQL driver |
| `sqlc` | Type-safe Go from raw SQL |
| `pressly/goose` | Database migrations |
| `golang-jwt` + `golang.org/x/crypto/bcrypt` | Auth (JWT + password hashing) |
| `godotenv` | Config |

### External Services
| Service | Purpose |
|---------|---------|
| PostgreSQL 16 | Primary database |
| Google Gemini (`gemini-2.5-flash`) | AI item detection from the camera, called server-side |

---

## How the Scan Flow Works

```
Shopkeeper points camera at products
            ↓
  Gemini identifies item names (server-side)
            ↓
  Backend keyword-matches against the shop's inventory
            ↓
  Matched item                 Not matched
  → card at its                → "not in inventory"
    default variant              name + price typed in
            ↓                          ↓
          Review screen (edit name, qty, price; remove)
                      ↓
          Pick customer   or   Walk-in (must pay in full)
                      ↓
          Enter amount paid (defaults to bill total)
                      ↓
   Fully paid → bill saved        Part/unpaid → khata credit
   nothing on khata               + payment entries written
```

A bill line stores its resolved result (name + price + qty + line total) **denormalized**, so deleting inventory never orphans a bill.

---

## Repo Structure

```
KhataDost/                  ← single .git at root
├── app/                    ← Flutter mobile client (BLoC · go_router · Dio · GetIt)
├── backend/                ← Go REST API (Chi · sqlx · pgx · sqlc · goose · Postgres)
├── bruno/                  ← API test collections
└── docs/
    ├── architecture.md
    └── features/           ← one design doc per feature
        ├── auth.md
        ├── dashboard.md
        ├── customers.md
        ├── inventory.md
        ├── billing.md
        ├── khata.md
        ├── scan.md
        └── settings.md
```

Full architecture → [docs/architecture.md](docs/architecture.md)

---

## Build Status — v1 feature-complete

| Feature | Flutter | Backend | Wired |
|---------|---------|---------|-------|
| Auth | ✅ | ✅ | ✅ |
| Dashboard | ✅ | ✅ | ✅ |
| Inventory | ✅ | ✅ | ✅ |
| Customers | ✅ | ✅ | ✅ |
| Billing (+ camera scan) | ✅ | ✅ | ✅ |
| Khata (ledger) | ✅ | ✅ | ✅ |
| Settings | ✅ | ✅ | ✅ |

Billing and khata were verified end-to-end on a physical device. A full A-Z UI pass (unified violet design system, skeleton loading, consistent popups, animated splash) landed after feature-complete.

---

## Roadmap (not yet built)

- **Change password** — UI scaffold is in place; the `PUT /v1/auth/password` endpoint and form logic are pending.
- **Delete account** and **data export**.
- **Hindi/English localization** and **theme switching** (shown as "coming soon" in Settings today).
- **Payment reminders** (e.g. a one-tap WhatsApp nudge from a customer's khata).

---

*Solo project by Sanu1001. Built to learn Go backend development while solving a real problem.*
