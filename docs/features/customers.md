# Customers — Feature Doc
**Project:** KhataDost
**Status:** Ready to build
**Scope:** Customer list + search, add, edit, delete (Flutter) + CRUD endpoints (Go)

---

## What this feature does

Lets a shopkeeper manage their customer contacts — the people they sell to and (later) track credit for. A customer is an **identity only**: name, phone, optional email/notes. No balances, no transaction history here — that belongs to the Khata feature, which will foreign-key to the `id` created here.

This feature is the foundation Khata and Billing both stand on. It must exist before either can link a customer.

---

## Customer vs Khata — the boundary (why this is identity-only)

- **A Customer is an identity.** Who the person is. Exists whether or not they ever buy on credit.
- **Khata is a ledger** of credit/payment transactions tied to a customer. The "balance" is *derived* by summing those entries — it is never typed in.
- The customer is the folder; the khata is the transactions inside it.

Decision: this feature stores identity only. The customers list shows **name + phone**, no balance (option A — pure identity). The only khata-adjacent thing exposed is a single boolean, `has_dues`, used to gate deletion (see below).

---

## Schema

```sql
CREATE TABLE customers (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id),  -- multi-tenancy: which shop owns this customer
    name        TEXT NOT NULL,
    phone       TEXT NOT NULL,
    email       TEXT,
    notes       TEXT,
    has_dues    BOOLEAN NOT NULL DEFAULT false,       -- TEMPORARY: flip manually in pgAdmin for testing
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, phone)
);
```

### LLD decisions baked into this schema

