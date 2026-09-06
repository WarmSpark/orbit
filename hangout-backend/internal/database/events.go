package database

import (
	"errors"
	"time"

	"gorm.io/gorm"
)

type Event struct {
	ID              string  `json:"id"`
	CreatorEmail    string  `json:"-"`
	Title           string  `json:"title"`
	Category        string  `json:"category"`
	Location        string  `json:"location"`
	Latitude        float64 `json:"latitude"`
	Longitude       float64 `json:"longitude"`
	Time            string  `json:"time"`
	MaxParticipants int     `json:"max_participants"`
	CreatedAt       string  `json:"created_at"`
}

type EventStore struct{}

func NewEventStore() *EventStore {
	return &EventStore{}
}

func within24h(createdAt string, now time.Time) bool {
	t, err := time.Parse(time.RFC3339, createdAt)
	if err != nil {

		return true
	}
	return now.Sub(t) <= 24*time.Hour
}

func (s *EventStore) SaveEvent(e Event) error {
	row := eventToRow(e)
	return DB.Create(&row).Error
}

func (s *EventStore) GetAllEvents() []Event {
	var rows []eventRow

	cutoff := time.Now().Add(-24 * time.Hour).Format(time.RFC3339)
	if err := DB.Where("created_at > ?", cutoff).Find(&rows).Error; err != nil {
		return []Event{}
	}
	now := time.Now()
	list := make([]Event, 0, len(rows))
	for _, r := range rows {
		if within24h(r.CreatedAt, now) {
			list = append(list, r.toEvent())
		}
	}
	return list
}

func (s *EventStore) GetEvent(eventID string) (Event, bool) {
	var row eventRow
	if err := DB.Where("id = ?", eventID).First(&row).Error; err != nil {
		return Event{}, false
	}
	return row.toEvent(), true
}

func (s *EventStore) HasActiveEvent(creatorEmail string) bool {
	var rows []eventRow
	if err := DB.Where("creator_email = ?", creatorEmail).Find(&rows).Error; err != nil {
		return false
	}
	now := time.Now()
	for _, r := range rows {
		if within24h(r.CreatedAt, now) {
			return true
		}
	}
	return false
}

func (s *EventStore) DeleteEvent(eventId, creatorEmail string) error {
	var row eventRow
	err := DB.Where("id = ?", eventId).First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return errors.New("event not found")
	}
	if err != nil {
		return err
	}
	if row.CreatorEmail != creatorEmail {
		return errors.New("unauthorized")
	}
	return DB.Delete(&eventRow{}, "id = ?", eventId).Error
}

func (s *EventStore) CleanupExpired() []string {
	var rows []eventRow
	if err := DB.Find(&rows).Error; err != nil {
		return nil
	}
	now := time.Now()
	var expiredIDs []string
	for _, r := range rows {
		if !within24h(r.CreatedAt, now) {
			expiredIDs = append(expiredIDs, r.ID)
		}
	}
	if len(expiredIDs) > 0 {
		DB.Delete(&eventRow{}, "id IN ?", expiredIDs)
	}
	return expiredIDs
}
