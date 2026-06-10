package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"

	"github.com/sanu1001/KhataDost/backend/internal/sqlcgen"
)

// ── Sentinel errors that ORIGINATE in the repository (DB-derived) ───────────
// Business-rule errors (walk-in must pay full, empty bill, etc.) live in the
// SERVICE layer — same split as inventory.
var (
	ErrBillNotFound = errors.New("bill not found")
)

// ── Domain structs (clean Go types — no database/sql or sqlc leaking out) ───

// BillLineInput is one line as it arrives on a create call, already validated
// and RESOLVED by the service (totals computed server-side). ItemID/VariantID
// are provenance pointers only — nil ItemID = miscellaneous, nil VariantID =
// Type B (loose) or miscellaneous.
type BillLineInput struct {
	ItemID    *uuid.UUID
	VariantID *uuid.UUID
	Name      string
	Quantity  float64
	UnitPrice float64
	LineTotal float64
}

type BillItem struct {
	ID        string
	ItemID    *string // nil = miscellaneous
	VariantID *string // nil = Type B / miscellaneous
	Name      string
	Quantity  float64
	UnitPrice float64
	LineTotal float64
	CreatedAt time.Time
}

type Bill struct {
	ID           string
	CustomerID   *string // nil = walk-in
	CustomerName string
	Amount       float64 // bill TOTAL (the column the dashboard sums)
	AmountPaid   float64
	CreatedAt    time.Time
}

// BillWithItems = a Bill PLUS its lines nested (same embedding pattern as
// ItemWithVariants — Bill's fields are promoted, write bwi.Amount directly).
type BillWithItems struct {
	Bill
	Items []BillItem // never nil in output — JSON emits [] not null
}

// ── Interface + unexported impl + constructor ───────────────────────────────
type BillingRepository interface {
	CreateBillWithItems(ctx context.Context, userID uuid.UUID, customerID *uuid.UUID, customerName string, total, amountPaid float64, lines []BillLineInput) (*BillWithItems, error)
	ListBills(ctx context.Context, userID uuid.UUID) ([]*Bill, error)
	GetBillByID(ctx context.Context, id, userID uuid.UUID) (*BillWithItems, error)
}

type billingRepository struct {
	db      *sqlx.DB // needed for BeginTxx (settlement transaction)
	queries *sqlcgen.Queries
}

func NewBillingRepository(db *sqlx.DB) BillingRepository {
	return &billingRepository{
		db:      db,
		queries: sqlcgen.New(db),
	}
}

// ── CreateBillWithItems — THE settlement transaction ────────────────────────
// Inserts the bill header, then N lines, ALL-OR-NOTHING. The service has
// already validated the business rules (non-empty bill, walk-in pays full,
// totals recomputed server-side) before we get here — this method's only job
// is atomicity. Same BeginTxx + defer Rollback + New(tx) shape as inventory's
// CreateItemWithVariants.
//
// PHASE 2 (khata) extends THIS transaction: when the customer is on tab
// (customerID set AND amountPaid != total), a khata 'credit' entry (= total,
// linked to the bill) and — if amountPaid > 0 — a 'payment' entry
// (= amountPaid) are inserted here, inside the same tx, after the lines.
// The khata_entries table arrives with migration 006.
func (r *billingRepository) CreateBillWithItems(
	ctx context.Context,
	userID uuid.UUID,
	customerID *uuid.UUID,
	customerName string,
	total, amountPaid float64,
	lines []BillLineInput,
) (*BillWithItems, error) {
	tx, err := r.db.BeginTxx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("CreateBillWithItems begin: %w", err)
	}
	defer tx.Rollback() // RAII: undo on any early return; no-op after commit

	qtx := sqlcgen.New(tx)

	// 1. Insert the bill header, get its generated id back.
	billRow, err := qtx.CreateBill(ctx, sqlcgen.CreateBillParams{
		UserID:       userID,
		CustomerID:   uuidPtrToNullUUID(customerID), // nil → NULL (walk-in)
		CustomerName: customerName,
		Amount:       floatToString(total),
		AmountPaid:   floatToString(amountPaid),
	})
	if err != nil {
		return nil, fmt.Errorf("CreateBillWithItems bill: %w", err)
	}

	// 2. Insert each line against the just-created bill id.
	created := make([]BillItem, 0, len(lines))
	for _, l := range lines {
		itemRow, err := qtx.CreateBillItem(ctx, sqlcgen.CreateBillItemParams{
			BillID:    billRow.ID,
			ItemID:    uuidPtrToNullUUID(l.ItemID),
			VariantID: uuidPtrToNullUUID(l.VariantID),
			Name:      l.Name,
			Quantity:  quantityToString(l.Quantity), // NUMERIC(12,3) → 3 decimals
			UnitPrice: floatToString(l.UnitPrice),
			LineTotal: floatToString(l.LineTotal),
		})
		if err != nil {
			// deferred Rollback undoes the bill + any earlier lines
			return nil, fmt.Errorf("CreateBillWithItems line %q: %w", l.Name, err)
		}
		created = append(created, billItemToDomain(itemRow))
	}

	// PHASE 2 INSERTION POINT: khata 'credit' (+ optional 'payment') entries
	// go here, inside this same transaction, once migration 006 exists.

	// 3. Commit. After this, the deferred Rollback becomes a no-op.
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("CreateBillWithItems commit: %w", err)
	}

	// 4. Assemble the domain object to return (no extra query — we have it all).
	return &BillWithItems{
		Bill:  billToDomain(billRow),
		Items: created,
	}, nil
}

