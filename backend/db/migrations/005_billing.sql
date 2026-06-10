-- +goose Up
-- Billing grows the bills stub (sanctioned exception #2: ALTER only, never edit 002).
-- bills.amount stays = bill TOTAL — dashboard sums it. customer_name stays as the
-- denormalized snapshot shown on lists even if the customer row is later deleted.
ALTER TABLE bills
    ADD COLUMN customer_id UUID REFERENCES customers(id) ON DELETE SET NULL,
    ADD COLUMN amount_paid NUMERIC(12,2) NOT NULL DEFAULT 0;
-- customer_id NULL = walk-in. ON DELETE SET NULL: deleting a customer keeps the
-- bill (sales history is immutable); the snapshot name still renders.

-- A bill line stores the RESOLVED result (name + price + qty + total), never a
-- live pointer dependency — deleting inventory can never orphan or change a bill.
CREATE TABLE bill_items (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bill_id     UUID NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
    item_id     UUID REFERENCES items(id) ON DELETE SET NULL,         -- NULL for miscellaneous
    variant_id  UUID REFERENCES item_variants(id) ON DELETE SET NULL, -- NULL for Type B / misc
    name        TEXT NOT NULL,                 -- denormalized snapshot (delete-safe)
    quantity    NUMERIC(12,3) NOT NULL,        -- count (Type A) or measure e.g. 0.750 (Type B)
    unit_price  NUMERIC(12,2) NOT NULL,        -- resolved variant price or rate
    line_total  NUMERIC(12,2) NOT NULL,        -- quantity * unit_price (denormalized)
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_bill_items_bill_id ON bill_items (bill_id);

-- +goose Down
DROP TABLE bill_items;
ALTER TABLE bills DROP COLUMN amount_paid, DROP COLUMN customer_id;
