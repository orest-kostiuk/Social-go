package main

import (
	"log"

	"github.com/joho/godotenv"
	"github.com/orest-kostiuk/social/internal/db"
	"github.com/orest-kostiuk/social/internal/env"
	"github.com/orest-kostiuk/social/internal/store"
)

func main() {
	err := godotenv.Load()
	if err != nil {
		log.Fatal("Error loading .env file")
	}

	cfg := config{
		addr: env.GetString("ADDR", ":8080"),
		db: dbConfig{
			addr:          "postgres://social_user:social_password@localhost:5432/social_db?sslmode=disable",
			maxOpensConns: env.GetInt("DB_MAX_OPEN_CONNS", 25),
			maxIdleConns:  env.GetInt("DB_MAX_IDLE_CONNS", 25),
			maxIdleTime:   env.GetString("DB_MAX_IDLE_TIME", "5m"),
		},
	}

	db, err := db.New(
		cfg.db.addr,
		cfg.db.maxOpensConns,
		cfg.db.maxIdleConns,
		cfg.db.maxIdleTime,
	)
	if err != nil {
		log.Panicf("Error connecting to the database: %v", err)
	}

	defer db.Close()
	log.Println("Connected to the database successfully")

	store := store.NewStorage(db)

	app := &application{
		config: cfg,
		store:  store,
	}

	mux := app.mount()
	log.Fatal(app.run(mux))

}
