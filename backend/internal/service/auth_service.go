package service

import (
	"context"
	"errors"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/sanu1001/KhataDost/backend/internal/repository"
	"github.com/sanu1001/KhataDost/backend/internal/sqlcgen"
	"golang.org/x/crypto/bcrypt"
)

var (
	ErrInvalidAccessCode = errors.New("invalid access code")
	ErrEmailAlreadyInUse = errors.New("email already in use")
	ErrInvalidCredentials = errors.New("invalid credentials")
)

type AuthService interface {
	Register(ctx context.Context, params RegisterParams) (AuthResult , error)
	Login(ctx context.Context, params LoginParams) (AuthResult , error)
}

type RegisterParams struct {
	Name string
	ShopName string
	Phone string
	Email string
	Password string
	AccessCode string
}

type LoginParams struct {
	Email string
	Password string
}

type AuthResult struct {
	Token string
	User sqlcgen.User
}

type authService struct {
	repo repository.AuthRepository
}

func NewAuthService(repo repository.AuthRepository) AuthService {
	return &authService{repo: repo}
}

func (s *authService) Register(ctx context.Context, params RegisterParams) (AuthResult , error) {
	if params.AccessCode != os.Getenv("ACCESS_CODE") {
		return AuthResult{}, ErrInvalidAccessCode
	}
	hashed, err := bcrypt.GenerateFromPassword([]byte(params.Password), bcrypt.DefaultCost)
	if err != nil {
		return AuthResult{}, errors.New("could not hash password")
	}

	user , err := s.repo.CreateUser(ctx , sqlcgen.CreateUserParams{
		Name: params.Name,
		ShopName: params.ShopName,
		Phone: params.Phone,
		Email: params.Email,
		Password: string(hashed),
	})
	if err != nil {
		return AuthResult{}, ErrEmailAlreadyInUse
	}

	token, err := generateJWT(user.ID)
	if err != nil {
		return AuthResult{}, err
	}
    
	return AuthResult{Token: token, User: user}, nil
}

func (s *authService) Login(ctx context.Context, params LoginParams) (AuthResult , error) {
	user, err := s.repo.GetUserByEmail(ctx, params.Email)
	if err != nil {
		return AuthResult{}, ErrInvalidCredentials
	}

	err =  bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(params.Password))
	if err != nil {
		return AuthResult{} , ErrInvalidCredentials
	}

	token , err := generateJWT(user.ID)
	if err != nil {
		return AuthResult{} , err
	}
	return AuthResult{Token: token, User: user}, nil
}

func generateJWT(userID uuid.UUID) (string, error) {
	secret := os.Getenv("JWT_SECRET")

	claims := jwt.MapClaims{
		"sub": userID.String(),
		"exp": time.Now().Add(30 * 24 *time.Hour).Unix(),
		"iat": time.Now().Unix(),
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}