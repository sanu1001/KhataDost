package repository

import (
	"context"
	"fmt"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"

	"github.com/sanu1001/KhataDost/backend/internal/sqlcgen"
)

// ── Domain struct ────────────────────────────────────────────────────────────
// No sqlcgen or database/sql types leak out. BillID is *string (nil for
// 'payment' entries); Note is *string (nil when absent).
type KhataEntry struct {
	ID         string
	CustomerID string
	Type       string  // 'credit' | 'payment'
	Amount     float64
	BillID     *string // nil for standalone payment entries
	Note       *string
	CreatedAt  time.Time
}

// ── Interface + impl + constructor ──────────────────────────────────────────
type KhataRepository interface {
	// InsertEntry writes one 'credit' or 'payment' entry.
	// Called both from inside the billing settlement transaction (via the
	// billingRepository's shared tx) and directly by RecordPayment.
	// billID is nil for payment entries; note is nil when absent.
	InsertEntry(ctx context.Context, userID, customerID uuid.UUID, entryType string, amount float64, billID *uuid.UUID, note *string) (*KhataEntry, error)

	// ListByCustomer returns all entries for one customer, oldest first.
	ListByCustomer(ctx context.Context, userID, customerID uuid.UUID) ([]KhataEntry, error)

	// GetBalance returns the derived balance (Σcredit − Σpayment).
	// Returns 0 when the customer has no entries.
	GetBalance(ctx context.Context, userID, customerID uuid.UUID) (float64, error)
}

type khataRepository struct {
	queries *sqlcgen.Queries
}

func NewKhataRepository(db *sqlx.DB) KhataRepository {
	return &khataRepository{queries: sqlcgen.New(db)}
}

// ── InsertEntry ──────────────────────────────────────────────────────────────
func (r *khataRepository) InsertEntry(
	ctx context.Context,
	userID, customerID uuid.UUID,
	entryType string,
	amount float64,
	billID *uuid.UUID,
	note *string,
) (*KhataEntry, error) {
	row, err := r.queries.InsertKhataEntry(ctx, sqlcgen.InsertKhataEntryParams{
		UserID:     userID,
		CustomerID: customerID,
		Type:       entryType,
		Amount:     floatToString(amount), // NUMERIC(12,2) → "NNN.NN"
		BillID:     uuidPtrToNullUUID(billID),
		Note:       toNullString(note),
	})
	if err != nil {
		return nil, fmt.Errorf("InsertKhataEntry: %w", err)
	}
	e := khataEntryToDomain(row)
	return &e, nil
}

// ── ListByCustomer ───────────────────────────────────────────────────────────
func (r *khataRepository) ListByCustomer(ctx context.Context, userID, customerID uuid.UUID) ([]KhataEntry, error) {
	rows, err := r.queries.ListKhataEntries(ctx, sqlcgen.ListKhataEntriesParams{
		UserID:     userID,
		CustomerID: customerID,
	})
	if err != nil {
		return nil, fmt.Errorf("ListKhataEntries: %w", err)
	}
	entries := make([]KhataEntry, 0, len(rows))
	for _, row := range rows {
		entries = append(entries, khataEntryToDomain(row))
	}
	return entries, nil
}

// ── GetBalance ───────────────────────────────────────────────────────────────
// sqlc v1.29.0 returns a single-column :one result as a scalar directly —
// GetCustomerBalance returns (string, error), not a Row struct.
func (r *khataRepository) GetBalance(ctx context.Context, userID, customerID uuid.UUID) (float64, error) {
	balanceStr, err := r.queries.GetCustomerBalance(ctx, sqlcgen.GetCustomerBalanceParams{
		UserID:     userID,
		CustomerID: customerID,
	})
	if err != nil {
		return 0, fmt.Errorf("GetCustomerBalance: %w", err)
	}
	balance, err := strconv.ParseFloat(balanceStr, 64)
	if err != nil {
		return 0, fmt.Errorf("GetCustomerBalance parse: %w", err)
	}
	return balance, nil
}

// ── Mapping helper ───────────────────────────────────────────────────────────
// khataEntryToDomain maps a sqlcgen.KhataEntry → repository KhataEntry.
// floatToString / uuidPtrToNullUUID / nullUUIDToStringPtr / toNullString /
// fromNullString are defined in other files in this package (inventory_repository.go
// and customer_repository.go respectively) — no redefinition needed.
func khataEntryToDomain(row sqlcgen.KhataEntry) KhataEntry {
	amount, _ := strconv.ParseFloat(row.Amount, 64)
	return KhataEntry{
		ID:         row.ID.String(),
		CustomerID: row.CustomerID.String(),
		Type:       row.Type,
		Amount:     amount,
		BillID:     nullUUIDToStringPtr(row.BillID),
		Note:       fromNullString(row.Note),
		CreatedAt:  row.CreatedAt,
	}
}
