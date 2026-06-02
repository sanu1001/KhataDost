# Inventory — Feature Doc
**Project:** KhataDost
**Status:** Ready to build
**Scope:** Item list + search, add, edit, delete with variants (Flutter) + CRUD endpoints (Go)

---

## What this feature does

Lets a shopkeeper manage their **price book** — the items they sell and what those items cost. It is the data layer the scan-to-bill flow and the manual bill builder both read from to price a line. It is **not** a stock ledger: no counts, no decrement on sale, no low-stock alerts.

> **Locked in the Scan → Bill decision log (§8, §10).** Inventory = price book, not stock. Rationale: a shopkeeper won't keep accurate counts, and an unmaintained count is worse than none. If he can search an item, it's physically on the counter — the app's only job is to price it fast. The dashboard "low stock" tile is dropped.

---

## The core model — one item, many price points (why parent/child)

An inventory item is **a family of price points under one searchable name.** "Lays" is one card; its variants are small ₹10 / medium ₹20 / large ₹50. The **variant** is the thing that lands on a bill line, not the bare item.

Two pricing types, decided by a `pricing_type` column on the item:

- **Type A — unit-priced (swipe card).** Discrete variants the shopkeeper swipes between. Lays S ₹10 / M ₹20 / L ₹50. The picked variant *is* the price. → modeled as **`items` one-to-many `item_variants`**.
- **Type B — loose / weight-priced (quantity card).** One fixed rate + unit, e.g. sugar ₹20/kg. No variants to swipe; the shopkeeper types a measure (750g) and the line cost computes live. → modeled as **`rate` + `unit` directly on the item row, no variants child.**

### Why not a single polymorphic FK (the rejected design)

The naive first instinct is `items { ..., type_ref → itemA or itemB }` — a foreign key pointing at *either* of two tables. This is a **polymorphic FK** and it breaks relational integrity: a FK must reference exactly one table, the DB can't enforce it, and every join needs a runtime branch. Rejected.

