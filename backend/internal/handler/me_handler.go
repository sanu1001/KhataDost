package handler

import (
	"errors"
	"net/http"

	"github.com/sanu1001/KhataDost/backend/internal/middleware"
	"github.com/sanu1001/KhataDost/backend/internal/service"
)

type meResponse struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	ShopName string `json:"shop_name"`
	Email    string `json:"email"`
	Phone    string `json:"phone"`
}

type MeHandler struct {
	meService service.MeService
}

func NewMeHandler(meService service.MeService) *MeHandler {
	return &MeHandler{meService: meService}
}

// Get handles GET /v1/me — returns the authenticated shopkeeper's profile.
func (h *MeHandler) Get(w http.ResponseWriter, r *http.Request) {
	userID, ok := middleware.UserIDFromContext(r.Context())
	if !ok {
		writeError(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	profile, err := h.meService.GetProfile(r.Context(), userID)
	if err != nil {
		if errors.Is(err, service.ErrUserNotFound) {
			writeError(w, "user not found", http.StatusNotFound)
			return
		}
		writeError(w, "could not load profile", http.StatusInternalServerError)
		return
	}

	writeJSON(w, meResponse{
		ID:       profile.ID,
		Name:     profile.Name,
		ShopName: profile.ShopName,
		Email:    profile.Email,
		Phone:    profile.Phone,
	}, http.StatusOK)
}
