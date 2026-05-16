-- name: GetTodaySales :one
SELECT COALESCE(SUM(amount), 0)::numeric AS total_sales FROM bills
WHERE user_id = $1
AND DATE(created_at AT TIME ZONE 'Asia/Kolkata') = CURRENT_DATE AT TIME ZONE 'Asia/Kolkata';

-- name: GetRecentBills :many
SELECT id, customer_name, amount, created_at FROM bills
WHERE user_id = $1
ORDER BY created_at DESC
LIMIT 3;