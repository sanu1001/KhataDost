# Khata — Feature Doc
**Project:** KhataDost
**Status:** Phase 2 (Go backend) + Phase 5 (Flutter) built
**Scope:** Per-customer dues ledger — entry timeline + derived balance + Record Payment. Credit entries are written by billing's settlement transaction (Phase 1); this feature reads the ledger and records payments.

---

## What this feature does

The udhaar (dues) book: **who owes me, and the trail that proves it.** Khata records ONLY balance-moving transactions (§12) — a fully-paid cash bill writes nothing here. Two entry kinds (§11):

| Kind | Source | Items? | Balance effect |
|---|---|---|---|
| `credit` | a bill settled short (written inside billing's settlement tx) | yes — links the bill via `bill_id` | up |
| `payment` | "Record Payment" on the customer's khata page | no — `bill_id` NULL | down |

> **THE INTEGRITY RULE (§12, locked):** balance is **DERIVED** = `Σcredit − Σpayment` — never stored, never typed. Entries are append-only; Record Payment is the ONLY balance-down action. Manual balance-editing does not exist anywhere in the system.

`customers.has_dues` is computed from this ledger (`balance != 0`) in the customers queries — the temp boolean was dropped in migration 006. Flutter customers feature never changed (same `has_dues` field).

## Schema (migration 006)

```sql
khata_entries(id uuid pk, user_id uuid fk users CASCADE,
    customer_id uuid fk customers CASCADE,
    type text /* 'credit' | 'payment' */, amount numeric(12,2),
    bill_id uuid fk bills ON DELETE SET NULL,  -- set on credit, NULL on payment
    note text /* nullable; unused for now */, created_at timestamptz)
-- idx_khata_customer (user_id, customer_id, created_at)
```

`bill_id` is `SET NULL` on bill deletion — a credit entry can therefore exist with a dead link; the timeline renders it as plain credit (not tappable). Balance query: `SUM(CASE WHEN type='credit' THEN amount ELSE -amount END)`.

## API

| Endpoint | Status | Notes |
|---|---|---|
| `GET /v1/khata/{customerId}` | 200 | `{balance, entries:[{id, type, amount, bill_id, note, created_at}]}` — entries **oldest first** |
| `POST /v1/khata/{customerId}/payment` | 201 | body `{amount}` → the created `payment` entry (same entry shape) |

Errors: 400 bad uuid / non-positive amount (`payment amount must be greater than zero`) · 401 · 404 unknown/foreign customer (ownership gate via frozen `CustomerRepository.GetByID`, read-only reuse) · 500. Money fields are JSON numbers; `bill_id`/`note` are JSON null when absent.

## Backend layer map

- `db/queries/khata.sql` → sqlc → `InsertKhataEntry`, `ListKhataEntries`, `GetCustomerBalance` (scalar `:one`)
- `khata_repository.go` — domain `KhataEntry` (BillID/Note `*string`), `InsertEntry` (shared by billing's tx and RecordPayment), `ListByCustomer` (oldest first), `GetBalance`
- `khata_service.go` — `KhataView{Balance, Entries}`, ownership gate, `ErrNonPositivePayment`, `round2` before insert
- `khata_handler.go` — `GetKhata`, `RecordPayment`, sentinel→status map
- `cmd/api/main.go` — khata chain + 2 routes in the protected group
- Bruno: `khata/` — get, payment, 400 non-positive, 404 foreign customer, 401s

---

## Flutter layer (Phase 5) — `features/khata/`

New feature territory. The customer detail page was ALWAYS designed to grow this (customers.md §Screens: "Becomes the Khata home … later") — its one sanctioned touch is a single additive Khata tile navigating to `/home/customers/:id/khata`.

### Pure math — `domain/khata_math.dart` (unit-tested first)

Mirrors the server exactly (advisory display only — the server's `balance` is the figure shown):

- `signedAmount(entry)` — credit +, payment −.
- `balanceOf(entries)` — `round2(Σ signed)`; reuses billing's `round2` (`bills/domain/bill_math.dart`) so money semantics stay identical app-wide.
- `runningBalances(entries)` — oldest-first in, `out[i]` = balance AFTER `entries[i]`; the timeline's per-entry "bal ₹x" column. §12's worked example (500 → +250 → −300 = 450) is a test case.
- `paymentValidationError(amount?)` — null when valid (> 0), else the EXACT server 400 message (client preflight; server stays the authority).

Tests: `test/features/khata/khata_math_test.dart` — bill_math_test style, including the **covariant-list regression group** (entries built via `KhataEntryModel.fromJson(...).toList()` — runtime `List<KhataEntryModel>`; all lookups in khata code are loop-based, never `firstWhere(orElse:)`).

### Layer map

- `domain/entities/khata_entry.dart` — `KhataEntryType {credit, payment}`, `KhataEntry` (id, type, amount, `billId?`, `note?`, createdAt), `Khata` (server-derived `balance` + oldest-first `entries`)
- `domain/khata_math.dart` → `test/features/khata/khata_math_test.dart`
- `domain/repositories/khata_repository.dart` — `getKhata(customerId)`, `recordPayment(customerId, amount)`
- `data/models/khata_model.dart` — `KhataEntryModel` (strict type parse: unknown `type` throws), `KhataModel`
- `data/datasources/` — `khata_datasource.dart` + mock + remote. Mock stays in-tree forever; GetIt comment-swap. Mock mirrors the server's rules + exact messages (400 non-positive) and seeds ledgers coherent with the customers/billing mocks: c1 Anil = credit ₹65 linked to bill `b1` + payment ₹20 (balance 45, has_dues ✓); c4 Sunita = credit ₹30 with `billId: null` (dead bill link — exercises the non-tappable credit row); c2/c3 empty (empty-state UX). Permissive on foreign customer ids (mixed mock/real runs) — ownership 404s are the real server's job.
- `data/repositories/khata_repository_impl.dart` — thin forwarder
- `presentation/bloc/khata_bloc.dart` — see below
- `presentation/pages/customer_khata_page.dart` + `widgets/` (entry tile, record-payment sheet, bill-items sheet)

### KhataBloc — one GetIt singleton, three sub-statuses

Single-state + `copyWith` (+ clear flags), Equatable. The singleton is provided per-route in the customers branch (`BlocProvider.value`), same lifetime model as every other feature bloc. State carries `customerId`; loading a different customer resets the state first.

- `status` (ledger load): `KhataLoadRequested(customerId)` → `getKhata` → entries + server `balance` + bloc-derived `runningBalances` emitted in one consistent state (customers' `visibleCustomers` precedent).
- `paymentStatus` (the Record Payment sheet): `KhataPaymentSubmitted(amount?)` → client preflight (`paymentValidationError`) → `recordPayment` → **re-fetch** `getKhata` → ONE emit: fresh ledger + `success`. Server 400/404 → `paymentError` shown INLINE in the sheet (`_serverMessageOr`, settle-page precedent). `KhataPaymentReset` clears stale sheet state on open.
- `billStatus` (the bill-items sheet): `KhataBillRequested(billId)` → `BillingRepository.getBillById` (read-only reuse of billing's contract) → `bill` in state. Billing pages untouched.

On payment success the PAGE (not the bloc) dispatches `CustomersLoadRequested` to the frozen `CustomersBloc` — public-API reuse, settle-page precedent — so the Customers tab's `has_dues` flips without waiting for a tab re-tap.

### Customer khata page

- **Balance header** — big `₹balance` (server figure): "X owes you" / "Advance — you owe X" (negative = overpay, legal §12) / "All settled".
- **Entry timeline** — newest first (reversed render of the oldest-first list), each row: kind icon, ±₹amount, date, running balance after that entry. Credit rows WITH a live `billId` are tappable → bill-items bottom sheet (read-only: name, qty × price, line total — billing's `formats.dart` helpers reused). Credit rows with `billId: null` and payment rows are plain.
- **Record Payment** — pinned `FilledButton` → bottom sheet (CustomerPickSheet's `static show()` + `BlocProvider.value` mechanism): one amount field, inline error container, submit spinner. Success → sheet pops, snackbar, ledger already re-fetched.
- Empty ledger → "No entries yet" placeholder; load error → message + retry.

### Wiring (all additive)

- `app_routes.dart`: `customerKhata` pattern + `customerKhataPath(id)`
- `app_router.dart`: `:id/khata` sub-route in the customers branch (before `:id`), MultiBlocProvider [KhataBloc, CustomersBloc]
- `navigation_cubit.dart`: `pushKhata(customerId)`
- `injection.dart`: datasource (mock-first comment-swap) → repository → `KhataBloc(khataRepository, billingRepository)`
- `customer_detail_page.dart`: the ONE sanctioned frozen touch — additive Khata tile (sanctioned 2026-06-11, Phase-4 FAB precedent)

### Frozen-feature reuse (all read-only)

- `CustomersBloc` state → customer name on the khata page (`firstWhereOrNull` — test-only closure, covariance-safe); `CustomersLoadRequested` dispatch after payment.
- `BillingRepository.getBillById` → bill-items sheet. (Bills feature is sibling territory, not frozen; its `bill_math.round2` and `formats.dart` are reused as pure helpers.)
