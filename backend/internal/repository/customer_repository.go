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

// ── Domain struct (separate from sqlcgen types) ──────────────────────────────
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
	// Field-by-field extraction: works regardless of whether sqlc names the
	// returned struct Customer, CreateCustomerRow, or something else after
	// migration 006 made has_dues a computed column (false literal for CREATE).
	c := toCustomer(row.ID, row.Name, row.Phone, row.Email, row.Notes, row.HasDues, row.CreatedAt, row.UpdatedAt)
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
		customers = append(customers, toCustomer(row.ID, row.Name, row.Phone, row.Email, row.Notes, row.HasDues, row.CreatedAt, row.UpdatedAt))
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
	c := toCustomer(row.ID, row.Name, row.Phone, row.Email, row.Notes, row.HasDues, row.CreatedAt, row.UpdatedAt)
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
	c := toCustomer(row.ID, row.Name, row.Phone, row.Email, row.Notes, row.HasDues, row.CreatedAt, row.UpdatedAt)
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

// toCustomer builds a domain Customer from explicit column values.
//
// After migration 006 dropped the has_dues column, sqlc regenerate may produce
// per-query Row structs (CreateCustomerRow, ListCustomersRow, etc.) instead of
// reusing the table's Customer model. By extracting fields by name at the call
// site (row.ID, row.HasDues, …) and passing them here as plain Go values, this
// function remains type-agnostic — it compiles regardless of what sqlc names the
// returned struct, as long as the struct has the expected field names.
func toCustomer(
	id uuid.UUID,
	name, phone string,
	email, notes sql.NullString,
	hasDues bool,
	createdAt, updatedAt time.Time,
) Customer {
	return Customer{
		ID:        id.String(),
		Name:      name,
		Phone:     phone,
		Email:     fromNullString(email),
		Notes:     fromNullString(notes),
		HasDues:   hasDues,
		CreatedAt: createdAt,
		UpdatedAt: updatedAt,
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
