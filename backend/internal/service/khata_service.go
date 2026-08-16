package service

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"github.com/sanu1001/KhataDost/backend/internal/repository"
)

// ── Sentinel errors ──────────────────────────────────────────────────────────
var (
	// ErrNonPositivePayment — Record Payment amount must be > 0.
	ErrNonPositivePayment = errors.New("payment amount must be greater than zero")
)

// ── KhataView — returned by GetKhata (entries + derived balance) ─────────────
// Defined here (service layer) because it's a composition of two repo calls,
// not a single DB row — same split as BillWithItems vs its parts.
type KhataView struct {
	Balance float64
	Entries []repository.KhataEntry
}

// ── Interface + impl + constructor ──────────────────────────────────────────
type KhataService interface {
	// GetKhata returns the full entry timeline + derived balance for one
	// customer. Ownership-gates the customer (404 if not this user's).
	GetKhata(ctx context.Context, userID, customerID uuid.UUID) (*KhataView, error)

	// RecordPayment inserts a 'payment' entry and returns it.
	// amount must be > 0. Ownership-gates the customer.
	RecordPayment(ctx context.Context, userID, customerID uuid.UUID, amount float64) (*repository.KhataEntry, error)
}

type khataService struct {
	repo repository.KhataRepository
	// customerRepo is the FROZEN customers feature's repo, reused read-only:
	// proves the customer belongs to this user (cross-shop ownership gate).
	// Same pattern as billingService — never modified, never writes to customers.
	customerRepo repository.CustomerRepository
}

func NewKhataService(repo repository.KhataRepository, customerRepo repository.CustomerRepository) KhataService {
	return &khataService{repo: repo, customerRepo: customerRepo}
}

// ── GetKhata ─────────────────────────────────────────────────────────────────
func (s *khataService) GetKhata(ctx context.Context, userID, customerID uuid.UUID) (*KhataView, error) {
	// Ownership gate: GetByID is user-scoped; an unknown / foreign customer_id
	// returns ErrCustomerNotFound which the handler maps to 404.
	if _, err := s.customerRepo.GetByID(ctx, customerID, userID); err != nil {
		return nil, err
	}

	entries, err := s.repo.ListByCustomer(ctx, userID, customerID)
	if err != nil {
		return nil, err
	}

	balance, err := s.repo.GetBalance(ctx, userID, customerID)
	if err != nil {
		return nil, err
	}

	return &KhataView{Balance: balance, Entries: entries}, nil
}

// ── RecordPayment ─────────────────────────────────────────────────────────────
func (s *khataService) RecordPayment(ctx context.Context, userID, customerID uuid.UUID, amount float64) (*repository.KhataEntry, error) {
	if amount <= 0 {
		return nil, ErrNonPositivePayment
	}

	// Ownership gate — same reason as GetKhata.
	if _, err := s.customerRepo.GetByID(ctx, customerID, userID); err != nil {
		return nil, err
	}

	// round2 is defined in billing_service.go (same package) — no redefinition.
	rounded := round2(amount)

	// Insert a standalone 'payment' entry. No bill link; note is nil for now
	// (a future "add note" field can be wired here without a schema change).
	return s.repo.InsertEntry(ctx, userID, customerID, "payment", rounded, nil, nil)
}
