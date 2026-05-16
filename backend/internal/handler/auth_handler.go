package handler

import (
	"encoding/json"
	"errors"
	"net/http"

	"github.com/sanu1001/KhataDost/backend/internal/service"
)

type AuthHandler struct {
	authService service.AuthService
}

func NewAuthHandler(authService service.AuthService) *AuthHandler {
	return &AuthHandler{authService: authService}
}

type registerRequest struct {
	Name string `json:"name"`
	ShopName string `json:"shop_name"`
	Phone string `json:"phone"`
	Email string `json:"email"`
	Password string `json:"password"`
	AccessCode string `json:"access_code"`

}

type loginRequest struct {
	Email string `json:"email"`
	Password string `json:"password"`
}

type userResponse struct {
	ID string `json:"id"`
	Name string `json:"name"`
	ShopName string `json:"shop_name"`
	Email string `json:"email"`
	Phone string `json:"phone"`
}

type authResponse struct {
	Token string `json:"token"`
	User userResponse `json:"user"`
}

func (h *AuthHandler) Register(w http.ResponseWriter, r *http.Request) {
	var req registerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.Name == "" || req.ShopName == "" || req.Phone == "" || req.Email == "" || req.Password == "" || req.AccessCode == "" {
		writeError(w, "All fields are required", http.StatusBadRequest)
		return
	}

	result , err := h.authService.Register(r.Context(), service.RegisterParams{
		Name: req.Name,
		ShopName: req.ShopName,
		Phone: req.Phone,
		Email: req.Email,
		Password: req.Password,
		AccessCode: req.AccessCode,
	})
	if err != nil {
		if errors.Is(err, service.ErrInvalidAccessCode) {
    		writeError(w, "invalid access code", http.StatusForbidden)
		} else if errors.Is(err, service.ErrEmailAlreadyInUse) {
    		writeError(w, "email already in use", http.StatusConflict)
		} else {
    		writeError(w, "something went wrong", http.StatusInternalServerError)
		}
		return
	}


	writeJSON(w, authResponse{
		Token: result.Token,
		User: userResponse{
			ID: result.User.ID.String(),
			Name: result.User.Name,
			ShopName: result.User.ShopName,
			Email: result.User.Email,
			Phone: result.User.Phone,
		},
	}, http.StatusCreated)

}


func (h *AuthHandler) Login(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, "invalid request body", http.StatusBadRequest)
		return
	}

	if req.Email == "" || req.Password == "" {
		writeError(w, "email and password are required", http.StatusBadRequest)
		return
	}

	result , err := h.authService.Login(r.Context(), service.LoginParams{
		Email: req.Email,
		Password: req.Password,
	})
	if err != nil {
		writeError(w, "invalid email or password", http.StatusUnauthorized)
		return
	}

	writeJSON(w, authResponse{
		Token: result.Token,
		User: userResponse{	
			ID: result.User.ID.String(),
			Name: result.User.Name,
			ShopName: result.User.ShopName,	
			Email: result.User.Email,
			Phone: result.User.Phone,
		},
	}, http.StatusOK)
}
func writeJSON(w http.ResponseWriter, data any, status int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func writeError(w http.ResponseWriter, message string, status int) {
	writeJSON(w, map[string]string{"error": message}, status)
}

