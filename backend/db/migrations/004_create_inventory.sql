-- +goose Up
CREATE TABLE items (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name         TEXT NOT NULL,
    pricing_type TEXT NOT NULL,
    rate         NUMERIC(12,2),
    unit         TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, name)
);

CREATE TABLE item_variants (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id     UUID NOT NULL REFERENCES items(id) ON DELETE CASCADE,
    label       TEXT NOT NULL,
    price       NUMERIC(12,2) NOT NULL,
    is_default  BOOLEAN NOT NULL DEFAULT false,
    description TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_item_variants_item_id ON item_variants (item_id);

CREATE UNIQUE INDEX idx_one_default_per_item
    ON item_variants (item_id) WHERE is_default;

-- +goose Down
DROP TABLE item_variants;
DROP TABLE items;