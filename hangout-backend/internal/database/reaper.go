package database

import (
	"time"
)

func StartReaper(eventStore *EventStore, requestStore *RequestStore, chatStore *ChatStore, interval time.Duration) {
	ticker := time.NewTicker(interval)
	go func() {
		for range ticker.C {
			expiredIDs := eventStore.CleanupExpired()
			if len(expiredIDs) > 0 {
				requestStore.CleanupEventRequests(expiredIDs)
				chatStore.CleanupRooms(expiredIDs)
			}
		}
	}()
}
