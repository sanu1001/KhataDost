package handler

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/go-chi/chi/v5"
	"github.com/google/uuid"

	"github.com/sanu1001/KhataDost/backend/internal/middleware"
	"github.com/sanu1001/KhataDost/backend/internal/repository"
	"github.com/sanu1001/KhataDost/backend/internal/service"
)

// ── Request structs (decode + validate) ─────────────────────────────────────

// variantRequest is one variant inside a create-item body. is_default defaults
// to false if omitted (Go zero value), which the service's default-count guard
// then validates (exactly one must be true).
type variantRequest struct {
	Label       string  `json:"label"`
	Price       float64 `json:"price"`
	IsDefault   bool    `json:"is_default"`
	Description *string `json:"description"`
}

type createItemRequest struct {
	Name        string           `json:"name"`
	PricingType string           `json:"pricing_type"`
	Rate        *float64         `json:"rate"`     // Type B only; nil for Type A
	Unit        *string          `json:"unit"`     // Type B only
	Variants    []variantRequest `json:"variants"` // Type A only; omitted/[] for Type B
}

type updateItemRequest struct {
	Name string   `json:"name"`
	Rate *float64 `json:"rate"`
	Unit *string  `json:"unit"`
}

type variantBodyRequest struct {
	Label       string  `json:"label"`
	Price       float64 `json:"price"`
	IsDefault   bool    `json:"is_default"`
	Description *string `json:"description"`
}

// ── Response structs (the nested JSON contract) ─────────────────────────────
// *float64/*string emit JSON null when nil — matches the doc (rate:null on
// unit items). Variants is always a non-nil slice → emits [] not null for loose.
type variantResponse struct {
	ID        string  `json:"id"`
	Label     string  `json:"label"`
	Price     float64 `json:"price"`
	IsDefault bool    `json:"is_default"`
}

type itemResponse struct {
	ID          string            `json:"id"`
	Name        string            `json:"name"`
	PricingType string            `json:"pricing_type"`
	Rate        *float64          `json:"rate"`
	Unit        *string           `json:"unit"`
	Variants    []variantResponse `json:"variants"`
}

type listItemsResponse struct {
	Items []itemResponse `json:"items"`
}

// ── Handler ─────────────────────────────────────────────────────────────────
type InventoryHandler struct {
	inventoryService service.InventoryService
}

func NewInventoryHandler(inventoryService service.InventoryService) *InventoryHandler {
	return &InventoryHandler{inventoryService: inventoryService}
}

// ── POST /v1/inventory ──────────────────────────────────────────────────────
func (h *InventoryHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var req createItemRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}
	if req.Name == "" || req.PricingType == "" {
		writeError(w, "name and pricing_type are required", http.StatusBadRequest)
		return
	}

	// Map the request's variants → service VariantInput. (Type-shape rules —
	// e.g. loose-with-variants — are the SERVICE's job, not the handler's.)
	variants := make([]service.VariantInput, 0, len(req.Variants))
	for _, v := range req.Variants {
		variants = append(variants, service.VariantInput{
			Label:       v.Label,
			Price:       v.Price,
			IsDefault:   v.IsDefault,
			Description: v.Description,
		})
	}

	item, err := h.inventoryService.Create(r.Context(), userID, service.CreateItemParams{
		Name:        req.Name,
		PricingType: req.PricingType,
		Rate:        req.Rate,
		Unit:        req.Unit,
		Variants:    variants,
	})
	if err != nil {
		writeInventoryError(w, err, "could not create item")
		return
	}

	writeJSON(w, toItemResponse(item), http.StatusCreated)
}

// ── GET /v1/inventory ───────────────────────────────────────────────────────
func (h *InventoryHandler) List(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	items, err := h.inventoryService.List(r.Context(), userID)
	if err != nil {
		writeError(w, "could not load inventory", http.StatusInternalServerError)
		return
	}

	resp := make([]itemResponse, 0, len(items))
	for _, it := range items {
		resp = append(resp, toItemResponse(it))
	}

	writeJSON(w, listItemsResponse{Items: resp}, http.StatusOK)
}

// ── PUT /v1/inventory/{id} ──────────────────────────────────────────────────
func (h *InventoryHandler) UpdateItem(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, "invalid item id", http.StatusBadRequest)
		return
	}

	var req updateItemRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}
	if req.Name == "" {
		writeError(w, "name is required", http.StatusBadRequest)
		return
	}

	item, err := h.inventoryService.UpdateItem(r.Context(), id, userID, service.UpdateItemParams{
		Name: req.Name,
		Rate: req.Rate,
		Unit: req.Unit,
	})
	if err != nil {
		writeInventoryError(w, err, "could not update item")
		return
	}

	// UpdateItem returns *repository.Item (no variants) → wrap with empty slice.
	writeJSON(w, toItemResponseFromItem(item), http.StatusOK)
}

// ── DELETE /v1/inventory/{id} ───────────────────────────────────────────────
// Twin of your customer Delete: parse id, call service, map error, 204.
// Sentinel to map: repository.ErrItemNotFound → 404 (use writeInventoryError).
func (h *InventoryHandler) DeleteItem(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, "unauthorized", http.StatusUnauthorized)
		return
	}
	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, "invalid item id", http.StatusBadRequest)
		return
	}

	err = h.inventoryService.DeleteItem(r.Context(), id, userID)
	if err != nil {
		writeInventoryError(w, err, "could not delete item")
		return
	}

	w.WriteHeader(http.StatusNoContent)

}

