# Billing — Feature Doc
**Project:** KhataDost
**Status:** Phase 1 (Go backend) built — Flutter in Phase 4
**Scope:** Bill creation with settlement (cash / credit / partial) + bill reads (Go). Scan endpoint is Phase 3; bill-builder UI is Phase 4; khata entries land in Phase 2.

---

## What this feature does

Persists the headline loop's output: **an editable bill of line items, settled against a customer or a walk-in.** Every sale (cash or credit) becomes a `bills` row + N `bill_items` rows in one transaction. Bills answer "what did I sell?" — sales history, dashboard's today's-sales. The dues side ("who owes me?") is khata's job, wired into this same transaction in Phase 2.

> **Locked in the Scan → Bill decision log (§8–§12).** The bill screen is the shopkeeper's notebook: every cell editable, AI/inventory only pre-fill. The server therefore trusts the client's *lines* (name/qty/price as edited) but **recomputes every money figure** — line totals and the bill total are server-derived, never accepted from the client.

---

## The core model — resolved snapshots, not live pointers

A bill line stores the **RESOLVED result** of however the price was derived (swiped variant, loose rate × measure, or free-typed miscellaneous): `name + quantity + unit_price + line_total`, denormalized. `item_id` / `variant_id` are nullable provenance pointers with `ON DELETE SET NULL` — deleting inventory can never orphan or change a bill.

Line shapes by origin:

| Origin | item_id | variant_id | quantity means |
|---|---|---|---|
| Type A (unit item, swiped variant) | set | set | count (2.000) |
| Type B (loose item, typed measure) | set | NULL | measure (0.750 kg) |
| Miscellaneous (free-typed) | NULL | NULL | count |

The same resolution applies to the bill header: `customer_name` is a denormalized snapshot (server-side, from the customers row — or `"Walk-in"`), so deleting a customer (`ON DELETE SET NULL` on `bills.customer_id`) keeps sales history rendering correctly.

## Schema (migration 005 — ALTERs the 002 stub, never edits it)

```sql
ALTER TABLE bills
    ADD COLUMN customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,  -- NULL = walk-in
    ADD COLUMN amount_paid NUMERIC(12,2) NOT NULL DEFAULT 0;
-- bills.amount stays = bill TOTAL (dashboard sums it — name is load-bearing).

CREATE TABLE bill_items (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bill_id     UUID NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
    item_id     UUID REFERENCES items(id) ON DELETE SET NULL,
    variant_id  UUID REFERENCES item_variants(id) ON DELETE SET NULL,
    name        TEXT NOT NULL,
    quantity    NUMERIC(12,3) NOT NULL,        -- 3 decimals: counts AND measures
    unit_price  NUMERIC(12,2) NOT NULL,
    line_total  NUMERIC(12,2) NOT NULL,        -- quantity × unit_price, server-computed
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_bill_items_bill_id ON bill_items (bill_id);
```

### LLD decisions baked into this schema

1. **Grow the stub by ALTER in a NEW migration** (005) — migrations 001–004 are immutable history; `bills.amount` keeps its name because `GetTodaySales` sums it.
2. **`customer_id` nullable-by-design** — NULL *means* walk-in; not a missing value.
3. **`NUMERIC(12,3)` for quantity** — one column serves both counts (Type A: 2.000) and measures (Type B: 0.750). Money stays `NUMERIC(12,2)`.
4. **Delete-safety triangle:** bill→items `CASCADE` (lines die with their bill), items/variants→bill_items `SET NULL` (inventory deletion never touches a bill), customers→bills `SET NULL` (sales history outlives the contact).
5. **`bill_items` carries no `user_id`** — tenancy is transitive through the user-scoped bill lookup, same as `item_variants` through items.
6. **Query column order = DDL order** (`…created_at, customer_id, amount_paid`) — ALTER-appended columns trail, and matching DDL order lets sqlc reuse the `Bill` model instead of per-query Row structs.
7. **Line order within a bill is not persisted.** All lines share the transaction's `NOW()`; `GetBillItems` orders by `(created_at, id)` for determinism, but uuid order ≠ insertion order. The CREATE response preserves insertion order; a re-fetch may not. Cosmetic at kirana scale; a `position` column is the future fix if it ever matters.

## Settlement (the integrity core)

One transaction (`BeginTxx` + `defer Rollback` + `New(tx)`, same shape as inventory's create): insert bill header → insert N lines → *(Phase 2: insert khata entries)* → commit.

Settle math, all server-side:

- `line_total = round2(quantity × unit_price)`; `amount` (total) `= round2(Σ line_total)`.
- `amount_paid` omitted → defaults to total ("paying now" pre-fills; cash sale = one tap).
- **Walk-in:** `amount_paid` must equal total exactly → else **409**. No ledger to owe against; overpay is meaningless.
- **Customer:** any `amount_paid ≥ 0` is legal, *including > total* (the surplus pays down old dues: owes 500, bill 250, pays 300 → 450). Customer must belong to this user (frozen `CustomerRepository.GetByID` reused read-only as the ownership gate + name snapshot) → else **404**.
- **Khata writes (computed now, written in Phase 2):** `paid == total` → nothing (a settled bill has no place in the dues book). `paid != total` → `credit` entry = total (linked to the bill) +, if `paid > 0`, `payment` entry = paid. Balance stays derived, never stored.

## API

| Endpoint | Status | Notes |
|---|---|---|
| `POST /v1/bills` | 201 | body: `{customer_id?, amount_paid?, items:[{item_id?, variant_id?, name, quantity, unit_price}]}` |
| `GET /v1/bills` | 200 | `{bills:[…]}` headers only, newest first, `items: []` |
| `GET /v1/bills/{id}` | 200 | header + nested `items` |

Errors: 400 invalid body / empty items / bad uuid / non-positive quantity / negative price or amount_paid · 401 no/bad token · 404 unknown customer or bill (user-scoped) · 409 walk-in not paid in full.

Response money fields are JSON numbers (`amount`, `amount_paid`, `quantity`, `unit_price`, `line_total`); `customer_id`/`item_id`/`variant_id` are null per the table above.

## Layer map (follows the four built features exactly)

- `db/queries/bills.sql` → sqlc → `internal/sqlcgen/bills.sql.go`
- `billing_repository.go` — `CreateBillWithItems` (the tx), `ListBills`, `GetBillByID`; NUMERIC↔float at this boundary; `ErrBillNotFound`.
- `billing_service.go` — validation, server-side money math, walk-in/customer branch, khata computation; `ErrEmptyBill`, `ErrInvalidLine`, `ErrNegativeAmountPaid`, `ErrWalkInMustPayFull`.
- `billing_handler.go` — decode/validate + body-uuid parsing, sentinel→status map, response mapping.
- `cmd/api/main.go` — additive chain + 3 routes in the protected group.
- Bruno: `bills/` folder — cash, credit, partial, walk-in-409, list, get, 401 (env vars `customerId`, `billId`).
