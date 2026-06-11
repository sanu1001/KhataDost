-- +goose Up
-- Phase 2: khata (credit ledger) + computed has_dues.
--
-- khata_entries records ONLY balance-moving transactions:
--   'credit'  — a bill placed on tab (links to the bill; amount = bill total)
--   'payment' — money received later (no bill link)
-- Balance is always DERIVED (Σcredit − Σpayment), never stored.
-- A fully-paid cash bill writes NOTHING here.

CREATE TABLE khata_entries (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
    type        TEXT NOT NULL,                                          -- 'credit' | 'payment'
    amount      NUMERIC(12,2) NOT NULL,
    bill_id     UUID REFERENCES bills(id) ON DELETE SET NULL,           -- set on 'credit', NULL on 'payment'
    note        TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Primary access pattern: all entries for one customer of one shop, in order.
CREATE INDEX idx_khata_customer ON khata_entries (user_id, customer_id, created_at);

-- has_dues is now computed from khata_entries (balance != 0).
-- The column is dropped here; customers.sql ListCustomers / GetCustomerByID
-- re-emit it as a LEFT-JOIN aggregate so the Go contract (HasDues bool) is
-- preserved and Flutter customers feature is untouched.
ALTER TABLE customers DROP COLUMN has_dues;

-- +goose Down
ALTER TABLE customers ADD COLUMN has_dues BOOLEAN NOT NULL DEFAULT false;
DROP TABLE khata_entries;
