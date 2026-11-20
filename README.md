# KhataDost: a digital khata for kirana shops

> *"Your Ledger's Best Friend"*

[![Flutter](https://img.shields.io/badge/Flutter-Dart%203.5%2B-blue?logo=flutter)](https://flutter.dev)
[![Go](https://img.shields.io/badge/Go-1.25-00ADD8?logo=go)](https://go.dev)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791?logo=postgresql)](https://postgresql.org)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](docker-compose.yml)

---

## The problem

India has over 12 million kirana stores: small neighbourhood shops that sell everything from rice to shampoo. Almost all of them sell on credit. A customer picks up groceries, says *"udhaar de do"* (put it on my tab), and the shopkeeper writes it in a paper notebook.

That notebook gets lost. Numbers go wrong. And with 50 customers on running tabs, there is no quick way to see who owes what.

KhataDost replaces that notebook and makes it faster. The shopkeeper's mental model stays his paper khata: the AI and the inventory only ever *pre-fill*, every value stays editable, and nothing locks.

---

## What it does

The shopkeeper points the phone camera at the products on the counter. Gemini names each product, the backend matches it to the shop's own inventory at the right price, and the app builds an editable bill. The shopkeeper checks it, picks a customer (or walk-in) and enters how much is paid now. Whatever is left unpaid goes on that customer's khata, and their balance updates at once.

| Screen | What the shopkeeper can do |
|---|---|
| **Dashboard** | Today's sales (with a hide-amount toggle) and the latest bills; refreshes when the tab is reopened |
| **Inventory** | A price book, not a stock ledger: unit items with named variants and prices, or loose items sold by a rate per unit (₹60 per kg) |
| **Bills** | Camera-scan billing, manual billing from inventory, free-typed lines; settle for a customer or a walk-in; bill history with Paid, Partial and Credit badges |
| **Customers** | Add, edit and search customers; delete is blocked while they owe money |
| **Khata** | Each customer's ledger: balance, timeline with a running balance, record a payment, open the bill behind a credit entry |
| **Settings** | Shop profile, logout, About. Language, theme and change password are not built yet |

A bill records how much was paid, not how (cash and UPI are not tracked separately).

### How the scan flow works

```
Shopkeeper points the camera at the products
            ↓
  Gemini names the products (called from the Go backend only)
            ↓
  Backend matches them to this shop's inventory (brand words first)
            ↓
  Matched item                  Not matched
  → card at its                 → label; the shopkeeper types
    default variant               a name and price
            ↓                           ↓
        Review screen (edit name, quantity, price; remove)
                        ↓
        Pick a customer   or   Walk-in (must pay in full)
                        ↓
        Enter the amount paid now (defaults to the bill total)
                        ↓
  Paid in full → bill saved,        Paid short → bill saved, plus a credit
  nothing on the khata              for the bill and a payment for what was paid
```

The balance is always **derived** (sum of credits minus sum of payments) and never stored or typed in. Bill lines store a snapshot of name, price and quantity, so editing or deleting inventory never changes an old bill.

---

## Run it locally

You need:

- **Docker** with Compose. On a Mac, [OrbStack](https://orbstack.dev) works well (Docker Desktop works too).
- **Flutter SDK** for the app, plus Xcode (iOS simulator) or Android Studio (Android emulator).
- Optional, only for working on the backend without Docker: **Go 1.25**, **goose** (`go install github.com/pressly/goose/v3/cmd/goose@v3.26.0`) and **sqlc v1.29.0**.

### 1. Start the backend with Docker

```bash
cp backend/.env.example backend/.env
```

Open `backend/.env` and set:

- `JWT_SECRET`: any long random string, for example the output of `openssl rand -hex 32`
- `ACCESS_CODE`: the code a shop must type to register (pick your own)
- `GEMINI_API_KEY`: a key from Google AI Studio for camera scan. You can leave it empty; everything except scan still works.

`backend/.env` is gitignored. Never commit it, and never put the Gemini key in the Flutter app.

```bash
docker compose up --build
```

This starts three services in order:

1. **db**: Postgres 16. Data lives in a Docker volume, so it survives restarts.
2. **migrate**: runs `goose up` to apply every migration in `backend/db/migrations`, then exits.
3. **api**: the Go server on port **8080**, started only after the migrations succeed.

Check it:

```bash
curl http://localhost:8080/health      # KhataDost backend is running
```

Everyday commands:

| Command | What it does |
|---|---|
| `docker compose up -d --build` | Start in the background (rebuild after code changes) |
| `docker compose logs -f api` | Follow the server logs (one line per request) |
| `docker compose ps` | See which services are running and healthy |
| `docker compose down` | Stop everything, keep the data |
| `docker compose down -v` | Stop everything and **delete** the database volume |
| `docker compose run --rm migrate` | Apply new migrations without restarting the API |

To look inside the database with pgAdmin or psql: host `localhost`, port `5433`, database, user and password all `khatadost`. Postgres is published on `127.0.0.1` only, and on port 5433 so it doesn't clash with another Postgres on 5432.

### 2. Run the Flutter app

The app runs on your machine, outside Docker, and talks to the API on port 8080.

```bash
cd app
flutter pub get
flutter run
```

How the app finds the backend (`app/lib/core/constants/app_constants.dart`):

| Where the app runs | Backend address | Why |
|---|---|---|
| iOS simulator | `http://localhost:8080` (default) | The simulator shares the Mac's network |
| Android emulator | `http://10.0.2.2:8080` (default) | Inside the emulator, `localhost` is the emulator itself; `10.0.2.2` is its alias for your computer |
| Real phone on the same Wi-Fi | pass it yourself | `flutter run --dart-define=API_BASE_URL=http://<your computer's IP>:8080` |

On a Mac, `ipconfig getifaddr en0` prints the Wi-Fi IP. Then register a shop in the app with your `ACCESS_CODE`.

### 3. Work on the backend without Docker (optional)

Run only the database in Docker and the server with Go, which is quicker while editing code:

```bash
docker compose up -d db
docker compose run --rm migrate
cd backend
go run ./cmd/api
```

`backend/.env.example` already points `DATABASE_URL` at the Docker database (`127.0.0.1:5433`). To use your own Postgres instead, change `DATABASE_URL` and run the migrations with goose:

```bash
cd backend
goose -dir db/migrations postgres "$DATABASE_URL" up
```

**Changing SQL:** add a new numbered migration in `backend/db/migrations` (`-- +goose Up` / `-- +goose Down`), never edit an old one. Put queries in `backend/db/queries/*.sql` and run `sqlc generate` in `backend/`. Never edit `backend/internal/sqlcgen/` by hand.

### 4. Tests

```bash
cd backend
go test ./...
```

The Go tests cover the scan feature (Gemini client, scan handler, matcher) and the billing khata rule. The `bruno/` folder holds a [Bruno](https://www.usebruno.com) collection for every endpoint, including error cases (401, 400, 404, 409); open it in Bruno and pick the `local` environment.

### Troubleshooting

- **Port 5433 or 8080 already in use:** set `DB_HOST_PORT` or `API_HOST_PORT` in a `.env` file next to `docker-compose.yml`, for example `API_HOST_PORT=8081`.
- **`env file backend/.env not found`:** you skipped `cp backend/.env.example backend/.env`.
- **Scan answers 502:** `GEMINI_API_KEY` is empty or wrong. **429:** the free Gemini quota is used up; wait a minute.
- **Real Android phone can't connect:** phone and computer must be on the same Wi-Fi, and the address must be passed with `--dart-define`. The app already allows plain HTTP (`usesCleartextTraffic`).
- **Older clones that used `git update-index --skip-worktree` on `app_constants.dart`:** run `git update-index --no-skip-worktree app/lib/core/constants/app_constants.dart` before pulling. The file no longer needs local edits.

---

## Tech stack

### App (`app/`)

Flutter, feature-first clean architecture, single-state BLoC.

| Package | Purpose |
|---|---|
| `flutter_bloc` | State management (one state class per feature with `copyWith`) |
| `go_router` | Navigation shell with one back stack per tab, and the login redirect guard |
| `dio` | HTTP client (one shared client that adds the JWT) |
| `get_it` | Dependency injection (mock and real datasources swapped by one line) |
| `flutter_secure_storage` | Keeps the JWT and the user profile |
| `equatable` | Value equality for states and entities |
| `collection` | Binary search for the name search index |
| `image_picker` | Camera and gallery for the scan flow |
| `skeletonizer` | Loading shimmer |
| `flutter_native_splash` | Native splash screen |

### Backend (`backend/`)

Go, layered as handler → service → repository → sqlc.

| Package | Purpose |
|---|---|
| Go 1.25 | Language |
| `go-chi/chi` | HTTP router and middleware (request logs, panic recovery) |
| `jackc/pgx` + `jmoiron/sqlx` | PostgreSQL driver and transactions |
| `sqlc` | Type-safe Go generated from plain SQL |
| `pressly/goose` | Database migrations |
| `golang-jwt` + `bcrypt` | Login tokens and password hashing |
| `godotenv` | Reads `backend/.env` when running outside Docker |

### External services

| Service | Purpose |
|---|---|
| PostgreSQL 16 | Database |
| Google Gemini (`gemini-2.5-flash`) | Product detection from a photo, called server-side only |

---

## API

Every route except register, login and health needs `Authorization: Bearer <token>`. Errors come back as `{"error": "message"}`.

| Method | Path | What it does |
|---|---|---|
| `GET` | `/health` | Liveness check |
| `POST` | `/v1/register` | Create a shop (needs the access code) and return a token |
| `POST` | `/v1/login` | Log in and return a token |
| `GET` | `/v1/me` | The logged-in shop's profile |
| `GET` | `/v1/dashboard/summary` | Today's sales and the 3 latest bills |
| `GET`, `POST` | `/v1/customers` | List or add customers |
| `PUT`, `DELETE` | `/v1/customers/{id}` | Edit or delete a customer (409 while they owe money) |
| `GET`, `POST` | `/v1/inventory` | List items with variants, or add an item |
| `PUT`, `DELETE` | `/v1/inventory/{id}` | Edit or delete an item |
| `POST` | `/v1/inventory/{id}/variants` | Add a variant to a unit item |
| `PUT`, `DELETE` | `/v1/inventory/{id}/variants/{vid}` | Edit or delete one of that item's variants |
| `POST` | `/v1/scan` | Photo (base64) in, matched inventory cards and unmatched labels out |
| `POST`, `GET` | `/v1/bills` | Settle a new bill, or list bills (newest first) |
| `GET` | `/v1/bills/{id}` | One bill with its lines |
| `GET` | `/v1/khata/{customerId}` | A customer's ledger and balance |
| `POST` | `/v1/khata/{customerId}/payment` | Record a payment |

---

## Repo structure

```
KhataDost/
├── app/                   Flutter app (BLoC · go_router · Dio · GetIt)
├── backend/               Go API
│   ├── cmd/api/main.go    wiring, routes, server start and shutdown
│   ├── internal/          handler · service · repository · sqlcgen · middleware · gemini · db
│   ├── db/migrations/     goose migrations (001 to 007)
│   ├── db/queries/        SQL that sqlc turns into Go
│   ├── Dockerfile
│   └── .env.example
├── bruno/                 API test collection
├── docs/
│   ├── architecture.md    how the whole system fits together
│   └── features/          the design doc written before each feature
└── docker-compose.yml     Postgres + migrations + API
```

Full architecture: [docs/architecture.md](docs/architecture.md)

---

## Status

**v1 is feature-complete:** auth, dashboard, inventory, customers, billing with camera scan, khata and settings all work end to end, checked on a real Android phone.

**Not built yet:**

- Change password (the screen exists; the `PUT /v1/auth/password` endpoint doesn't)
- Hindi/English and theme switching ("coming soon" in Settings)
- Delete account and data export
- Payment reminders (for example a WhatsApp nudge from a customer's khata)
- Deployment (planned: the Go server on Render, Postgres on Neon, the APK shared directly)

---

*Solo project by [sanu1001](https://github.com/sanu1001). Built to learn Go backend development while solving a real problem.*
