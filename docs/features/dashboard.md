# Dashboard — Feature Doc
**Project:** KhataDost  
**Status:** Ready to build  
**Scope:** Dashboard screen (Flutter) + summary endpoint (Go)

---

## What this feature does

First screen after login. Shows the shopkeeper a quick glance at today's business in under 5 seconds. Primary goal: prove the Flutter ↔ Go ↔ Postgres round-trip end-to-end with real data.

---

## Screen — DashboardPage

Three elements, nothing more.

### 1. Greeting
- "Good morning / Good afternoon / Good evening, {shop_name}"
- Time-aware greeting computed client-side from `DateTime.now()`
- `shop_name` pulled from `AuthBloc` state — no extra API call needed

### 2. Today's sales total
- Label: "Today's Sales"
- Value: ₹{amount} (e.g. ₹3,450)
- Server-computed, IST timezone (Asia/Kolkata), midnight reset
- Shows ₹0 silently if no bills today — no special empty UI

### 3. Recent bills
- Last 3 bills ever created, ordered newest first
- Each row: customer name (or "Walk-in") · ₹{amount} · time ago ("2 hours ago")
- "No bills yet" plain text placeholder if list is empty
- Tapping a row: no-op for now

---

## Loading behavior

- Skeletonizer shimmer on all three sections while `status == loading`
- Refetch on tab focus: every time user switches to Home tab, `DashboardLoadRequested` fires
- No pull-to-refresh in this scope

---

## BLoC

### Event
```dart
class DashboardLoadRequested extends DashboardEvent {
  const DashboardLoadRequested();
}
```

### State
```dart
enum DashboardStatus { initial, loading, loaded, error }

class DashboardState extends Equatable {
  final DashboardStatus status;
  final DashboardSummary? summary;
  final String? errorMessage;

  const DashboardState({
    this.status = DashboardStatus.initial,
    this.summary,
    this.errorMessage,
  });

  DashboardState copyWith({
    DashboardStatus? status,
    DashboardSummary? summary,
    String? errorMessage,
    bool clearError = false,
  });
}
```

Single-state with `copyWith`. Same pattern as `AuthState`.

---

## Data

### Entities (domain layer — pure Dart, no JSON)
```dart
class DashboardSummary {
  final double todaySales;
  final List<RecentBill> recentBills;

  const DashboardSummary({
    required this.todaySales,
    required this.recentBills,
  });
}

class RecentBill {
  final String id;
  final String customerName; // "Walk-in" if no linked customer
  final double amount;
  final DateTime createdAt;

  const RecentBill({
    required this.id,
    required this.customerName,
    required this.amount,
    required this.createdAt,
  });
}
```

### Mock data
```dart
DashboardSummary(
  todaySales: 3450.00,
  recentBills: [
    RecentBill(
      id: 'b1',
      customerName: 'Suresh Kumar',
      amount: 540.00,
      createdAt: DateTime.now(),
    ),
    RecentBill(
      id: 'b2',
      customerName: 'Walk-in',
      amount: 120.00,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    RecentBill(
      id: 'b3',
      customerName: 'Meena Devi',
      amount: 890.00,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ],
)
```

---

## API endpoint

| Method | Path | Auth required |
|--------|------|---------------|
| GET | /v1/dashboard/summary | Yes — Bearer JWT |

### Response shape
```json
{
  "today_sales": 3450.00,
  "recent_bills": [
    {
      "id": "b1",
      "customer_name": "Suresh Kumar",
      "amount": 540.00,
      "created_at": "2026-05-15T10:00:00Z"
    },
    {
      "id": "b2",
      "customer_name": "Walk-in",
      "amount": 120.00,
      "created_at": "2026-05-15T09:00:00Z"
    },
    {
      "id": "b3",
      "customer_name": "Meena Devi",
      "amount": 890.00,
      "created_at": "2026-05-15T07:00:00Z"
    }
  ]
}
```

### Backend logic
- `today_sales` → `SUM(amount)` from `bills` where `created_at` falls within today in IST (`Asia/Kolkata`), midnight to midnight
- `recent_bills` → `SELECT ... ORDER BY created_at DESC LIMIT 3`
- JWT middleware validates token; handler extracts `user_id` from claims (for future per-shop scoping — even if unused now, wire it correctly)

---

## GoRouter

DashboardPage lives inside the `StatefulShellRoute` (bottom nav shell).

| Route | Page |
|-------|------|
| /home/dashboard | DashboardPage (shell branch index 0) |

---

## Bottom nav (locked)

```
Home (0) | Bills (1) | [Scan FAB — center] | Inventory (2) | Customers (3)
Settings → top-right gear icon on DashboardPage AppBar
```

---

## Flutter file map

Build in this order — one file at a time.

```
features/dashboard/
├── domain/
│   ├── entities/
│   │   └── dashboard_summary.dart          ← 1. pure Dart entities
│   └── repositories/
│       └── dashboard_repository.dart       ← 2. abstract contract
├── data/
│   ├── datasources/
│   │   ├── dashboard_datasource.dart       ← 3. abstract datasource interface
│   │   └── dashboard_mock_datasource.dart  ← 4. hardcoded mock, implements interface
│   └── repositories/
│       └── dashboard_repository_impl.dart  ← 5. delegates to datasource
└── presentation/
    ├── bloc/
    │   ├── dashboard_event.dart            ← 6. DashboardLoadRequested
    │   ├── dashboard_state.dart            ← 7. DashboardState + status enum
    │   └── dashboard_bloc.dart             ← 8. handles event, calls repo, emits state
    └── pages/
        └── dashboard_page.dart             ← 9. BlocBuilder + 3 sections + skeletonizer
```

After all 9 files: register in `core/di/injection.dart`, wire into `core/router/app_router.dart`.

---

## Backend file map

```
internal/
├── handler/
│   └── dashboard_handler.go     ← GET /v1/dashboard/summary
├── service/
│   └── dashboard_service.go     ← business logic, timezone handling
└── repository/
    └── dashboard_repository.go  ← SQL queries via sqlc

db/
├── migrations/
│   └── 002_create_bills.sql     ← bills table (minimal: id, user_id, customer_name, amount, created_at)
└── queries/
    └── dashboard.sql            ← today_sales SUM + recent 3 bills
```

---

## Build order (full feature)

1. Flutter — domain layer (entities + repository contract)
2. Flutter — mock datasource + repository impl
3. Flutter — BLoC (event, state, bloc)
4. Flutter — DashboardPage UI (raw, functional, no design)
5. Flutter — GetIt registration + GoRouter wiring + emulator test with mock data
6. Go — bills migration (002)
7. Go — sqlc queries (dashboard.sql)
8. Go — repository → service → handler, wire route with JWT middleware
9. Flutter — swap mock datasource → real Dio remote datasource
10. End-to-end test: login → land on dashboard → see real data from Postgres

---

## Reference

Use `features/auth/` as the exact pattern template:
- Same folder structure
- Same BLoC shape (single state + copyWith + status enum)
- Same GetIt registration approach
- Same Dio error handling pattern in remote datasource

---

## What is deferred

- Outstanding dues → Khata feature
- Low stock alerts → Inventory feature
- Bill detail screen → Billing feature  
- Scan FAB behavior → Billing feature
- Settings screen → Settings feature
- UI design / Figma polish → after all features are functionally complete