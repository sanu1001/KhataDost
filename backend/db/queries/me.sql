-- name: GetUserByID :one
SELECT id, name, shop_name, phone, email FROM users WHERE id = $1;
