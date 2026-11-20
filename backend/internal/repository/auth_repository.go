package repository

import (
	"context"
	"errors"
	"fmt"

	"github.com/jmoiron/sqlx"
	"github.com/sanu1001/KhataDost/backend/internal/sqlcgen"
)

// ErrDuplicateEmail is returned when the email is already registered
// (Postgres unique violation 23505 on users.email).
var ErrDuplicateEmail = errors.New("email already registered")

type AuthRepository interface {
	CreateUser(ctx context.Context, params sqlcgen.CreateUserParams) (sqlcgen.User, error)
	GetUserByEmail(ctx context.Context, email string) (sqlcgen.User, error)
}

type authRepository struct {
	queries *sqlcgen.Queries
}

func NewAuthRepository(db *sqlx.DB) AuthRepository {
	return &authRepository{
		queries: sqlcgen.New(db),
	}
}

func (r *authRepository) CreateUser(ctx context.Context, params sqlcgen.CreateUserParams) (sqlcgen.User, error) {
	user, err := r.queries.CreateUser(ctx, params)
	if err != nil {
		if isUniqueViolation(err) { // helper in customer_repository.go
			return sqlcgen.User{}, ErrDuplicateEmail
		}
		return sqlcgen.User{}, fmt.Errorf("CreateUser: %w", err)
	}
	return user, nil
}

func (r *authRepository) GetUserByEmail(ctx context.Context, email string) (sqlcgen.User, error) {
	return r.queries.GetUserByEmail(ctx, email)
}
