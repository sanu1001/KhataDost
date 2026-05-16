package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/go-chi/chi/v5"
	"github.com/joho/godotenv"
	"github.com/sanu1001/KhataDost/backend/internal/db"
	"github.com/sanu1001/KhataDost/backend/internal/handler"
	"github.com/sanu1001/KhataDost/backend/internal/repository"
	"github.com/sanu1001/KhataDost/backend/internal/service"
)

func main() {

	err := godotenv.Load()
	if err != nil {
		log.Fatal("Error loading .env file")
	}

	database := db.Connect(os.Getenv("DATABASE_URL"))
	defer database.Close()

	authRepo := repository.NewAuthRepository(database)
	authService := service.NewAuthService(authRepo)
	authHandler := handler.NewAuthHandler(authService)

	r := chi.NewRouter()

	r.Get("/health", func(w http.ResponseWriter, req *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintln(w, "KhataDost backend is runningg!")
	})

	r.Post("/v1/register", authHandler.Register)
	r.Post("/v1/login", authHandler.Login)


	port := os.Getenv("PORT")
	log.Printf("Server starting on port %s...", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}
