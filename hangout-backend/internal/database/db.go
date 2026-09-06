package database

import (
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var gormLogger = logger.Default.LogMode(logger.Error)

var DB *gorm.DB

func Connect() error {
	dsn := strings.TrimSpace(os.Getenv("DATABASE_URL"))
	if dsn == "" {
		return fmt.Errorf("DATABASE_URL is not set")
	}

	db, err := gorm.Open(postgres.New(postgres.Config{
		DSN:                  dsn,
		PreferSimpleProtocol: true,
	}), &gorm.Config{
		Logger: gormLogger,
	})
	if err != nil {
		return fmt.Errorf("open postgres: %w", err)
	}

	sqlDB, err := db.DB()
	if err != nil {
		return fmt.Errorf("get sql.DB: %w", err)
	}

	sqlDB.SetMaxOpenConns(10)
	sqlDB.SetMaxIdleConns(5)
	sqlDB.SetConnMaxLifetime(30 * time.Minute)
	sqlDB.SetConnMaxIdleTime(5 * time.Minute)

	if err := sqlDB.Ping(); err != nil {
		return fmt.Errorf("ping postgres: %w", err)
	}

	DB = db

	if err := migrate(); err != nil {
		return fmt.Errorf("migrate: %w", err)
	}

	log.Println("[db] connected to Postgres and migrated schema")
	return nil
}

func migrate() error {
	if err := DB.AutoMigrate(
		&userRow{},
		&eventRow{},
		&requestRow{},
		&messageRow{},
	); err != nil {
		return err
	}

	if err := DB.Exec(
		`CREATE UNIQUE INDEX IF NOT EXISTS idx_users_username_lower
		 ON users (lower(username)) WHERE username <> ''`,
	).Error; err != nil {
		return err
	}

	if err := DB.Exec(
		`CREATE INDEX IF NOT EXISTS idx_requests_event ON requests (event_id)`,
	).Error; err != nil {
		return err
	}

	if err := DB.Exec(
		`CREATE INDEX IF NOT EXISTS idx_messages_room_seq ON messages (room_id, seq)`,
	).Error; err != nil {
		return err
	}
	return nil
}