1. **`user_id` FK — multi-tenancy.** Every domain table (customers, bills, inventory, khata) carries `user_id`. One database serves many shops without leaking data. The JWT-claims `user_id` extraction already wired in the dashboard handler feeds this.
2. **`id` UUID — the relationship anchor.** Khata will `REFERENCES customers(id)`. UUID over auto-increment int: no guessable sequential IDs in URLs, client-generatable, merge-friendly.
3. **`phone NOT NULL` + `UNIQUE(user_id, phone)` — hard dedup.** Phone is the backbone identifier for a kirana shop (UPI, WhatsApp, reminders). Required, so the unique constraint is a hard "no duplicate customer per shop" guarantee. (No-phone edge case — "old lady with no phone" — handled in real life by storing her son's number.)
4. **`has_dues` is TEMPORARY.** A manually-flipped boolean for now. When Khata ships, this column is **dropped** and `has_dues` becomes computed: `SELECT COALESCE(SUM(amount),0) != 0 FROM khata_entries WHERE customer_id = ...`. The API field name never changes, so the Flutter side never knows the swap happened — same contract-stability principle as auth/dashboard.
5. **`created_at` / `updated_at` — audit columns.** Standard on every table.

---

## Delete policy (gated on dues)

The rule: **delete is permitted only when outstanding balance is zero.**

- Customer **has dues** (`has_dues == true`) → delete option hidden. Cannot delete.
- Dues cleared later via Khata → balance hits zero → delete option appears.
- Customer **never had dues** → delete allowed.

### Defense in depth (two layers, same idea as the router auth guard)

- **Client (UX):** the app hides the delete button when `has_dues == true`.
- **Server (safety):** the DELETE handler **rejects** a delete for a customer with dues, returning `409 Conflict`. Never trust the client — a malformed request or future bug must not be able to erase someone who owes money.

### Hard delete (for now)

Delete is a **hard delete** — the row is gone. Rationale: there is no customer-history screen anywhere in the current plan, and the dashboard's recent-bills stores `customer_name` as a denormalized string (not a live FK join), so deleting a customer orphans nothing today.

> ⚠️ **Khata's feature doc MUST revisit this.** Before khata foreign-keys to `customers`, decide history retention. Soft delete (`deleted_at TIMESTAMPTZ`) is the financially-correct choice once transaction history exists — and writing that migration is a deliberate learning exercise for the Khata session.

### Testing both states now

`has_dues` is flipped directly in pgAdmin. Insert two test customers — one `true`, one `false` — to verify both UI states (delete hidden vs shown) without any mock logic in the Flutter app. The app trusts the field; mocking lives at the DB level.

---

## Search — token inverted index + binary search (the meaty part)

Real shopkeepers type partial names: "s" → "su" → "sur" for "Suresh Sen", **or** they type "sen" (the surname). Both must match. That means matching on **any word (token)** of the name, by prefix.

### Why a plain binary search isn't enough — and why tokens fix it

- Binary search needs the matches **contiguous** in a sorted list, searching on the sorted key.
- "sur" is a prefix of the full string "Suresh Sen" → contiguous → binary search works.
- "sen" sits in the *middle* of "Suresh Sen" → matches scattered across sorted order → plain binary search **fails**.
- **Fix:** shatter each name into tokens (words), build a flat list of `(token, customerId)` pairs sorted by token. Now "sen" is a **prefix of a token** → contiguous again → binary search works on the token list. This is a lightweight **inverted index**.

### The structure

```
Customers:
  c1: "Suresh Sen"
  c2: "Anil Sen"
  c3: "Sunita Devi"

Token index (flat List, sorted by token):
  ("anil",   c2)
  ("devi",   c3)
  ("sen",    c1)
  ("sen",    c2)
  ("sunita", c3)
  ("suresh", c1)
```

Dart shape: `List<({String token, String customerId})>` sorted by `token`. Binary search via `package:collection`'s `lowerBound`.

### The query (half-open prefix range — the DSA gem)

To find all tokens with prefix `p`:
- **lower bound** = first token `>= p`
- **upper bound** = first token `>= p'`, where `p'` = `p` with its **last character incremented** (e.g. `"sen"` → `"seo"`).
- Everything in `[p, p')` is exactly the tokens starting with `p`.

Edge case: if the last char is `z`, carry over (drop it and increment the previous char), or fall back to "scan to end". Worked out at implementation time; the doc records the *approach*.

### Pipeline (search as a pure function)

```
query string
  → normalize (lowercase, trim, split on \s+, drop empties)  [usually 1 token]
  → binary-search token index for [p, p') range
  → collect matched customerIds
  → DEDUP by customerId         (Suresh Sen matches both its tokens on "s")
  → map ids back to Customer objects from the sorted master list
  → result preserves ALPHABETICAL-by-name order (consistent with unfiltered list)
```

`search(index, query) → List<Customer>` is a **pure function** — no BLoC, no I/O. Trivially unit-testable (interview gold: "how do you test search?" → "pure function, here are the cases").

### Normalization rules

Tokens stored **lowercased, trimmed**; query lowercased/trimmed the same way. Split on whitespace runs (`\s+`), drop empty tokens (handles "Suresh  Sen" with double space).

### Index lifecycle (derived state)

The index is **derived from the customer list** and must stay in sync. Rebuilt when:
- List first loads from backend
- A customer is added / edited (name changed → tokens changed) / deleted

Lives in the BLoC, held in state alongside the list, rebuilt on any mutation.

### Honest boundaries (deliberate, documented as choices not gaps)

- **Prefix-of-token only.** "esh" will **not** match "Suresh" — it's a token *prefix*, not a substring. (Substring needs a suffix structure — out of scope.)
- **No typo tolerance.** "sursh" finds nothing. Fuzzy/Levenshtein deferred.
- **No phone search.** Phones are not tokenized. (Clean future extension: fold phone digits into the same index as their own tokens.)

### Why no backend search endpoint

The whole customer list ships to the client once on tab load and lives in memory (5–500 customers). Searching the server would be a wasted round-trip to find something already in RAM. **Search is 100% client-side.**

> Server-side search (`WHERE name ILIKE 'x%'`, backed by a **B-tree index** — which resolves the prefix range via binary search *on disk*, the same algorithm, different home) is deferred until the list outgrows what the client can hold — i.e. when **pagination** is introduced. The prefix semantic stays identical across both layers.

---

## List ordering

Alphabetical by name (`ORDER BY name`). Predictable, easy to scan for a known person. The in-app sorted master list mirrors this and is what binary search relies on.

---

## Screens

### CustomersPage (branch 3 — the tab)
- Search bar at top (filters the in-memory list via the inverted index)
- Alphabetical list of customers; each row: name + phone
- "No customers yet" placeholder when empty; "No matches" when search yields nothing
- FAB or AppBar action: "Add customer"
- Tapping a row → CustomerDetailPage
- Shared gear icon (`ShellActions`) in AppBar

### CustomerDetailPage (minimal stub)
- Shows name, phone, email, notes
- "Edit" button → CustomerFormPage (edit mode)
- "Delete" button — **only rendered when `has_dues == false`**
- Becomes the Khata home (transaction history + balance) later

### CustomerFormPage (shared add + edit)
- Fields: Name, Phone, Email (optional), Notes (optional)
- Add mode: empty form, submit → POST
- Edit mode: pre-filled, submit → PUT
- Inline validation errors (same style as auth forms)

---

## BLoC

Single-state BLoC, `status` enum + `copyWith`. Same shape as `AuthState` / `DashboardState`. Events are pure triggers.

### Events
```dart
CustomersLoadRequested
CustomerAdded(name, phone, email?, notes?)
CustomerUpdated(id, name, phone, email?, notes?)
CustomerDeleted(id)
CustomerSearchChanged(query)
```

### State
```dart
enum CustomersStatus { initial, loading, loaded, error }

class CustomersState extends Equatable {
  final CustomersStatus status;
  final List<Customer> customers;          // full list, alphabetical (source of truth)
  final CustomerSearchIndex? searchIndex;  // derived from `customers`
  final String searchQuery;                // current query ('' = show all)
  final List<Customer> visibleCustomers;   // derived = search(index, query) or full list
  final String? errorMessage;

  // copyWith(...) — same pattern as AuthState/DashboardState
}
```

- `visibleCustomers` is always derived = `f(customers, searchIndex, query)`, recomputed on load/add/edit/delete/searchChanged. Source of truth stays `(customers, query)`; index is derived from `customers`. The page is dumb — it renders `visibleCustomers` only.
- The actual search lives in `CustomerSearchIndex` (domain layer), kept pure and testable.

### Scope
- `CustomersBloc` registered in GetIt, provided at the Customers branch (NOT hoisted to the shell — feature isolation, the lesson from the dashboard refetch refactor).

---

## Data

### Entity (domain — pure Dart, no JSON)
```dart
class Customer {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? notes;
  final bool hasDues;     // gates delete

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.notes,
    required this.hasDues,
  });
}
```

### Search index (domain — pure Dart)
```dart
class CustomerSearchIndex {
  // Built from List<Customer>; holds a flat List<(token, customerId)> sorted by token.
  factory CustomerSearchIndex.build(List<Customer> customers);

  // Pure: returns matching customer ids for a prefix query (deduped).
  Set<String> query(String prefix);
}
```

### Mock data
```dart
[
  Customer(id: 'c1', name: 'Anil Sen',     phone: '9000000001', hasDues: true),
  Customer(id: 'c2', name: 'Meena Devi',   phone: '9000000002', hasDues: false),
  Customer(id: 'c3', name: 'Suresh Sen',   phone: '9000000003', hasDues: false),
  Customer(id: 'c4', name: 'Sunita Kumari',phone: '9000000004', hasDues: true),
]
// c1/c4 has_dues=true → delete hidden; c2/c3 false → delete shown.
// Search "sen" → {c1, c3}; "su" → {c3, c4}; "s" → {c1, c3, c4}.
```

---

## API endpoints

| Method | Path | Auth | Body |
|--------|------|------|------|
| POST | /v1/customers | Yes — Bearer JWT | name, phone, email?, notes? |
| GET | /v1/customers | Yes | — (returns full list) |
| PUT | /v1/customers/{id} | Yes | name, phone, email?, notes? |
| DELETE | /v1/customers/{id} | Yes | — (409 if has_dues) |

### Create / Update request body
```json
{
  "name": "Suresh Sen",
  "phone": "9876543210",
  "email": null,
  "notes": null
}
```

### Customer response (single)
```json
{
  "id": "uuid",
  "name": "Suresh Sen",
  "phone": "9876543210",
  "email": null,
  "notes": null,
  "has_dues": false
}
```

### List response
```json
{
  "customers": [
    { "id": "uuid", "name": "Anil Sen",   "phone": "9000000001", "email": null, "notes": null, "has_dues": true },
    { "id": "uuid", "name": "Suresh Sen", "phone": "9876543210", "email": null, "notes": null, "has_dues": false }
  ]
}
```
Returned `ORDER BY name`.

### Error responses
```json
// 400 — duplicate phone (violates UNIQUE(user_id, phone))
{ "error": "a customer with this phone already exists" }

// 409 — delete blocked by dues
{ "error": "customer has outstanding dues and cannot be deleted" }
```

### Backend logic notes
- All queries scoped by `user_id` from JWT claims.
- POST/PUT: validate name non-empty, phone non-empty; map unique-violation → 400.
- DELETE: check `has_dues` first; if true → 409, else delete.

---

## GoRouter

CustomersPage is branch 3 of the shell (currently a placeholder). Add/detail/edit push **within** the branch so the bottom nav stays visible and the branch stack is preserved.

| Route | Page |
|-------|------|
| /home/customers | CustomersPage (shell branch index 3) |
| /home/customers/add | CustomerFormPage (add mode) |
| /home/customers/:id | CustomerDetailPage |
| /home/customers/:id/edit | CustomerFormPage (edit mode) |

> Whether add/edit are full pages vs modal sheets is a UI-polish decision, deferred. Functionally they're pushed routes for now. Navigation goes through `NavigationCubit` (new methods), never `context.push` directly — same discipline as the rest of the app.

---

## Flutter file map

```
features/customers/
├── domain/
│   ├── entities/
│   │   ├── customer.dart                  ← 1. pure entity
│   │   └── customer_search_index.dart     ← 2. inverted index + binary-search query (pure)
│   └── repositories/
│       └── customer_repository.dart       ← 3. abstract contract
├── data/
│   ├── models/
│   │   └── customer_model.dart            ← 4. JSON ↔ entity
│   ├── datasources/
│   │   ├── customer_datasource.dart       ← 5. abstract interface
│   │   ├── customer_mock_datasource.dart  ← 6. hardcoded mock
│   │   └── customer_remote_datasource.dart← (later) real Dio
│   └── repositories/
│       └── customer_repository_impl.dart  ← 7. delegates to datasource
└── presentation/
    ├── bloc/
    │   ├── customers_event.dart           ← 8.
    │   ├── customers_state.dart           ← 9. status enum + copyWith
    │   └── customers_bloc.dart            ← 10. builds index, runs pure search
    └── pages/
        ├── customers_page.dart            ← 11. list + search bar
        ├── customer_detail_page.dart      ← 12. minimal stub
        ├── customer_form_page.dart        ← 13. shared add/edit
        └── widgets/
            ├── customer_list_tile.dart
            └── customer_search_bar.dart
```

---

## Backend file map

```
internal/
├── handler/
│   └── customer_handler.go    ← POST/GET/PUT/DELETE /v1/customers
├── service/
│   └── customer_service.go    ← validation, dues-check on delete (409)
└── repository/
    └── customer_repository.go ← SQL via sqlc, scoped by user_id

db/
├── migrations/
│   └── 003_create_customers.sql  ← table + UNIQUE(user_id, phone) + temp has_dues
└── queries/
    └── customers.sql             ← insert, list (ORDER BY name), update, delete, get-by-id
```

---

## Build order

1. Flutter — domain (`Customer` entity, `CustomerSearchIndex` with pure query, repo contract)
2. Flutter — **unit-test the search index** (prefix, surname, dedup, empty, normalization cases)
3. Flutter — mock datasource + repo impl
4. Flutter — BLoC (events, state, bloc): load → build index, searchChanged → recompute visible
5. Flutter — CustomersPage UI (list + search bar + list tile, raw/functional)
6. Flutter — CustomerFormPage (shared add/edit)
7. Flutter — CustomerDetailPage stub (delete button gated on `hasDues`)
8. Flutter — GetIt registration + NavigationCubit methods + wire into shell branch 3 + emulator test with mock
9. Go — migration 003 (customers table, unique constraint, temp `has_dues`)
10. Go — sqlc queries (customers.sql)
11. Go — repository → service → handler; routes with JWT middleware; dues-check 409 on delete; unique-violation → 400
12. Flutter — swap mock → real Dio remote datasource
13. End-to-end test: add → appears alphabetically → search by name & surname → edit → delete. Flip `has_dues` in pgAdmin to verify delete-gating both ways.

---

## Reference

Use `features/auth/` and `features/dashboard/` as pattern templates:
- Same feature-first folder structure
- Same single-state BLoC (status enum + copyWith)
- Same GetIt registration approach
- Same Dio error-handling pattern in the remote datasource
- Same contract-first discipline: build Flutter against the mock until the API shape is locked

---

## Key learnings / LLD notes (interview-facing)

- **Multi-tenancy** via `user_id` on every domain table; scope every query by JWT claims.
- **Separation of concerns:** customer screen exposes `has_dues` (boolean), never the balance amount. The *amount* is khata's business; the *deletability* is all this screen needs.
- **Defense in depth:** client hides the delete button (UX); server enforces the 409 (safety). Same shape as the router's auth redirect guard.
- **Design-now-vs-migrate-later:** hard delete now (nothing to protect yet); deliberate soft-delete migration when khata introduces real history. Migrations are a feature, not a chore.
- **Inverted index + binary search:** token-prefix search makes "first name OR surname" matches contiguous in sorted order. The half-open prefix range `[p, p')` is the core trick.
- **Same semantic, two homes:** client-side binary search over a Dart list ≡ Postgres B-tree resolving `ILIKE 'x%'` on disk. Shared *semantic*, not shared code.
- **Search as a pure function:** no I/O, no BLoC dependency → trivially unit-testable.
- **Client-side until pagination:** search stays in-app while the full list fits in memory; server-side search is a *pagination-triggered* enhancement, not a customer-count one.

---

## What is deferred (not in this feature)

- Khata / balances / transaction history → Khata feature (will FK to `customers.id`; must decide soft-delete then)
- Linking a customer to a bill → Billing feature
- Substring-within-token search ("esh" → "Suresh"), fuzzy/typo tolerance, phone search → future search enhancements
- Server-side search + pagination → when the list outgrows client memory
- UI design / Figma polish; modal-sheet vs full-page forms → after all features are functionally complete