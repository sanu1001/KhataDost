package service

import (
	"context"
	"errors"
	"math"

	"github.com/google/uuid"

	"github.com/sanu1001/KhataDost/backend/internal/repository"
)

// ── Sentinel errors owned by THIS layer (business rules) ────────────────────
// Repository-level errors (ErrBillNotFound, ErrCustomerNotFound) pass THROUGH
// this layer unwrapped — the handler matches them with errors.Is either way.
var (
	// ErrEmptyBill — a bill needs at least one line item.
	ErrEmptyBill = errors.New("a bill needs at least one item")

	// ErrInvalidLine — a line is missing a name, or has a non-positive
	// quantity, or a negative price.
	ErrInvalidLine = errors.New("each item needs a name, a positive quantity, and a non-negative price")

	// ErrNegativeAmountPaid — "paying now" cannot be negative.
	ErrNegativeAmountPaid = errors.New("amount_paid cannot be negative")

	// ErrWalkInMustPayFull — a walk-in has no khata to owe against, so the
	// bill must be settled exactly in full (LOCKED in the decision log).
	ErrWalkInMustPayFull = errors.New("a walk-in bill must be paid in full")
)

// walkInName is the denormalized customer_name snapshot for walk-in bills.
const walkInName = "Walk-in"

// ── Params (named structs, per naming convention) ───────────────────────────

// BillLineParams is one line as it arrives on a create request. The handler
// has already decoded JSON and parsed the UUIDs; totals are NOT accepted from
// the client — this service recomputes them (the server owns the math).
type BillLineParams struct {
	ItemID    *uuid.UUID // nil = miscellaneous
	VariantID *uuid.UUID // nil = Type B / miscellaneous
	Name      string
	Quantity  float64 // count (Type A) or measure (Type B)
	UnitPrice float64 // resolved variant price, rate, or free-typed misc price
}

type CreateBillParams struct {
	CustomerID *uuid.UUID // nil = walk-in
	AmountPaid *float64   // nil = "paying now" defaults to the bill total
	Lines      []BillLineParams
}

// ── Interface + impl + constructor ──────────────────────────────────────────
type BillingService interface {
	Create(ctx context.Context, userID uuid.UUID, p CreateBillParams) (*repository.BillWithItems, error)
	List(ctx context.Context, userID uuid.UUID) ([]*repository.Bill, error)
	Get(ctx context.Context, id, userID uuid.UUID) (*repository.BillWithItems, error)
}

type billingService struct {
	repo repository.BillingRepository
	// customerRepo is the FROZEN customers feature's repository, reused
	// read-only (never modified): it proves the customer belongs to this user
	// (cross-shop guard — the FK alone would accept another shop's customer
	// id) and supplies the authoritative customer_name snapshot.
	customerRepo repository.CustomerRepository
}

func NewBillingService(repo repository.BillingRepository, customerRepo repository.CustomerRepository) BillingService {
	return &billingService{repo: repo, customerRepo: customerRepo}
}

// ── Create — validate, recompute totals, resolve the settle, hand to the tx ─
func (s *billingService) Create(
	ctx context.Context,
	userID uuid.UUID,
	p CreateBillParams,
) (*repository.BillWithItems, error) {
	// 1. Validate lines BEFORE touching the DB.
	if len(p.Lines) == 0 {
		return nil, ErrEmptyBill
	}
	for _, l := range p.Lines {
		if l.Name == "" || l.Quantity <= 0 || l.UnitPrice < 0 {
			return nil, ErrInvalidLine
		}
	}

	// 2. Recompute every money figure server-side (never trust client totals).
	//    line_total = quantity × unit_price, rounded to paise; bill total =
	//    Σ line_total. bills.amount = this total — the dashboard sums it.
	lines := make([]repository.BillLineInput, 0, len(p.Lines))
	total := 0.0
	for _, l := range p.Lines {
		lineTotal := round2(l.Quantity * l.UnitPrice)
		total = round2(total + lineTotal)
		lines = append(lines, repository.BillLineInput{
			ItemID:    l.ItemID,
			VariantID: l.VariantID,
			Name:      l.Name,
			Quantity:  l.Quantity,
			UnitPrice: l.UnitPrice,
			LineTotal: lineTotal,
		})
	}

	// 3. Resolve "paying now": omitted → defaults to the bill total (the
	//    settle screen pre-fills it; cash sale = one tap).
	paid := total
	if p.AmountPaid != nil {
		paid = round2(*p.AmountPaid)
	}
	if paid < 0 {
		return nil, ErrNegativeAmountPaid
	}

	// 4. Walk-in vs customer.
	if p.CustomerID == nil {
		// Walk-in: no ledger to owe against → must pay exactly in full.
		// (Overpay is meaningless too — there's no balance to credit.)
		if !moneyEqual(paid, total) {
			return nil, ErrWalkInMustPayFull
		}
		// No khata entries: a walk-in has no ledger.
		return s.repo.CreateBillWithItems(ctx, userID, nil, walkInName, total, paid, lines, nil)
	}

	// Customer bill: prove ownership + snapshot the name. GetByID is scoped
	// by user_id, so a foreign/unknown id returns ErrCustomerNotFound (404).
	customer, err := s.customerRepo.GetByID(ctx, *p.CustomerID, userID)
	if err != nil {
		return nil, err
	}

	// Decide the khata writes HERE (business rule), let the repository write
	// them inside the settlement transaction (atomicity).
	entries := khataEntriesFor(total, paid)
	return s.repo.CreateBillWithItems(ctx, userID, p.CustomerID, customer.Name, total, paid, lines, entries)
}

// khataEntriesFor decides what a customer's bill writes to their khata.
// Pure function (no I/O), unit-tested in billing_service_test.go.
//
//	paid == total → nothing: a fully settled sale has no place in the dues book.
//	paid != total → a 'credit' for the WHOLE bill (linked to it), plus a
//	                'payment' for what was paid now, if anything.
//
// The balance stays DERIVED from entries, never stored:
// new_balance = old_balance + total − paid. paid > total is legal: the
// surplus pays down old dues (owes 500, bill 250, pays 300 → 450).
// "Equal" uses moneyEqual, the same half-paisa tolerance as the walk-in rule,
// so the whole service shares one definition of "paid in full".
func khataEntriesFor(total, paid float64) []repository.KhataEntryInput {
	if moneyEqual(paid, total) {
		return nil
	}
	entries := []repository.KhataEntryInput{
		{Type: "credit", Amount: total, LinkToBill: true},
	}
	if paid > 0 {
		entries = append(entries, repository.KhataEntryInput{Type: "payment", Amount: paid})
	}
	return entries
}

// ── List / Get — pure pass-throughs (no business rules on read) ─────────────
func (s *billingService) List(ctx context.Context, userID uuid.UUID) ([]*repository.Bill, error) {
	return s.repo.ListBills(ctx, userID)
}

func (s *billingService) Get(ctx context.Context, id, userID uuid.UUID) (*repository.BillWithItems, error) {
	return s.repo.GetBillByID(ctx, id, userID)
}

// ── Money helpers — pure functions ──────────────────────────────────────────

// round2 rounds to 2 decimals (paise). All money math routes through this so
// float drift can never leak into a stored NUMERIC.
func round2(x float64) float64 {
	return math.Round(x*100) / 100
}

// moneyEqual compares two already-rounded money values with a half-paisa
// tolerance — never compare floats with ==.
func moneyEqual(a, b float64) bool {
	return math.Abs(a-b) < 0.005
}
