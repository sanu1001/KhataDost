package db

import (
	"log"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/jmoiron/sqlx"
)

func Connect(databaseURL string) *sqlx.DB {
	db, err := sqlx.Connect("pgx", databaseURL)
	if err != nil {
		log.Fatalf("Could not connect to database: %v", err)
	}
	log.Println("Database connection established")
	return db
}
