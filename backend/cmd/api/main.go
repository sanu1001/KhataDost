package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/go-chi/chi/v5"
	"github.com/joho/godotenv"
	"github.com/sanu1001/KhataDost/backend/internal/db"
)

func main() {

	err := godotenv.Load()
	if err != nil {
		log.Fatal("Error loading .env file")
	}

	database := db.Connect(os.Getenv("DATABASE_URL"))
	defer database.Close()

	r := chi.NewRouter()

	r.Get("/health", func(w http.ResponseWriter, req *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintln(w, "KhataDost backend is runningg!")
	})

	port := os.Getenv("PORT")

	log.Printf("Server starting on port %s...", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}
