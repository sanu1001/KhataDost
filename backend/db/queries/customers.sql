-- name: CreateCustomer :one
-- Insert a new customer scoped to the owning shop (user_id).
-- RETURNING hands back the full row (server-generated id, has_dues default,
-- timestamps) so the handler can echo it to the client with no second query.
INSERT INTO customers (user_id, name, phone, email, notes)
VALUES ($1, $2, $3, $4, $5)
RETURNING id, user_id, name, phone, email, notes, has_dues, created_at, updated_at;

-- name: ListCustomers :many
-- Full list for one shop, alphabetical. Backed by idx_customers_user_name.
SELECT id, user_id, name, phone, email, notes, has_dues, created_at, updated_at
FROM customers
WHERE user_id = $1
ORDER BY name;

-- name: GetCustomerByID :one
-- Single customer, scoped by BOTH id AND user_id — a shop can never read
-- another shop's customer even with a guessed id.
SELECT id, user_id, name, phone, email, notes, has_dues, created_at, updated_at
FROM customers
WHERE id = $1 AND user_id = $2;

-- name: UpdateCustomer :one
-- Update identity fields, bump updated_at. Scoped by id AND user_id.
-- has_dues is NOT updatable here — it's khata-owned (temporary manual flip for now).
UPDATE customers
SET name = $3, phone = $4, email = $5, notes = $6, updated_at = NOW()
WHERE id = $1 AND user_id = $2
RETURNING id, user_id, name, phone, email, notes, has_dues, created_at, updated_at;

-- name: DeleteCustomer :exec
-- Hard delete, scoped by id AND user_id. The dues-check happens in the
-- SERVICE layer before this runs (defense layer 2 returns 409). This query
-- just deletes — it trusts the service already gated it.
DELETE FROM customers
WHERE id = $1 AND user_id = $2;