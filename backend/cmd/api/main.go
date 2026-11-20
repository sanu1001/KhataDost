package main

import (
	"context"
	"errors"
	"fmt"
	"io/fs"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"github.com/joho/godotenv"
	"github.com/sanu1001/KhataDost/backend/internal/db"
	"github.com/sanu1001/KhataDost/backend/internal/gemini"
	"github.com/sanu1001/KhataDost/backend/internal/handler"
	"github.com/sanu1001/KhataDost/backend/internal/middleware"
	"github.com/sanu1001/KhataDost/backend/internal/repository"
	"github.com/sanu1001/KhataDost/backend/internal/service"
)

func main() {
	// Settings come from environment variables. A .env file is optional:
	// `go run` on a laptop reads backend/.env, while Docker passes the same
	// variables in through docker-compose and has no .env inside the image.
	// A .env that exists but can't be read is still a fatal error.
	if err := godotenv.Load(); err != nil {
		if !errors.Is(err, fs.ErrNotExist) {
			log.Fatalf("could not read .env: %v", err)
		}
		log.Println("no .env file, reading settings from the environment only")
	}

	// Fail fast on settings the server can't run without, instead of
	// failing later on the first request (an empty JWT_SECRET would even
	// sign tokens with an empty key).
	mustEnv("DATABASE_URL")
	mustEnv("JWT_SECRET")
	if os.Getenv("ACCESS_CODE") == "" {
		log.Println("WARNING: ACCESS_CODE not set: nobody can register until it is")
	}
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
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

	// me chain (read-only profile for Settings; reads the frozen users table)
	meRepo := repository.NewMeRepository(database)
	meService := service.NewMeService(meRepo)
	meHandler := handler.NewMeHandler(meService)

	// customer chain
	customerRepo := repository.NewCustomerRepository(database)
	customerService := service.NewCustomerService(customerRepo)
	customerHandler := handler.NewCustomerHandler(customerService)

	// inventory chain
	inventoryRepo := repository.NewInventoryRepository(database)
	inventoryService := service.NewInventoryService(inventoryRepo)
	inventoryHandler := handler.NewInventoryHandler(inventoryService)

	// billing chain (reuses the frozen customer repo read-only: ownership
	// guard + customer_name snapshot at settle time)
	billingRepo := repository.NewBillingRepository(database)
	billingService := service.NewBillingService(billingRepo, customerRepo)
	billingHandler := handler.NewBillingHandler(billingService)

	// khata chain (reuses the frozen customer repo read-only: ownership guard)
	khataRepo := repository.NewKhataRepository(database)
	khataService := service.NewKhataService(khataRepo, customerRepo)
	khataHandler := handler.NewKhataHandler(khataService)

	// scan chain (reuses the frozen inventory repo read-only: the match pool).
	// The Gemini key lives in the server environment (.env or docker-compose)
	// ONLY — it never ships in the Flutter app.
	geminiKey := os.Getenv("GEMINI_API_KEY")
	if geminiKey == "" {
		log.Println("WARNING: GEMINI_API_KEY not set: /v1/scan will return 502 until it is set")
	}
	geminiClient := gemini.NewClient(geminiKey)
	scanService := service.NewScanService(geminiClient, inventoryRepo)
	scanHandler := handler.NewScanHandler(scanService)

	r := chi.NewRouter()
	// One log line per request (method, path, status, size, duration) and a
	// 500 instead of a dropped connection if a handler ever panics.
	r.Use(chimw.Logger)
	r.Use(chimw.Recoverer)

	r.Get("/health", func(w http.ResponseWriter, req *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprintln(w, "KhataDost backend is running")
	})

	// public routes
	r.Post("/v1/register", authHandler.Register)
	r.Post("/v1/login", authHandler.Login)

	// protected routes
	r.Group(func(r chi.Router) {
		r.Use(middleware.RequireAuth)
		r.Get("/v1/dashboard/summary", dashboardHandler.GetSummary)

		r.Get("/v1/me", meHandler.Get)

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

		r.Post("/v1/bills", billingHandler.Create)
		r.Get("/v1/bills", billingHandler.List)
		r.Get("/v1/bills/{id}", billingHandler.GetByID)

		r.Get("/v1/khata/{customerId}", khataHandler.GetKhata)
		r.Post("/v1/khata/{customerId}/payment", khataHandler.RecordPayment)

		r.Post("/v1/scan", scanHandler.Scan)
	})

	// Timeouts so a slow or stuck client can't hold a connection forever.
	// Read and write allow 60 s: a scan photo can be ~10 MB from a phone on a
	// slow network, and /v1/scan waits up to 30 s for Gemini.
	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           r,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       60 * time.Second,
		WriteTimeout:      60 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	// Graceful shutdown: on Ctrl+C or `docker compose down` (SIGTERM), stop
	// accepting new requests and give the ones in flight 10 s to finish.
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	go func() {
		log.Printf("Server starting on port %s...", port)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server error: %v", err)
		}
	}()

	<-ctx.Done()
	log.Println("shutting down...")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Printf("shutdown did not finish cleanly: %v", err)
	}
}

// mustEnv stops the server at startup if a required setting is missing.
func mustEnv(key string) {
	if os.Getenv(key) == "" {
		log.Fatalf("%s is not set (put it in backend/.env, or in the environment)", key)
	}
}
