-- name: GetTodaySales :one
-- "Today" is the shop's day in India (IST), whatever time zone the database
-- session runs in (Neon and the Postgres Docker image default to UTC).
-- date_trunc finds midnight IST as a wall-clock time, AT TIME ZONE turns it
-- back into a real instant, and the half-open range [midnight, midnight + 1 day)
-- keeps the (user_id, created_at) index usable. India has no daylight saving,
-- so a day is always 24 hours.
SELECT COALESCE(SUM(amount), 0)::numeric AS total_sales FROM bills
WHERE user_id = $1
AND created_at >= (date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata')
AND created_at <  (date_trunc('day', now() AT TIME ZONE 'Asia/Kolkata') AT TIME ZONE 'Asia/Kolkata') + INTERVAL '1 day';

-- name: GetRecentBills :many
SELECT id, customer_name, amount, created_at FROM bills
WHERE user_id = $1
ORDER BY created_at DESC
LIMIT 3;