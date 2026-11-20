-- +goose Up
-- All lines of a bill are written in one transaction, so they share the same
-- created_at, and their ids are random UUIDv4. Nothing recorded the order the
-- lines were added in, so GetBillItems could return them shuffled.
-- line_no is the line's index on the bill (0, 1, 2, ...). Rows written before
-- this migration get 0 and keep the old (created_at, id) order among themselves.
ALTER TABLE bill_items ADD COLUMN line_no INT NOT NULL DEFAULT 0;

-- +goose Down
ALTER TABLE bill_items DROP COLUMN line_no;
