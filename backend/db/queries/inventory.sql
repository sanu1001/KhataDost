-- name: CreateItem :one
-- Insert the parent item row, scoped to the shop. RETURNING hands back the
-- server-generated id — the repository NEEDS this id to then insert the
-- variant rows against it, all inside ONE transaction.
INSERT INTO items (user_id, name, pricing_type, rate, unit)
VALUES ($1, $2, $3, $4, $5)
RETURNING id, user_id, name, pricing_type, rate, unit, created_at, updated_at;

-- name: CreateVariant :one
-- Insert one variant against an existing item. Called N times by the repo
-- (once per variant) inside the create transaction, and standalone by the
-- add-variant endpoint. The repo passes item_id from the just-created item.
INSERT INTO item_variants (item_id, label, price, is_default, description)
VALUES ($1, $2, $3, $4, $5)
RETURNING id, item_id, label, price, is_default, description, created_at, updated_at;

-- name: GetItemByID :one
-- Single item, scoped by id AND user_id (same cross-shop guard as customers).
-- Used by the variant guard: service reads pricing_type before allowing a
-- variant insert — a 'loose' item must reject variants.
SELECT id, user_id, name, pricing_type, rate, unit, created_at, updated_at
FROM items
WHERE id = $1 AND user_id = $2;

-- name: UpdateItem :one
-- Update item fields, bump updated_at. Scoped by id AND user_id.
UPDATE items
SET name = $3, rate = $4, unit = $5, updated_at = NOW()
WHERE id = $1 AND user_id = $2
RETURNING id, user_id, name, pricing_type, rate, unit, created_at, updated_at;

-- name: DeleteItem :exec
-- Hard delete, scoped by id AND user_id. ON DELETE CASCADE drops the item's
-- variants automatically — no separate variant delete needed here.
DELETE FROM items
WHERE id = $1 AND user_id = $2;



-- name: GetVariantByID :one
-- Single variant by its own id. Used for the 404 check before update/delete.
-- NOTE: variants have no user_id column — tenancy is enforced one level up,
-- by first confirming the parent item belongs to this user (GetItemByID).
SELECT id, item_id, label, price, is_default, description, created_at, updated_at
FROM item_variants
WHERE id = $1;

-- name: UpdateVariant :one
UPDATE item_variants
SET label = $2, price = $3, is_default = $4, description = $5, updated_at = NOW()
WHERE id = $1
RETURNING id, item_id, label, price, is_default, description, created_at, updated_at;

-- name: DeleteVariant :exec
DELETE FROM item_variants
WHERE id = $1;

-- name: ListItemsWithVariants :many
-- LEFT JOIN so Type B (loose) items with zero variants still appear.
-- Returns FLAT rows: a unit item with 3 variants = 3 rows (item cols repeated,
-- one variant per row); a loose item = 1 row with all variant cols NULL.
-- The repository groups these flat rows into nested objects in Go, keyed by
-- item_id, preserving this ORDER BY name via a parallel ordered slice.
SELECT
    i.id           AS item_id,
    i.name         AS item_name,
    i.pricing_type,
    i.rate,
    i.unit,
    i.created_at   AS item_created_at,
    i.updated_at   AS item_updated_at,
    v.id           AS variant_id,
    v.label,
    v.price,
    v.is_default,
    v.description,
    v.created_at   AS variant_created_at,
    v.updated_at   AS variant_updated_at
FROM items i
LEFT JOIN item_variants v ON i.id = v.item_id
WHERE i.user_id = $1
ORDER BY i.name;