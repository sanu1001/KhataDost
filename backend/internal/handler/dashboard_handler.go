package handler

import (
	"net/http"
	"time"

	"github.com/sanu1001/KhataDost/backend/internal/middleware"
	"github.com/sanu1001/KhataDost/backend/internal/service"
)

type recentBillResponse struct {
	ID           string    `json:"id"`
	CustomerName string    `json:"customer_name"`
	Amount       float64   `json:"amount"`
	CreatedAt    time.Time `json:"created_at"`
}

type dashboardSummaryResponse struct {
	TodaySales  float64              `json:"today_sales"`
	RecentBills []recentBillResponse `json:"recent_bills"`
}

type DashboardHandler struct {
	dashboardService service.DashboardService
}

func NewDashboardHandler(dashboardService service.DashboardService) *DashboardHandler {
	return &DashboardHandler{dashboardService: dashboardService}
}

func (h *DashboardHandler) GetSummary(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	summary, err := h.dashboardService.GetDashboardSummary(r.Context(), userID)
	if err != nil {
		writeError(w, "could not load dashboard", http.StatusInternalServerError)
		return
	}

	bills := make([]recentBillResponse, 0, len(summary.RecentBills))
	for _, b := range summary.RecentBills {
		bills = append(bills, recentBillResponse{
			ID:           b.ID,
			CustomerName: b.CustomerName,
			Amount:       b.Amount,
			CreatedAt:    b.CreatedAt,
		})
	}

	writeJSON(w, dashboardSummaryResponse{
		TodaySales:  summary.TodaySales,
		RecentBills: bills,
	}, http.StatusOK)
}
