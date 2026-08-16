-- name: CreateCustomer :one
-- Insert a new customer scoped to the owning shop (user_id).
-- RETURNING hands back the full row so the handler can echo it to the client
-- with no second query. has_dues is always false for a brand-new customer
-- (no khata_entries exist yet) — emitted as a literal so the Go contract
-- (HasDues bool) is preserved after migration 006 dropped the column.
INSERT INTO customers (user_id, name, phone, email, notes)
VALUES ($1, $2, $3, $4, $5)
RETURNING id, user_id, name, phone, email, notes, false AS has_dues, created_at, updated_at;

-- name: ListCustomers :many
-- Full list for one shop, alphabetical. Backed by idx_customers_user_name.
-- has_dues is computed: balance (SUM credits − SUM payments) != 0.
-- LEFT JOIN so customers with no entries are included (has_dues = false).
SELECT
    c.id,
    c.user_id,
    c.name,
    c.phone,
    c.email,
    c.notes,
    COALESCE(
        SUM(CASE WHEN k.type = 'credit' THEN k.amount ELSE -k.amount END),
        0
    )::numeric <> 0 AS has_dues,
    c.created_at,
    c.updated_at
FROM customers c
LEFT JOIN khata_entries k ON k.customer_id = c.id AND k.user_id = c.user_id
WHERE c.user_id = $1
GROUP BY c.id, c.user_id, c.name, c.phone, c.email, c.notes, c.created_at, c.updated_at
ORDER BY c.name;

-- name: GetCustomerByID :one
-- Single customer, scoped by BOTH id AND user_id — a shop can never read
-- another shop's customer even with a guessed id.
-- has_dues computed the same way as ListCustomers.
SELECT
    c.id,
    c.user_id,
    c.name,
    c.phone,
    c.email,
    c.notes,
    COALESCE(
        SUM(CASE WHEN k.type = 'credit' THEN k.amount ELSE -k.amount END),
        0
    )::numeric <> 0 AS has_dues,
    c.created_at,
    c.updated_at
FROM customers c
LEFT JOIN khata_entries k ON k.customer_id = c.id AND k.user_id = c.user_id
WHERE c.id = $1 AND c.user_id = $2
GROUP BY c.id, c.user_id, c.name, c.phone, c.email, c.notes, c.created_at, c.updated_at;

-- name: UpdateCustomer :one
-- Update identity fields, bump updated_at. Scoped by id AND user_id.
-- has_dues emitted as false (identity updates never change balances; the UI
-- refreshes the list after update, which calls ListCustomers with the real value).
UPDATE customers
SET name = $3, phone = $4, email = $5, notes = $6, updated_at = NOW()
WHERE id = $1 AND user_id = $2
RETURNING id, user_id, name, phone, email, notes, false AS has_dues, created_at, updated_at;

-- name: DeleteCustomer :exec
-- Hard delete, scoped by id AND user_id. The dues-check happens in the
-- SERVICE layer before this runs (defense layer 2 returns 409). This query
-- just deletes — it trusts the service already gated it.
DELETE FROM customers
WHERE id = $1 AND user_id = $2;