// ── POST /v1/inventory/{id}/variants ────────────────────────────────────────
func (h *InventoryHandler) AddVariant(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	itemID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, "invalid item id", http.StatusBadRequest)
		return
	}

	var req variantBodyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}
	if req.Label == "" {
		writeError(w, "label is required", http.StatusBadRequest)
		return
	}

	variant, err := h.inventoryService.AddVariant(r.Context(), itemID, userID, service.AddVariantParams{
		Label:       req.Label,
		Price:       req.Price,
		IsDefault:   req.IsDefault,
		Description: req.Description,
	})
	if err != nil {
		writeInventoryError(w, err, "could not add variant")
		return
	}

	writeJSON(w, toVariantResponse(*variant), http.StatusCreated)
}

// ── PUT /v1/inventory/{id}/variants/{vid} ───────────────────────────────────
func (h *InventoryHandler) UpdateVariant(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	itemID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, "invalid item id", http.StatusBadRequest)
		return
	}
	variantID, err := uuid.Parse(chi.URLParam(r, "vid"))
	if err != nil {
		writeError(w, "invalid variant id", http.StatusBadRequest)
		return
	}

	var req variantBodyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}
	if req.Label == "" {
		writeError(w, "label is required", http.StatusBadRequest)
		return
	}

	variant, err := h.inventoryService.UpdateVariant(r.Context(), itemID, variantID, userID, service.UpdateVariantParams{
		Label:       req.Label,
		Price:       req.Price,
		IsDefault:   req.IsDefault,
		Description: req.Description,
	})
	if err != nil {
		writeInventoryError(w, err, "could not update variant")
		return
	}

	writeJSON(w, toVariantResponse(*variant), http.StatusOK)
}

// ── DELETE /v1/inventory/{id}/variants/{vid} ────────────────────────────────
// TWO path params: parse both "id" and "vid". Call DeleteVariant(itemID,
// variantID, userID), map error via writeInventoryError, 204 on success.
func (h *InventoryHandler) DeleteVariant(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	itemID, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, "invalid item id", http.StatusBadRequest)
		return
	}
	variantID, err := uuid.Parse(chi.URLParam(r, "vid"))
	if err != nil {
		writeError(w, "invalid variant id", http.StatusBadRequest)
		return
	}
	err = h.inventoryService.DeleteVariant(r.Context(), itemID, variantID, userID)
	if err != nil {
		writeInventoryError(w, err, "could not delete variant")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// ── Sentinel → status mapping (shared by every inventory handler) ───────────
// Spans BOTH layers: service business-rule errors AND repository errors that
// pass through the service unwrapped. errors.Is matches either. Anything
// unrecognized → 500 with the caller's generic fallback message.
func writeInventoryError(w http.ResponseWriter, err error, fallback string) {
	switch {
	case errors.Is(err, service.ErrInvalidPricingType),
		errors.Is(err, service.ErrUnitNeedsVariants),
		errors.Is(err, service.ErrUnitNeedsOneDefault),
		errors.Is(err, service.ErrLooseNeedsRateUnit):
		writeError(w, err.Error(), http.StatusBadRequest)
	case errors.Is(err, service.ErrLooseItemNoVariants):
		writeError(w, err.Error(), http.StatusConflict)
	case errors.Is(err, repository.ErrDuplicateItemName):
		writeError(w, err.Error(), http.StatusConflict)
	case errors.Is(err, repository.ErrItemNotFound):
		writeError(w, "item not found", http.StatusNotFound)
	case errors.Is(err, repository.ErrVariantNotFound):
		writeError(w, "variant not found", http.StatusNotFound)
	default:
		writeError(w, fallback, http.StatusInternalServerError)
	}
}

// ── Mapping helpers (domain → response) ─────────────────────────────────────

func toVariantResponse(v repository.Variant) variantResponse {
	return variantResponse{
		ID:        v.ID,
		Label:     v.Label,
		Price:     v.Price,
		IsDefault: v.IsDefault,
	}
}

// toItemResponse maps the nested ItemWithVariants (from Create/List).
func toItemResponse(it *repository.ItemWithVariants) itemResponse {
	variants := make([]variantResponse, 0, len(it.Variants))
	for _, v := range it.Variants {
		variants = append(variants, toVariantResponse(v))
	}
	return itemResponse{
		ID:          it.ID, // promoted from embedded Item
		Name:        it.Name,
		PricingType: it.PricingType,
		Rate:        it.Rate,
		Unit:        it.Unit,
		Variants:    variants,
	}
}

// toItemResponseFromItem maps a bare *repository.Item (from UpdateItem, which
// returns no variants). Variants emits [] — the client refetches the list for
// the authoritative nested shape.
func toItemResponseFromItem(it *repository.Item) itemResponse {
	return itemResponse{
		ID:          it.ID,
		Name:        it.Name,
		PricingType: it.PricingType,
		Rate:        it.Rate,
		Unit:        it.Unit,
		Variants:    make([]variantResponse, 0),
	}
}
