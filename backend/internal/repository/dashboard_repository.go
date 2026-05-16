package repository

import (
	"context"
	"fmt"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/jmoiron/sqlx"
	"github.com/sanu1001/KhataDost/backend/internal/sqlcgen"
)

type DashboardRepository interface {
	GetDashboardSummary(ctx context.Context, userID uuid.UUID) (*DashboardSummary, error)
}

type dashboardRepository struct {
	queries *sqlcgen.Queries
}

func NewDashboardRepository(db *sqlx.DB) DashboardRepository {
	return &dashboardRepository{
		queries: sqlcgen.New(db),
	}
}

type DashboardSummary struct {
	TodaySales  float64
	RecentBills []RecentBill
}

type RecentBill struct {
	ID           string
	CustomerName string
	Amount       float64
	CreatedAt    time.Time
}

func (r *dashboardRepository) GetDashboardSummary(ctx context.Context, userID uuid.UUID) (*DashboardSummary, error) {
	// 1. fetch today's sales
	totalSalesStr, err := r.queries.GetTodaySales(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("GetTodaySales: %w", err)
	}

	todaySales, err := strconv.ParseFloat(totalSalesStr, 64)
	if err != nil {
		return nil, fmt.Errorf("parsing total_sales: %w", err)
	}

	// 2. fetch recent bills
	rows, err := r.queries.GetRecentBills(ctx, userID)
	if err != nil {
		return nil, fmt.Errorf("GetRecentBills: %w", err)
	}

	// 3. convert sqlc rows → domain structs
	bills := make([]RecentBill, 0, len(rows))
	for _, row := range rows {
		amount, err := strconv.ParseFloat(row.Amount, 64)
		if err != nil {
			return nil, fmt.Errorf("parsing bill amount: %w", err)
		}
		bills = append(bills, RecentBill{
			ID:           row.ID.String(),
			CustomerName: row.CustomerName,
			Amount:       amount,
			CreatedAt:    row.CreatedAt,
		})
	}

	return &DashboardSummary{
		TodaySales:  todaySales,
		RecentBills: bills,
	}, nil
}
