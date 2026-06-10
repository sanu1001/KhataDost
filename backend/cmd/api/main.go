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
	"github.com/sanu1001/KhataDost/backend/internal/middleware"
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

	// auth chain
	authRepo := repository.NewAuthRepository(database)
	authService := service.NewAuthService(authRepo)
	authHandler := handler.NewAuthHandler(authService)

	// dashboard chain
	dashboardRepo := repository.NewDashboardRepository(database)
	dashboardService := service.NewDashboardService(dashboardRepo)
	dashboardHandler := handler.NewDashboardHandler(dashboardService)

	// customer chain
	customerRepo := repository.NewCustomerRepository(database)
	customerService := service.NewCustomerService(customerRepo)
	customerHandler := handler.NewCustomerHandler(customerService)

	// inventory chain
	inventoryRepo := repository.NewInventoryRepository(database)
	inventoryService := service.NewInventoryService(inventoryRepo)
	inventoryHandler := handler.NewInventoryHandler(inventoryService)

	r := chi.NewRouter()

	r.Get("/health", func(w http.ResponseWriter, req *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintln(w, "KhataDost backend is runningg!")
	})

	// public routes
	r.Post("/v1/register", authHandler.Register)
	r.Post("/v1/login", authHandler.Login)

	// protected routes
	r.Group(func(r chi.Router) {
		r.Use(middleware.RequireAuth)
		r.Get("/v1/dashboard/summary", dashboardHandler.GetSummary)

		r.Post("/v1/customers", customerHandler.Create)
		r.Get("/v1/customers", customerHandler.List)
		r.Put("/v1/customers/{id}", customerHandler.Update)
		r.Delete("/v1/customers/{id}", customerHandler.Delete)

		r.Post("/v1/inventory", inventoryHandler.Create)
		r.Get("/v1/inventory", inventoryHandler.List)
		r.Put("/v1/inventory/{id}", inventoryHandler.UpdateItem)
		r.Delete("/v1/inventory/{id}", inventoryHandler.DeleteItem)
		r.Post("/v1/inventory/{id}/variants", inventoryHandler.AddVariant)
		r.Put("/v1/inventory/{id}/variants/{vid}", inventoryHandler.UpdateVariant)
		r.Delete("/v1/inventory/{id}/variants/{vid}", inventoryHandler.DeleteVariant)
	})

	port := os.Getenv("PORT")
	log.Printf("Server starting on port %s...", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}