// ── ListBills — headers only, newest first ──────────────────────────────────
// Line items are NOT fetched here — the list view needs name/total/date only;
// the detail view fetches lines via GetBillByID.
func (r *billingRepository) ListBills(ctx context.Context, userID uuid.UUID) ([]*Bill, error) {
	rows, err := r.queries.ListBills(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("ListBills: %w", err)
	}

	bills := make([]*Bill, 0, len(rows))
	for _, row := range rows {
		b := billToDomain(row)
		bills = append(bills, &b)
	}
	return bills, nil
}

// ── GetBillByID — header + lines, scoped by id AND user_id ──────────────────
// Two reads, no transaction needed: bill_items are immutable after creation,
// so there's nothing to race. Tenancy for the lines is transitive — the
// header lookup is user-scoped, and lines are only fetched via its bill id
// (same pattern as item_variants).
func (r *billingRepository) GetBillByID(ctx context.Context, id, userID uuid.UUID) (*BillWithItems, error) {
	billRow, err := r.queries.GetBillByID(ctx, sqlcgen.GetBillByIDParams{
		ID:     id,
		UserID: userID,
	})
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrBillNotFound
		}
		return nil, fmt.Errorf("GetBillByID: %w", err)
	}

	itemRows, err := r.queries.GetBillItems(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("GetBillByID items: %w", err)
	}

	items := make([]BillItem, 0, len(itemRows))
	for _, row := range itemRows {
		items = append(items, billItemToDomain(row))
	}

	return &BillWithItems{
		Bill:  billToDomain(billRow),
		Items: items,
	}, nil
}

// ── Mapping helpers (sqlc ↔ domain) ─────────────────────────────────────────
// floatToString / toNullString / fromNullString / nullStringToFloatPtr are NOT
// redefined here — they live in customer_repository.go / inventory_repository.go
// in this same `repository` package.

// quantityToString: float64 → string for the NUMERIC(12,3) quantity column.
// Three decimals (not two): quantity is a count for Type A (2.000) or a
// measure for Type B (0.750 kg).
func quantityToString(q float64) string {
	return strconv.FormatFloat(q, 'f', 3, 64)
}

// uuidPtrToNullUUID: *uuid.UUID → uuid.NullUUID. nil → NULL.
func uuidPtrToNullUUID(u *uuid.UUID) uuid.NullUUID {
	if u == nil {
		return uuid.NullUUID{Valid: false}
	}
	return uuid.NullUUID{UUID: *u, Valid: true}
}

// nullUUIDToStringPtr: uuid.NullUUID → *string. NULL → nil.
func nullUUIDToStringPtr(nu uuid.NullUUID) *string {
	if !nu.Valid {
		return nil
	}
	s := nu.UUID.String()
	return &s
}

// billToDomain: sqlcgen.Bill → repository Bill (parse NUMERIC, uuid→string).
func billToDomain(row sqlcgen.Bill) Bill {
	amount, _ := strconv.ParseFloat(row.Amount, 64)         // NOT NULL → always parseable
	amountPaid, _ := strconv.ParseFloat(row.AmountPaid, 64) // NOT NULL DEFAULT 0
	return Bill{
		ID:           row.ID.String(),
		CustomerID:   nullUUIDToStringPtr(row.CustomerID), // NULL → nil (walk-in)
		CustomerName: row.CustomerName,
		Amount:       amount,
		AmountPaid:   amountPaid,
		CreatedAt:    row.CreatedAt,
	}
}

// billItemToDomain: sqlcgen.BillItem → repository BillItem.
func billItemToDomain(row sqlcgen.BillItem) BillItem {
	quantity, _ := strconv.ParseFloat(row.Quantity, 64)
	unitPrice, _ := strconv.ParseFloat(row.UnitPrice, 64)
	lineTotal, _ := strconv.ParseFloat(row.LineTotal, 64)
	return BillItem{
		ID:        row.ID.String(),
		ItemID:    nullUUIDToStringPtr(row.ItemID),
		VariantID: nullUUIDToStringPtr(row.VariantID),
		Name:      row.Name,
		Quantity:  quantity,
		UnitPrice: unitPrice,
		LineTotal: lineTotal,
		CreatedAt: row.CreatedAt,
	}
}
