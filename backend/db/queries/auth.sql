-- name: CreateUser :one
INSERT INTO users (name, shop_name, phone, email, password)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: GetUserByEmail :one
SELECT * FROM users WHERE email = $1;