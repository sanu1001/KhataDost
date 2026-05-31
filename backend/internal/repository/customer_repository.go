package repository

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jmoiron/sqlx"

	"github.com/sanu1001/KhataDost/backend/internal/sqlcgen"
)

// ── Sentinel errors (mapped to HTTP status in the handler) ──────────────────
var (
	// ErrDuplicatePhone is returned when (user_id, phone) already exists.
	// Triggered by Postgres unique-violation SQLSTATE 23505.
	ErrDuplicatePhone = errors.New("a customer with this phone already exists")

	// ErrCustomerNotFound is returned when no row matches the id+user_id scope.
	ErrCustomerNotFound = errors.New("customer not found")
)

// ── Domain struct (separate from sqlcgen.Customer) ──────────────────────────
// email/notes are *string (nullable), not sql.NullString — the service and
// handler never see database/sql types.
type Customer struct {
	ID        string
	Name      string
	Phone     string
	Email     *string
	Notes     *string
	HasDues   bool
	CreatedAt time.Time
	UpdatedAt time.Time
}

// ── Interface + impl ────────────────────────────────────────────────────────
type CustomerRepository interface {
	Create(ctx context.Context, userID uuid.UUID, name, phone string, email, notes *string) (*Customer, error)
	List(ctx context.Context, userID uuid.UUID) ([]Customer, error)
	GetByID(ctx context.Context, id, userID uuid.UUID) (*Customer, error)
	Update(ctx context.Context, id, userID uuid.UUID, name, phone string, email, notes *string) (*Customer, error)
	Delete(ctx context.Context, id, userID uuid.UUID) error
}

type customerRepository struct {
	queries *sqlcgen.Queries
}

func NewCustomerRepository(db *sqlx.DB) CustomerRepository {
	return &customerRepository{queries: sqlcgen.New(db)}
}

// ── Create ──────────────────────────────────────────────────────────────────
func (r *customerRepository) Create(
	ctx context.Context,
	userID uuid.UUID,
	name, phone string,
	email, notes *string,
) (*Customer, error) {
	row, err := r.queries.CreateCustomer(ctx, sqlcgen.CreateCustomerParams{
		UserID: userID,
		Name:   name,
		Phone:  phone,
		Email:  toNullString(email),
		Notes:  toNullString(notes),
	})
	if err != nil {
		if isUniqueViolation(err) {
			return nil, ErrDuplicatePhone
		}
		return nil, fmt.Errorf("CreateCustomer: %w", err)
	}
	c := toDomain(row)
	return &c, nil
}

// ── List ────────────────────────────────────────────────────────────────────
func (r *customerRepository) List(ctx context.Context, userID uuid.UUID) ([]Customer, error) {
	rows, err := r.queries.ListCustomers(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("ListCustomers: %w", err)
	}
	customers := make([]Customer, 0, len(rows))
	for _, row := range rows {
		customers = append(customers, toDomain(row))
	}
	return customers, nil
}

// ── GetByID ─────────────────────────────────────────────────────────────────
func (r *customerRepository) GetByID(ctx context.Context, id, userID uuid.UUID) (*Customer, error) {
	row, err := r.queries.GetCustomerByID(ctx, sqlcgen.GetCustomerByIDParams{
		ID:     id,
		UserID: userID,
	})
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrCustomerNotFound
		}
		return nil, fmt.Errorf("GetCustomerByID: %w", err)
	}
	c := toDomain(row)
	return &c, nil
}

// ── Update ──────────────────────────────────────────────────────────────────
func (r *customerRepository) Update(
	ctx context.Context,
	id, userID uuid.UUID,
	name, phone string,
	email, notes *string,
) (*Customer, error) {
	row, err := r.queries.UpdateCustomer(ctx, sqlcgen.UpdateCustomerParams{
		ID:     id,
		UserID: userID,
		Name:   name,
		Phone:  phone,
		Email:  toNullString(email),
		Notes:  toNullString(notes),
	})
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrCustomerNotFound
		}
		if isUniqueViolation(err) {
			return nil, ErrDuplicatePhone
		}
		return nil, fmt.Errorf("UpdateCustomer: %w", err)
	}
	c := toDomain(row)
	return &c, nil
}

// ── Delete ──────────────────────────────────────────────────────────────────
func (r *customerRepository) Delete(ctx context.Context, id, userID uuid.UUID) error {
	err := r.queries.DeleteCustomer(ctx, sqlcgen.DeleteCustomerParams{
		ID:     id,
		UserID: userID,
	})
	if err != nil {
		return fmt.Errorf("DeleteCustomer: %w", err)
	}
	return nil
}

// ── Mapping helpers ─────────────────────────────────────────────────────────

// toDomain maps a sqlc row → the repository's domain Customer.
func toDomain(row sqlcgen.Customer) Customer {
	return Customer{
		ID:        row.ID.String(),
		Name:      row.Name,
		Phone:     row.Phone,
		Email:     fromNullString(row.Email),
		Notes:     fromNullString(row.Notes),
		HasDues:   row.HasDues,
		CreatedAt: row.CreatedAt,
		UpdatedAt: row.UpdatedAt,
	}
}

// toNullString: *string → sql.NullString.  nil → NULL.
func toNullString(s *string) sql.NullString {
	if s == nil {
		return sql.NullString{Valid: false}
	}
	return sql.NullString{String: *s, Valid: true}
}

// fromNullString: sql.NullString → *string.  invalid → nil.
func fromNullString(ns sql.NullString) *string {
	if !ns.Valid {
		return nil
	}
	return &ns.String
}

// isUniqueViolation reports whether err is a Postgres unique-violation (23505).
func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		return pgErr.Code == "23505"
	}
	return false
}
