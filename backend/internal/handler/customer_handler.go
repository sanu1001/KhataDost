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
// email/notes are *string so an omitted/null JSON field decodes to nil,
// which flows all the way to a SQL NULL.
type createCustomerRequest struct {
	Name  string  `json:"name"`
	Phone string  `json:"phone"`
	Email *string `json:"email"`
	Notes *string `json:"notes"`
}

type updateCustomerRequest struct {
	Name  string  `json:"name"`
	Phone string  `json:"phone"`
	Email *string `json:"email"`
	Notes *string `json:"notes"`
}

// ── Response struct ─────────────────────────────────────────────────────────
// *string fields emit JSON null when nil — matches the Flutter contract.
type customerResponse struct {
	ID      string  `json:"id"`
	Name    string  `json:"name"`
	Phone   string  `json:"phone"`
	Email   *string `json:"email"`
	Notes   *string `json:"notes"`
	HasDues bool    `json:"has_dues"`
}

type listCustomersResponse struct {
	Customers []customerResponse `json:"customers"`
}

// ── Handler ─────────────────────────────────────────────────────────────────
type CustomerHandler struct {
	customerService service.CustomerService
}

func NewCustomerHandler(customerService service.CustomerService) *CustomerHandler {
	return &CustomerHandler{customerService: customerService}
}

// ── POST /v1/customers ──────────────────────────────────────────────────────
func (h *CustomerHandler) Create(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	var req createCustomerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}
	if req.Name == "" || req.Phone == "" {
		writeError(w, "name and phone are required", http.StatusBadRequest)
		return
	}

	customer, err := h.customerService.Create(r.Context(), userID, service.CreateCustomerParams{
		Name:  req.Name,
		Phone: req.Phone,
		Email: req.Email,
		Notes: req.Notes,
	})
	if err != nil {
		if errors.Is(err, repository.ErrDuplicatePhone) {
			writeError(w, "a customer with this phone already exists", http.StatusBadRequest)
		} else {
			writeError(w, "could not create customer", http.StatusInternalServerError)
		}
		return
	}

	writeJSON(w, toCustomerResponse(*customer), http.StatusCreated)
}

// ── GET /v1/customers ───────────────────────────────────────────────────────
func (h *CustomerHandler) List(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	customers, err := h.customerService.List(r.Context(), userID)
	if err != nil {
		writeError(w, "could not load customers", http.StatusInternalServerError)
		return
	}

	resp := make([]customerResponse, 0, len(customers))
	for _, c := range customers {
		resp = append(resp, toCustomerResponse(c))
	}

	writeJSON(w, listCustomersResponse{Customers: resp}, http.StatusOK)
}

// ── PUT /v1/customers/{id} ──────────────────────────────────────────────────
func (h *CustomerHandler) Update(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, "invalid customer id", http.StatusBadRequest)
		return
	}

	var req updateCustomerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}
	if req.Name == "" || req.Phone == "" {
		writeError(w, "name and phone are required", http.StatusBadRequest)
		return
	}

	customer, err := h.customerService.Update(r.Context(), id, userID, service.UpdateCustomerParams{
		Name:  req.Name,
		Phone: req.Phone,
		Email: req.Email,
		Notes: req.Notes,
	})
	if err != nil {
		if errors.Is(err, repository.ErrCustomerNotFound) {
			writeError(w, "customer not found", http.StatusNotFound)
		} else if errors.Is(err, repository.ErrDuplicatePhone) {
			writeError(w, "a customer with this phone already exists", http.StatusBadRequest)
		} else {
			writeError(w, "could not update customer", http.StatusInternalServerError)
		}
		return
	}

	writeJSON(w, toCustomerResponse(*customer), http.StatusOK)
}

// ── DELETE /v1/customers/{id} ───────────────────────────────────────────────
func (h *CustomerHandler) Delete(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	id, err := uuid.Parse(chi.URLParam(r, "id"))
	if err != nil {
		writeError(w, "invalid customer id", http.StatusBadRequest)
		return
	}

	err = h.customerService.Delete(r.Context(), id, userID)
	if err != nil {
		if errors.Is(err, repository.ErrCustomerNotFound) {
			writeError(w, "customer not found", http.StatusNotFound)
		} else if errors.Is(err, service.ErrCustomerHasDues) {
			writeError(w, "customer has outstanding dues and cannot be deleted", http.StatusConflict)
		} else {
			writeError(w, "could not delete customer", http.StatusInternalServerError)
		}
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// ── Mapping helper ──────────────────────────────────────────────────────────
func toCustomerResponse(c repository.Customer) customerResponse {
	return customerResponse{
		ID:      c.ID,
		Name:    c.Name,
		Phone:   c.Phone,
		Email:   c.Email,
		Notes:   c.Notes,
		HasDues: c.HasDues,
	}
}
