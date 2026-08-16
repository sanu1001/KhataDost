package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
	"github.com/sanu1001/KhataDost/backend/internal/sqlcgen"
)

type MeRepository interface {
	GetByID(ctx context.Context, userID uuid.UUID) (*Profile, error)
}

type meRepository struct {
	queries *sqlcgen.Queries
}

func NewMeRepository(db *sqlx.DB) MeRepository {
	return &meRepository{
		queries: sqlcgen.New(db),
	}
}

// Profile is the read-only shop/owner profile surfaced on the Settings page.
// Password is deliberately never selected/returned.
type Profile struct {
	ID       string
	Name     string
	ShopName string
	Email    string
	Phone    string
}

func (r *meRepository) GetByID(ctx context.Context, userID uuid.UUID) (*Profile, error) {
	row, err := r.queries.GetUserByID(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("GetUserByID: %w", err)
	}

	return &Profile{
		ID:       row.ID.String(),
		Name:     row.Name,
		ShopName: row.ShopName,
		Email:    row.Email,
		Phone:    row.Phone,
	}, nil
}
