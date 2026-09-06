package database

type userRow struct {
	Email    string `gorm:"primaryKey;size:320"`
	Username string `gorm:"size:32;not null;default:''"`
	Name     string `gorm:"size:60;not null;default:''"`
	Gender   string `gorm:"size:16;not null;default:''"`
	Bio      string `gorm:"type:text;not null;default:''"`
	Avatar   string `gorm:"size:64;not null;default:''"`
}

func (userRow) TableName() string { return "users" }

func (r userRow) toUser() User {
	return User{Username: r.Username, Email: r.Email, Name: r.Name, Gender: r.Gender, Bio: r.Bio, Avatar: r.Avatar}
}

type eventRow struct {
	ID              string  `gorm:"primaryKey;size:32"`
	CreatorEmail    string  `gorm:"size:320;not null;index"`
	Title           string  `gorm:"size:200;not null;default:''"`
	Category        string  `gorm:"size:64;not null;default:''"`
	Location        string  `gorm:"size:200;not null;default:''"`
	Latitude        float64 `gorm:"not null;default:0"`
	Longitude       float64 `gorm:"not null;default:0"`
	Time            string  `gorm:"size:64;not null;default:''"`
	MaxParticipants int     `gorm:"not null;default:0"`

	CreatedAt string `gorm:"size:40;not null;index"`
}

func (eventRow) TableName() string { return "events" }

func (r eventRow) toEvent() Event {
	return Event{
		ID:              r.ID,
		CreatorEmail:    r.CreatorEmail,
		Title:           r.Title,
		Category:        r.Category,
		Location:        r.Location,
		Latitude:        r.Latitude,
		Longitude:       r.Longitude,
		Time:            r.Time,
		MaxParticipants: r.MaxParticipants,
		CreatedAt:       r.CreatedAt,
	}
}

func eventToRow(e Event) eventRow {
	return eventRow{
		ID:              e.ID,
		CreatorEmail:    e.CreatorEmail,
		Title:           e.Title,
		Category:        e.Category,
		Location:        e.Location,
		Latitude:        e.Latitude,
		Longitude:       e.Longitude,
		Time:            e.Time,
		MaxParticipants: e.MaxParticipants,
		CreatedAt:       e.CreatedAt,
	}
}

type requestRow struct {
	ID             string `gorm:"primaryKey;size:32"`
	EventID        string `gorm:"size:32;not null;index"`
	ApplicantEmail string `gorm:"size:320;not null;index"`
	Status         string `gorm:"size:16;not null;default:'pending'"`
	CreatedAt      string `gorm:"size:40;not null;default:''"`
}

func (requestRow) TableName() string { return "requests" }

func (r requestRow) toRequest() JoinRequest {
	return JoinRequest{
		ID:             r.ID,
		EventID:        r.EventID,
		ApplicantEmail: r.ApplicantEmail,
		Status:         r.Status,
		CreatedAt:      r.CreatedAt,
	}
}

type messageRow struct {
	ID           string `gorm:"primaryKey;size:32"`
	RoomID       string `gorm:"size:32;not null;index"`
	SenderEmail  string `gorm:"size:320;not null;default:''"`
	SenderHandle string `gorm:"size:64;not null;default:''"`
	Message      string `gorm:"type:text;not null;default:''"`
	Type         string `gorm:"size:16;not null;default:'chat'"`
	TimeStamp    string `gorm:"size:40;not null;default:''"`
	ReplyToID    string `gorm:"size:32;not null;default:''"`
	ReplyToText  string `gorm:"size:200;not null;default:''"`

	Seq int64 `gorm:"autoIncrement;index"`
}

func (messageRow) TableName() string { return "messages" }

func (r messageRow) toChatMessage() ChatMessage {
	return ChatMessage{
		ID:           r.ID,
		RoomID:       r.RoomID,
		SenderEmail:  r.SenderEmail,
		SenderHandle: r.SenderHandle,
		Message:      r.Message,
		Type:         r.Type,
		TimeStamp:    r.TimeStamp,
		ReplyToID:    r.ReplyToID,
		ReplyToText:  r.ReplyToText,
	}
}
