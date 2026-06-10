-- name: CreateBill :one
-- Insert the bill header, scoped to the shop. RETURNING hands back the
-- server-generated id — the repository NEEDS it to insert the bill_items
-- against it, all inside ONE transaction (same pattern as CreateItem).
-- customer_id is NULL for walk-in; customer_name is the denormalized snapshot.
-- amount = bill TOTAL (dashboard sums this column — name is load-bearing).
-- NOTE: customer_id/amount_paid trail created_at in the column list because
-- migration 005 ALTER-appended them — keeping DDL order lets sqlc reuse the
-- Bill model instead of emitting per-query Row structs.
INSERT INTO bills (user_id, customer_id, customer_name, amount, amount_paid)
VALUES ($1, $2, $3, $4, $5)
RETURNING id, user_id, customer_name, amount, created_at, customer_id, amount_paid;

-- name: CreateBillItem :one
-- Insert one line against an existing bill. Called N times by the repo inside
-- the settlement transaction. Stores the RESOLVED result (name + price + qty +
-- total) — item_id/variant_id are provenance pointers only, nullable by design
-- (NULL item_id = miscellaneous; NULL variant_id = Type B or miscellaneous).
INSERT INTO bill_items (bill_id, item_id, variant_id, name, quantity, unit_price, line_total)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING id, bill_id, item_id, variant_id, name, quantity, unit_price, line_total, created_at;

-- name: ListBills :many
-- Full bill list for one shop, newest first. Backed by idx_bills_user_created_at
-- (same index the dashboard's recent-bills query uses). Headers only — line
-- items are fetched per-bill via GetBillItems on the detail view.
SELECT id, user_id, customer_name, amount, created_at, customer_id, amount_paid
FROM bills
WHERE user_id = $1
ORDER BY created_at DESC;

-- name: GetBillByID :one
-- Single bill, scoped by BOTH id AND user_id — a shop can never read another
-- shop's bill even with a guessed id (same cross-shop guard as customers).
SELECT id, user_id, customer_name, amount, created_at, customer_id, amount_paid
FROM bills
WHERE id = $1 AND user_id = $2;

-- name: GetBillItems :many
-- Lines for one bill. NOTE: bill_items carry no user_id — tenancy is enforced
-- one level up by GetBillByID (transitive tenancy, same as item_variants).
-- created_at is NOW() = transaction start, so every line in a bill shares one
-- timestamp; the id tiebreak just makes the order deterministic.
SELECT id, bill_id, item_id, variant_id, name, quantity, unit_price, line_total, created_at
FROM bill_items
WHERE bill_id = $1
ORDER BY created_at, id;
