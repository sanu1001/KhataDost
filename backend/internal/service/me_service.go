package service

import (
	"context"
	"database/sql"
	"errors"

	"github.com/google/uuid"
	"github.com/sanu1001/KhataDost/backend/internal/repository"
)

// ErrUserNotFound is returned when the authenticated user's row no longer
// exists (e.g. the account was deleted but a still-valid JWT was presented).
var ErrUserNotFound = errors.New("user not found")

type MeService interface {
	GetProfile(ctx context.Context, userID uuid.UUID) (*repository.Profile, error)
}

type meService struct {
	repo repository.MeRepository
}

func NewMeService(repo repository.MeRepository) MeService {
	return &meService{repo: repo}
}

func (s *meService) GetProfile(ctx context.Context, userID uuid.UUID) (*repository.Profile, error) {
	profile, err := s.repo.GetByID(ctx, userID)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrUserNotFound
		}
		return nil, err
	}
	return profile, nil
}
