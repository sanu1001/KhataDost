package service

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"github.com/sanu1001/KhataDost/backend/internal/repository"
)

// ── Sentinel errors owned by THIS layer ─────────────────────────────────────
// Business-rule errors. Repository-level errors (ErrDuplicatePhone,
// ErrCustomerNotFound) are defined in the repository and pass through.
var (
	// ErrCustomerHasDues blocks deletion of a customer with outstanding dues.
	ErrCustomerHasDues = errors.New("customer has outstanding dues and cannot be deleted")
)

// ── Params (named structs, per naming convention) ───────────────────────────
type CreateCustomerParams struct {
	Name  string
	Phone string
	Email *string
	Notes *string
}

type UpdateCustomerParams struct {
	Name  string
	Phone string
	Email *string
	Notes *string
}

// ── Interface + impl ────────────────────────────────────────────────────────
type CustomerService interface {
	Create(ctx context.Context, userID uuid.UUID, p CreateCustomerParams) (*repository.Customer, error)
	List(ctx context.Context, userID uuid.UUID) ([]repository.Customer, error)
	Update(ctx context.Context, id, userID uuid.UUID, p UpdateCustomerParams) (*repository.Customer, error)
	Delete(ctx context.Context, id, userID uuid.UUID) error
}

type customerService struct {
	repo repository.CustomerRepository
}

func NewCustomerService(repo repository.CustomerRepository) CustomerService {
	return &customerService{repo: repo}
}

// ── Create ──────────────────────────────────────────────────────────────────
func (s *customerService) Create(
	ctx context.Context,
	userID uuid.UUID,
	p CreateCustomerParams,
) (*repository.Customer, error) {
	return s.repo.Create(ctx, userID, p.Name, p.Phone, p.Email, p.Notes)
}

// ── List ────────────────────────────────────────────────────────────────────
func (s *customerService) List(ctx context.Context, userID uuid.UUID) ([]repository.Customer, error) {
	return s.repo.List(ctx, userID)
}

// ── Update ──────────────────────────────────────────────────────────────────
func (s *customerService) Update(
	ctx context.Context,
	id, userID uuid.UUID,
	p UpdateCustomerParams,
) (*repository.Customer, error) {
	return s.repo.Update(ctx, id, userID, p.Name, p.Phone, p.Email, p.Notes)
}

// ── Delete (the only method with business logic) ────────────────────────────
func (s *customerService) Delete(ctx context.Context, id, userID uuid.UUID) error {
	// 1. Fetch first — disambiguates not-found (404) from has-dues (409).
	customer, err := s.repo.GetByID(ctx, id, userID)
	if err != nil {
		// Passes ErrCustomerNotFound straight through to the handler.
		return err
	}

	// 2. Business rule: dues block deletion (defense layer 2 — server side).
	if customer.HasDues {
		return ErrCustomerHasDues
	}

	// 3. Clear to delete.
	return s.repo.Delete(ctx, id, userID)
}
