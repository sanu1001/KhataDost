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

// ── Request structs (decode + validate) ─────────────────────────────────────

// billLineRequest is one line on a create-bill body. item_id/variant_id are
// provenance pointers (both omitted for miscellaneous; variant_id omitted for
// Type B). line totals are NOT accepted — the service recomputes them.
type billLineRequest struct {
	ItemID    *string `json:"item_id"`
	VariantID *string `json:"variant_id"`
	Name      string  `json:"name"`
	Quantity  float64 `json:"quantity"`
	UnitPrice float64 `json:"unit_price"`
}

type createBillRequest struct {
	CustomerID *string           `json:"customer_id"` // omitted/null = walk-in
	AmountPaid *float64          `json:"amount_paid"` // omitted = pay in full
	Items      []billLineRequest `json:"items"`
}

// ── Response structs ─────────────────────────────────────────────────────────
// *string emits JSON null when nil — item_id/variant_id/customer_id are null
// for miscellaneous/Type B/walk-in respectively. Items is always a non-nil
// slice → emits [] (the list endpoint returns headers with items: []).
type billItemResponse struct {
	ID        string  `json:"id"`
	ItemID    *string `json:"item_id"`
	VariantID *string `json:"variant_id"`
	Name      string  `json:"name"`
	Quantity  float64 `json:"quantity"`
	UnitPrice float64 `json:"unit_price"`
	LineTotal float64 `json:"line_total"`
}

type billResponse struct {
	ID           string             `json:"id"`
	CustomerID   *string            `json:"customer_id"`
	CustomerName string             `json:"customer_name"`
	Amount       float64            `json:"amount"` // bill total
	AmountPaid   float64            `json:"amount_paid"`
	CreatedAt    time.Time          `json:"created_at"`
	Items        []billItemResponse `json:"items"`
}

type listBillsResponse struct {
	Bills []billResponse `json:"bills"`
}

// ── Handler ─────────────────────────────────────────────────────────────────
type BillingHandler struct {
	billingService service.BillingService
}

func NewBillingHandler(billingService service.BillingService) *BillingHandler {
	return &BillingHandler{billingService: billingService}
}

// ── POST /v1/bills — create + settle in one shot ────────────────────────────
func (h *BillingHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var req createBillRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}
	if len(req.Items) == 0 {
		writeError(w, "items are required", http.StatusBadRequest)
		return
	}

	// Parse body UUIDs here — the handler owns decode+validate; the service
	// receives typed params only.
	customerID, err := parseOptionalUUID(req.CustomerID)
	if err != nil {
		writeError(w, "invalid customer id", http.StatusBadRequest)
		return
	}

	lines := make([]service.BillLineParams, 0, len(req.Items))
	for _, it := range req.Items {
		itemID, err := parseOptionalUUID(it.ItemID)
		if err != nil {
			writeError(w, "invalid item id", http.StatusBadRequest)
			return
		}
		variantID, err := parseOptionalUUID(it.VariantID)
		if err != nil {
			writeError(w, "invalid variant id", http.StatusBadRequest)
			return
		}
		lines = append(lines, service.BillLineParams{
			ItemID:    itemID,
			VariantID: variantID,
			Name:      it.Name,
			Quantity:  it.Quantity,
			UnitPrice: it.UnitPrice,
		})
	}

	bill, err := h.billingService.Create(r.Context(), userID, service.CreateBillParams{
		CustomerID: customerID,
		AmountPaid: req.AmountPaid,
		Lines:      lines,
	})
	if err != nil {
		writeBillingError(w, err, "could not create bill")
		return
	}

	writeJSON(w, toBillResponse(bill), http.StatusCreated)
}

// ── GET /v1/bills — headers only, newest first ──────────────────────────────
func (h *BillingHandler) List(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	bills, err := h.billingService.List(r.Context(), userID)
	if err != nil {
		writeError(w, "could not load bills", http.StatusInternalServerError)
		return
	}

	resp := make([]billResponse, 0, len(bills))
	for _, b := range bills {
		resp = append(resp, toBillHeaderResponse(b))
	}

	writeJSON(w, listBillsResponse{Bills: resp}, http.StatusOK)
}

// ── GET /v1/bills/{id} — header + lines ─────────────────────────────────────
func (h *BillingHandler) GetByID(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, "invalid bill id", http.StatusBadRequest)
		return
	}

	bill, err := h.billingService.Get(r.Context(), id, userID)
	if err != nil {
		writeBillingError(w, err, "could not load bill")
		return
	}

	writeJSON(w, toBillResponse(bill), http.StatusOK)
}

// ── Sentinel → status mapping (shared by every billing handler) ─────────────
// Spans BOTH layers: service business-rule errors AND repository errors that
// pass through the service unwrapped. Anything unrecognized → 500 with the
// caller's generic fallback message.
func writeBillingError(w http.ResponseWriter, err error, fallback string) {
	switch {
	case errors.Is(err, service.ErrEmptyBill),
		errors.Is(err, service.ErrInvalidLine),
		errors.Is(err, service.ErrNegativeAmountPaid):
		writeError(w, err.Error(), http.StatusBadRequest)
	case errors.Is(err, service.ErrWalkInMustPayFull):
		writeError(w, err.Error(), http.StatusConflict)
	case errors.Is(err, repository.ErrCustomerNotFound):
		writeError(w, "customer not found", http.StatusNotFound)
	case errors.Is(err, repository.ErrBillNotFound):
		writeError(w, "bill not found", http.StatusNotFound)
	default:
		writeError(w, fallback, http.StatusInternalServerError)
	}
}

// ── Mapping helpers ──────────────────────────────────────────────────────────

// parseOptionalUUID: *string → *uuid.UUID. nil in → nil out (not an error);
// present-but-garbage → error.
func parseOptionalUUID(s *string) (*uuid.UUID, error) {
	if s == nil {
		return nil, nil
	}
	u, err := uuid.Parse(*s)
	if err != nil {
		return nil, err
	}
	return &u, nil
}

func toBillItemResponse(it repository.BillItem) billItemResponse {
	return billItemResponse{
		ID:        it.ID,
		ItemID:    it.ItemID,
		VariantID: it.VariantID,
		Name:      it.Name,
		Quantity:  it.Quantity,
		UnitPrice: it.UnitPrice,
		LineTotal: it.LineTotal,
	}
}

// toBillResponse maps the nested BillWithItems (from Create/GetByID).
func toBillResponse(b *repository.BillWithItems) billResponse {
	items := make([]billItemResponse, 0, len(b.Items))
	for _, it := range b.Items {
		items = append(items, toBillItemResponse(it))
	}
	return billResponse{
		ID:           b.ID, // promoted from embedded Bill
		CustomerID:   b.CustomerID,
		CustomerName: b.CustomerName,
		Amount:       b.Amount,
		AmountPaid:   b.AmountPaid,
		CreatedAt:    b.CreatedAt,
		Items:        items,
	}
}

// toBillHeaderResponse maps a bare *repository.Bill (from List, which returns
// no lines). Items emits [] — the client fetches the detail for lines.
func toBillHeaderResponse(b *repository.Bill) billResponse {
	return billResponse{
		ID:           b.ID,
		CustomerID:   b.CustomerID,
		CustomerName: b.CustomerName,
		Amount:       b.Amount,
		AmountPaid:   b.AmountPaid,
		CreatedAt:    b.CreatedAt,
		Items:        make([]billItemResponse, 0),
	}
}
