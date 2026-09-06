package database

import (
	"time"
)

type ChatMessage struct {
	ID           string `json:"id"`
	RoomID       string `json:"room_id"`
	SenderEmail  string `json:"-"`
	SenderHandle string `json:"sender_handle"`
	Message      string `json:"message"`
	Type         string `json:"type"`
	TimeStamp    string `json:"time_stamp"`
	ReplyToID    string `json:"reply_to_id,omitempty"`
	ReplyToText  string `json:"reply_to_text,omitempty"`
}

const maxMessagesPerRoom = 100

type ChatStore struct{}

func NewChatStore() *ChatStore {
	return &ChatStore{}
}

func (s *ChatStore) SaveMessages(msg ChatMessage) {
	if msg.TimeStamp == "" {
		msg.TimeStamp = time.Now().Format(time.RFC3339)
	}

	row := messageRow{
		ID:           msg.ID,
		RoomID:       msg.RoomID,
		SenderEmail:  msg.SenderEmail,
		SenderHandle: msg.SenderHandle,
		Message:      msg.Message,
		Type:         msg.Type,
		TimeStamp:    msg.TimeStamp,
		ReplyToID:    msg.ReplyToID,
		ReplyToText:  msg.ReplyToText,
	}
	if err := DB.Create(&row).Error; err != nil {
		return
	}

	DB.Exec(
		`DELETE FROM messages
		 WHERE room_id = ? AND seq NOT IN (
		   SELECT seq FROM messages WHERE room_id = ? ORDER BY seq DESC LIMIT ?
		 )`,
		msg.RoomID, msg.RoomID, maxMessagesPerRoom,
	)
}

func (s *ChatStore) GetRoomHistory(roomID string) []ChatMessage {
	var rows []messageRow

	if err := DB.Where("room_id = ?", roomID).
		Order("seq DESC").Limit(maxMessagesPerRoom).Find(&rows).Error; err != nil {
		return []ChatMessage{}
	}
	out := make([]ChatMessage, 0, len(rows))
	for i := len(rows) - 1; i >= 0; i-- {
		out = append(out, rows[i].toChatMessage())
	}
	return out
}

func (s *ChatStore) DeleteRoomHistory(roomID string) {
	DB.Delete(&messageRow{}, "room_id = ?", roomID)
}

func (s *ChatStore) CleanupRooms(roomIDs []string) {
	if len(roomIDs) == 0 {
		return
	}
	DB.Delete(&messageRow{}, "room_id IN ?", roomIDs)
}
