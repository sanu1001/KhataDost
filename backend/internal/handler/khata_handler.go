package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/sanu1001/KhataDost/backend/internal/middleware"
	"github.com/sanu1001/KhataDost/backend/internal/repository"
	"github.com/sanu1001/KhataDost/backend/internal/service"
)

// ── Response structs ─────────────────────────────────────────────────────────
// bill_id / note emit JSON null when nil (pointer fields). amount is a JSON
// number (float64). created_at is RFC 3339 (standard time.Time encoding).
type khataEntryResponse struct {
	ID        string    `json:"id"`
	Type      string    `json:"type"`
	Amount    float64   `json:"amount"`
	BillID    *string   `json:"bill_id"`
	Note      *string   `json:"note"`
	CreatedAt time.Time `json:"created_at"`
}

type khataResponse struct {
	Balance float64              `json:"balance"`
	Entries []khataEntryResponse `json:"entries"`
}

// ── Request struct ───────────────────────────────────────────────────────────
type recordPaymentRequest struct {
	Amount float64 `json:"amount"`
}

// ── Handler ──────────────────────────────────────────────────────────────────
type KhataHandler struct {
	khataService service.KhataService
}

func NewKhataHandler(khataService service.KhataService) *KhataHandler {
	return &KhataHandler{khataService: khataService}
}

// ── GET /v1/khata/{customerId} ───────────────────────────────────────────────
// Returns the entry timeline (oldest first) + derived balance for one customer.
func (h *KhataHandler) GetKhata(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	customerID, err := uuid.Parse(chi.URLParam(r, "customerId"))
	if err != nil {
		writeError(w, "invalid customer id", http.StatusBadRequest)
		return
	}

	view, err := h.khataService.GetKhata(r.Context(), userID, customerID)
	if err != nil {
		writeKhataError(w, err, "could not load khata")
		return
	}

	entries := make([]khataEntryResponse, 0, len(view.Entries))
	for _, e := range view.Entries {
		entries = append(entries, toKhataEntryResponse(e))
	}

	writeJSON(w, khataResponse{Balance: view.Balance, Entries: entries}, http.StatusOK)
}

// ── POST /v1/khata/{customerId}/payment ──────────────────────────────────────
// Inserts a 'payment' entry and returns it (201). Validates amount > 0.
func (h *KhataHandler) RecordPayment(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	customerID, err := uuid.Parse(chi.URLParam(r, "customerId"))
	if err != nil {
		writeError(w, "invalid customer id", http.StatusBadRequest)
		return
	}

	var req recordPaymentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	entry, err := h.khataService.RecordPayment(r.Context(), userID, customerID, req.Amount)
	if err != nil {
		writeKhataError(w, err, "could not record payment")
		return
	}

	writeJSON(w, toKhataEntryResponse(*entry), http.StatusCreated)
}

// ── Sentinel → status mapping ────────────────────────────────────────────────
func writeKhataError(w http.ResponseWriter, err error, fallback string) {
	switch {
	case errors.Is(err, service.ErrNonPositivePayment):
		writeError(w, err.Error(), http.StatusBadRequest)
	case errors.Is(err, repository.ErrCustomerNotFound):
		writeError(w, "customer not found", http.StatusNotFound)
	default:
		writeError(w, fallback, http.StatusInternalServerError)
	}
}

// ── Mapping helpers ──────────────────────────────────────────────────────────
func toKhataEntryResponse(e repository.KhataEntry) khataEntryResponse {
	return khataEntryResponse{
		ID:        e.ID,
		Type:      e.Type,
		Amount:    e.Amount,
		BillID:    e.BillID,
		Note:      e.Note,
		CreatedAt: e.CreatedAt,
	}
}
