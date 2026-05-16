package repository

import (
	"context"

	"github.com/jmoiron/sqlx"
	"github.com/sanu1001/KhataDost/backend/internal/sqlcgen"
)

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
	return r.queries.CreateUser(ctx, params)
}

func (r *authRepository) GetUserByEmail(ctx context.Context, email string) (sqlcgen.User, error) {
	return r.queries.GetUserByEmail(ctx, email)
}
