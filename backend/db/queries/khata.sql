-- name: InsertKhataEntry :one
-- Insert one khata entry ('credit' or 'payment') for a customer.
-- Called in two places:
--   1. Inside the billing settlement transaction (credit + optional payment
--      written by billing_repository.CreateBillWithItems via the shared tx).
--   2. Directly by the "Record Payment" endpoint (payment only).
-- bill_id is set only for 'credit' entries; NULL for standalone 'payment'.
INSERT INTO khata_entries (user_id, customer_id, type, amount, bill_id, note)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING id, user_id, customer_id, type, amount, bill_id, note, created_at;

-- name: ListKhataEntries :many
-- Chronological ledger for one customer of one shop (timeline view).
-- Oldest first — credits and payments within the same settlement transaction
-- share the tx timestamp; id breaks ties deterministically.
SELECT id, user_id, customer_id, type, amount, bill_id, note, created_at
FROM khata_entries
WHERE user_id = $1 AND customer_id = $2
ORDER BY created_at, id;

-- name: GetCustomerBalance :one
-- Derived balance: SUM(credits) − SUM(payments).
-- Returns 0 when the customer has no entries (COALESCE).
-- ::numeric cast ensures sqlc emits string (same convention as money columns
-- throughout the codebase), not interface{}.
SELECT COALESCE(
    SUM(CASE WHEN type = 'credit' THEN amount ELSE -amount END),
    0
)::numeric AS balance
FROM khata_entries
WHERE user_id = $1 AND customer_id = $2;