The correct shape is a **parent/child one-to-many**: a single `items` parent, with the *variation* (Type A's many price points) pushed into a child table. Type B simply has zero children because its price is fully described by two columns on its own row — a child table for Type B would always be empty and meaningless.

---

## Schema

```sql
-- pricing_type enum values: 'unit' (Type A) | 'loose' (Type B)

CREATE TABLE items (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,  -- multi-tenancy
    name         TEXT NOT NULL,                       -- the searchable name, e.g. "Lays"
    pricing_type TEXT NOT NULL,                       -- 'unit' | 'loose'
    rate         NUMERIC(12,2),                       -- Type B only; NULL for Type A
    unit         TEXT,                                -- Type B only ('kg','g','litre'); NULL for Type A
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, name)                            -- no duplicate item name per shop
);

CREATE TABLE item_variants (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id      UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,  -- the one-to-many anchor
    label        TEXT NOT NULL,                       -- 'small', '500ml'
    price        NUMERIC(12,2) NOT NULL,
    is_default   BOOLEAN NOT NULL DEFAULT false,      -- the base variant the scan/card lands on
    description  TEXT,                                -- optional, nullable
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_item_variants_item_id ON item_variants (item_id);

-- Guarantees AT MOST ONE default variant per item (the ≤1 half).
-- The ≥1 half (every Type A item has exactly one default) is enforced in the service layer.
CREATE UNIQUE INDEX idx_one_default_per_item
    ON item_variants (item_id) WHERE is_default;
```

### LLD decisions baked into this schema

1. **`user_id` FK — multi-tenancy.** Same as every domain table. Every query scoped by JWT-claims `user_id`.
2. **`pricing_type` decides everything downstream** — which card renders (swipe vs quantity), which columns are populated, whether variants exist. It is the discriminator the whole feature branches on.
3. **`rate` / `unit` nullable *by design*.** They are NULL for Type A items — not an accident, a deliberate "these fields don't apply to this row type." (Interview answer: nullable-by-design, not nullable-by-laziness.)
4. **`item_variants.item_id` is where the one-to-many lives.** Child holds the FK to the parent. One item, many variant rows. `ON DELETE CASCADE` → deleting an item auto-drops its variants.
5. **`is_default` + partial unique index — defense in depth (same shape as the customers delete guard).** The partial unique index `WHERE is_default` lets the DB enforce *at most one* default per item; the service layer enforces *at least one* on a Type A item. Together = exactly one. The scan flow drops the card at the default variant; the shopkeeper swipes if it's wrong.
6. **`UNIQUE(user_id, name)` — no duplicate item per shop.** Mirrors customers' `UNIQUE(user_id, phone)`. Maps to a 400/409 on insert (SQLSTATE `23505`).
7. **`NUMERIC(12,2)` for money** (price, rate), never float — same money convention as `bills.amount`. Comes back as `string` from the `database/sql` driver → `strconv.ParseFloat` in the repository.

---

## Type-shape rules (enforced in the service layer)

`pricing_type` constrains which fields/children are valid. These are cross-field rules → they live in the **service layer** as sentinel errors, not in the DB:

| Rule | Type A (`unit`) | Type B (`loose`) |
|---|---|---|
| `rate`, `unit` | must be NULL | must be NOT NULL |
| `item_variants` | ≥ 1, exactly one `is_default` | **none allowed** |

> **The variant guard you reasoned out.** Before inserting a row into `item_variants`, the service reads the parent's `pricing_type`; if it's `'loose'`, it rejects the insert (returns a sentinel → handler maps to 409/400). The repository just runs the SQL it's told to — the *rule* lives one layer up, exactly like the dues-check on customer delete.

---

## Delete policy (hard delete — safe here)

Hard delete, no dues-style gate. Deleting an item is safe because **bill lines store the resolved result** (denormalized name + chosen price + qty + line total), not a live FK to the variant — same denormalization principle as the dashboard's `customer_name`. Deleting "Lays" orphans nothing on bills already written.

`ON DELETE CASCADE` on `item_variants.item_id` → deleting an item drops its variants in one statement.

> Consistent with the customers hard-delete rationale: nothing financial is protected by keeping the row, because history is already denormalized onto the bill.

---

## Search — reuse the customers inverted index

Items are searched by **name**, exactly like customers were searched by name. Reuse the **token inverted index + binary-search prefix range** built for customers (`lowerBound` over a flat sorted `List<({String token, String itemId})>`, half-open `[p, p')` range). Same pure-function, unit-testable shape.

- Search is **100% client-side** — the full item list ships to the client on tab load and lives in memory (a kirana's price book is small). No backend search endpoint, same rationale as customers (deferred until pagination).
- The index is **derived from the item list**, rebuilt on load / add / edit / delete.

> Generalize the customers `SearchIndex` or duplicate it — decide at build time. The token/binary-search semantics are identical; only the entity it maps back to changes.

---

## API endpoints (7)

The single-item-by-id lookup for AI matching is **not** here — it's a billing/scan concern, deferred. Inventory ships the full list to the client; detail and search are in-memory.

| Method | Path | Auth | Body / Notes |
|--------|------|------|--------------|
| POST | /v1/inventory | Yes | item + (Type A) inline `variants[]` — **one transaction** |
| GET | /v1/inventory | Yes | full list, each Type A item with nested `variants[]` |
| PUT | /v1/inventory/{id} | Yes | update item fields (name, rate, unit) |
| DELETE | /v1/inventory/{id} | Yes | hard delete; cascades variants |
| POST | /v1/inventory/{id}/variants | Yes | add a variant to an existing Type A item |
| PUT | /v1/inventory/{id}/variants/{vid} | Yes | update a variant |
| DELETE | /v1/inventory/{id}/variants/{vid} | Yes | delete a variant |

> **Create takes variants inline; later edits are granular.** A Type A item with zero variants is useless, so `POST /v1/inventory` creates the item *and* its initial variants atomically (one DB transaction). The standalone variant endpoints are for incremental management afterward (add a 4th size, fix a price, drop one).

### Create request — Type A (unit)
```json
{
  "name": "Lays",
  "pricing_type": "unit",
  "variants": [
    { "label": "small",  "price": 10.00, "is_default": true },
    { "label": "medium", "price": 20.00, "is_default": false },
    { "label": "large",  "price": 50.00, "is_default": false }
  ]
}
```

### Create request — Type B (loose)
```json
{
  "name": "Sugar",
  "pricing_type": "loose",
  "rate": 20.00,
  "unit": "kg"
}
```

### List response (mixed types, Type A nested)
```json
{
  "items": [
    {
      "id": "uuid",
      "name": "Lays",
      "pricing_type": "unit",
      "rate": null,
      "unit": null,
      "variants": [
        { "id": "uuid", "label": "small",  "price": 10.00, "is_default": true },
        { "id": "uuid", "label": "medium", "price": 20.00, "is_default": false },
        { "id": "uuid", "label": "large",  "price": 50.00, "is_default": false }
      ]
    },
    {
      "id": "uuid",
      "name": "Sugar",
      "pricing_type": "loose",
      "rate": 20.00,
      "unit": "kg",
      "variants": []
    }
  ]
}
```
Returned `ORDER BY name`.

### Error responses
```json
// 400/409 — duplicate item name (violates UNIQUE(user_id, name), SQLSTATE 23505)
{ "error": "an item with this name already exists" }

// 409 — variant insert on a Type B (loose) item
{ "error": "loose-priced items cannot have variants" }

// 400 — Type A create with no variants, or no default
{ "error": "a unit-priced item needs at least one variant with a default" }
```

### Backend logic notes
- All queries scoped by `user_id` from JWT claims.
- **`POST /v1/inventory` runs inside a DB transaction** — insert the item, then insert N variants; all succeed or all roll back. (First transaction in the project; gentle precursor to the billing settlement transaction.)
- The **list query is a JOIN** (`items LEFT JOIN item_variants`), returning N rows per Type A item — **grouped in Go** via `map[uuid.UUID]*ItemWithVariants` into one nested object each. `LEFT JOIN` so Type B items (zero variants) still appear.
- Validate type-shape rules in the service (Type A: variants + one default; Type B: rate+unit, no variants).
- Map unique-violation (23505) → duplicate-name error.

---

## BLoC

Single-state BLoC, `status` enum + `copyWith` — same shape as `AuthState` / `DashboardState` / `CustomersState`. Bigger event surface than customers because variants are independently mutable.

### Events
```dart
InventoryLoadRequested
ItemAdded(name, pricingType, {variants?, rate?, unit?})
ItemUpdated(id, name, {rate?, unit?})
ItemDeleted(id)
VariantAdded(itemId, label, price, isDefault)
VariantUpdated(itemId, variantId, label, price, isDefault)
VariantDeleted(itemId, variantId)
InventorySearchChanged(query)
```

### State
```dart
enum InventoryStatus { initial, loading, loaded, error }

class InventoryState extends Equatable {
  final InventoryStatus status;
  final List<Item> items;            // full list, alphabetical (source of truth)
  final ItemSearchIndex? searchIndex; // derived from `items`
  final String searchQuery;
  final List<Item> visibleItems;     // derived = search(index, query) or full list
  final String? errorMessage;
  // copyWith(...) — same pattern as the other features
}
```
- `visibleItems` is always derived = `f(items, searchIndex, query)`, recomputed on load/add/edit/delete/searchChanged. Page renders `visibleItems` only.
- `searchIndex` rebuilt on every mutation that changes a name.

### Scope
- `InventoryBloc` registered in GetIt, provided at the **Inventory branch** (branch 2), not hoisted to the shell — feature isolation, same lesson as customers.

---

## Data

### Entity (domain — pure Dart, no JSON) — **the polymorphic fork**

Two pricing types that **deliberately do not share a structure** (Type A has variants, Type B has rate+unit). Recommended Dart shape: a **sealed class** so the bill screen does an *exhaustive switch* on the type and the compiler forces both card renderers to exist.

```dart
sealed class Item {
  final String id;
  final String name;
  const Item({required this.id, required this.name});
}

class UnitItem extends Item {          // Type A — swipe card
  final List<ItemVariant> variants;    // one is the default
  const UnitItem({required super.id, required super.name, required this.variants});
}

class LooseItem extends Item {         // Type B — quantity card
  final double rate;
  final String unit;
  const LooseItem({required super.id, required super.name, required this.rate, required this.unit});
}

class ItemVariant {
  final String id;
  final String label;
  final double price;
  final bool isDefault;
  const ItemVariant({required this.id, required this.label, required this.price, required this.isDefault});
}
```

> **Fork to confirm at Flutter build time:** sealed class (above — exhaustive switch, no "this field is null for that type" footguns) **vs** one flat `Item` with a `pricingType` enum + nullable `rate`/`unit` + possibly-empty `variants`. Recommendation is sealed; the model layer reads `pricing_type` from JSON and constructs the right subclass.

### Search index (domain — pure Dart)
```dart
class ItemSearchIndex {
  factory ItemSearchIndex.build(List<Item> items);  // flat sorted (token, itemId)
  Set<String> query(String prefix);                 // pure, deduped
}
```
Same token-prefix binary-search structure as `CustomerSearchIndex`.

### Mock data
```dart
[
  UnitItem(id: 'i1', name: 'Lays', variants: [
    ItemVariant(id: 'v1', label: 'small',  price: 10, isDefault: true),
    ItemVariant(id: 'v2', label: 'medium', price: 20, isDefault: false),
    ItemVariant(id: 'v3', label: 'large',  price: 50, isDefault: false),
  ]),
  UnitItem(id: 'i2', name: 'Colgate', variants: [
    ItemVariant(id: 'v4', label: '100g', price: 55, isDefault: true),
    ItemVariant(id: 'v5', label: '200g', price: 95, isDefault: false),
  ]),
  LooseItem(id: 'i3', name: 'Sugar', rate: 20, unit: 'kg'),
  LooseItem(id: 'i4', name: 'Rice',  rate: 60, unit: 'kg'),
]
// Search "la" → {i1}; "co" → {i2}; "r" → {i4}.
```

---

## Screens

### InventoryPage (branch 2 — the tab)
- Search bar at top (filters the in-memory list via the inverted index)
- Alphabetical list; each row: name + a price hint (Type A: default variant price, e.g. "from ₹10"; Type B: "₹20/kg")
- "No items yet" placeholder when empty; "No matches" when search yields nothing
- FAB / AppBar action: "Add item"
- Tapping a row → ItemDetailPage
- Shared gear icon (`ShellActions`) in AppBar

### ItemDetailPage
- Type A: name + list of variants (label · price, default marked)
- Type B: name + rate + unit
- "Edit" → ItemFormPage (edit mode); "Delete" (hard delete)

> The **swipe** interaction itself is built on the bill screen (billing feature). Inventory detail just lists the variants — it CRUDs the data the swipe card later reads.

### ItemFormPage (shared add + edit) — the meaty UI
- First field: **pricing type toggle** (Unit / Loose) — drives which fields render below.
- Type A: name + a dynamic list of variant rows (label, price, "set default" radio — exactly one).
- Type B: name + rate + unit.
- Add mode: empty; Edit mode: pre-filled. Inline validation (same style as auth/customers forms).

---

## GoRouter

Inventory is **branch 2** of the shell. Add/detail/edit push **within** the branch so the bottom nav stays visible. Navigation goes through `NavigationCubit`, never `context.push` directly.

| Route | Page |
|-------|------|
| /home/inventory | InventoryPage (shell branch index 2) |
| /home/inventory/add | ItemFormPage (add mode) |
| /home/inventory/{id} | ItemDetailPage |
| /home/inventory/{id}/edit | ItemFormPage (edit mode) |

---

## Flutter file map

```
features/inventory/
├── domain/
│   ├── entities/
│   │   ├── item.dart                    ← 1. sealed Item + UnitItem/LooseItem + ItemVariant
│   │   └── item_search_index.dart       ← 2. inverted index + binary-search query (pure)
│   └── repositories/
│       └── inventory_repository.dart    ← 3. abstract contract
├── data/
│   ├── models/
│   │   └── item_model.dart              ← 4. JSON ↔ entity (branch on pricing_type)
│   ├── datasources/
│   │   ├── inventory_datasource.dart    ← 5. abstract interface
│   │   ├── inventory_mock_datasource.dart ← 6. hardcoded mock
│   │   └── inventory_remote_datasource.dart ← (later) real Dio
│   └── repositories/
│       └── inventory_repository_impl.dart ← 7. delegates to datasource
└── presentation/
    ├── bloc/
    │   ├── inventory_event.dart         ← 8.
    │   ├── inventory_state.dart         ← 9. status enum + copyWith
    │   └── inventory_bloc.dart          ← 10. builds index, runs pure search
    └── pages/
        ├── inventory_page.dart          ← 11. list + search bar
        ├── item_detail_page.dart        ← 12. variants / rate+unit
        ├── item_form_page.dart          ← 13. shared add/edit, type toggle
        └── widgets/
            ├── item_list_tile.dart
            ├── item_search_bar.dart
            └── variant_row.dart         ← dynamic variant input row (Type A form)
```

---

## Backend file map

```
internal/
├── handler/
│   └── inventory_handler.go    ← POST/GET/PUT/DELETE items + variant sub-routes
├── service/
│   └── inventory_service.go    ← type-shape validation, variant guard, sentinel errors
└── repository/
    └── inventory_repository.go ← SQL via sqlc, JOIN+group, transaction on create

db/
├── migrations/
│   └── 004_create_inventory.sql  ← items + item_variants + indexes (Up + Down)
└── queries/
    └── inventory.sql             ← create item, create variant, list (JOIN, ORDER BY name),
                                     update item/variant, delete item/variant, get-by-id
```

---

## Build order

1. Flutter — domain (`Item` sealed hierarchy, `ItemVariant`, `ItemSearchIndex` pure query, repo contract)
2. Flutter — **unit-test the search index** (prefix, dedup, empty, normalization) — reuse customers' test cases
3. Flutter — mock datasource + repo impl
4. Flutter — BLoC (events incl. variant events, state, bloc): load → build index, searchChanged → recompute visible
5. Flutter — InventoryPage UI (list + search + tile)
6. Flutter — ItemFormPage (type toggle drives the form; dynamic variant rows for Type A)
7. Flutter — ItemDetailPage (variants list / rate+unit; delete)
8. Flutter — GetIt registration + NavigationCubit methods + wire into shell branch 2 + emulator test with mock
9. Go — migration 004 (items + item_variants, FKs, partial unique index)
10. Go — sqlc queries (inventory.sql)
11. Go — repository (JOIN + group-in-Go, transaction on create) → service (type-shape rules, variant guard) → handler (item + variant routes); unique-violation → dup-name error
12. Flutter — swap mock → real Dio remote datasource
13. End-to-end: add Type A with 3 variants → appears alphabetically → search → edit a variant price → add a variant → add a Type B → delete. Verify the transaction (kill it mid-create, confirm no orphan item).

---

## Reference

Use `features/customers/` as the closest pattern template (search index, single-state BLoC, branch wiring, mock-first), and `backend_conventions.md §7` (dashboard vertical) for the Go layering. New ground this feature breaks (no prior template — design carefully):
- Parent/child one-to-many (items → variants)
- Polymorphic domain model (sealed Type A/B)
- DB transaction on create (item + N variants atomic)
- JOIN + group-in-Go (N rows → 1 nested object)
- Service-layer cross-field validation + the variant guard

---

## Key learnings / LLD notes (interview-facing)

- **Parent/child over polymorphic FK:** a FK referencing "one of two tables" is unenforceable; push the variation into a child table, let the empty-for-Type-B case fall out naturally.
- **Discriminator column (`pricing_type`):** one column drives card rendering, column validity, and child existence. The whole feature branches on it.
- **Nullable-by-design:** `rate`/`unit` NULL on Type A is a modeling statement ("N/A for this row"), not missing data.
- **Defense in depth, twice:** partial unique index (`WHERE is_default`) caps defaults at the DB; service guarantees the floor; service guards variant-insert against Type B. Same client-hides / server-enforces shape as the customers delete guard.
- **JOIN returns N rows per parent → group in Go** with a map keyed by parent id. One round-trip beats N+1 fetches.
- **Atomic multi-row write = transaction:** create item + variants all-or-nothing. First use of `BEGIN/COMMIT` in the project; the billing settlement transaction is the same move at larger scale.
- **Sealed class for two card types:** exhaustive switch on the bill screen → compiler forces both renderers, no nullable-field footguns.
- **Inventory is a price book, not stock:** the deliberate scope cut. AI + inventory are accelerators that pre-fill; nothing locks, every cell is editable on the bill.

---

## What is deferred (not in this feature)

- The **swipe card** interaction + manual bill-builder → Billing feature (inventory only CRUDs the data behind it)
- **Scan → inventory matching** (Gemini label → item card, keyword/fuzzy on name) → Billing/Scan feature; the single-item match query lives there, not here
- `bills` + `bill_items` schema expansion, settlement transaction → Billing feature
- Server-side search + pagination → when the list outgrows client memory
- `item_description` surfacing in UI → optional, deferred
- UI design / Figma polish; swipe-card animation → after all features are functionally complete