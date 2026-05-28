package service

import (
	"context"

	"github.com/google/uuid"
	"github.com/sanu1001/KhataDost/backend/internal/repository"
)

type DashboardService interface {
	GetDashboardSummary(ctx context.Context, userID uuid.UUID) (*repository.DashboardSummary, error)
}

type dashboardService struct {
	repo repository.DashboardRepository
}

func NewDashboardService(repo repository.DashboardRepository) DashboardService {
	return &dashboardService{repo: repo}
}

func (s *dashboardService) GetDashboardSummary(ctx context.Context, userID uuid.UUID) (*repository.DashboardSummary, error) {
	return s.repo.GetDashboardSummary(ctx, userID)
}
