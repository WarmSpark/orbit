package database

import (
	"errors"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type JoinRequest struct {
	ID             string `json:"id"`
	EventID        string `json:"event_id"`
	ApplicantEmail string `json:"applicant_email"`
	Status         string `json:"status"`
	CreatedAt      string `json:"created_at"`
}

type EventMember struct {
	Username string `json:"username"`
	Name     string `json:"name"`
	Gender   string `json:"gender"`
	Avatar   string `json:"avatar"`
	Bio      string `json:"bio"`
	IsHost   bool   `json:"is_host"`

	Email string `json:"email,omitempty"`
}

type RequestStore struct{}

func NewRequestStore() *RequestStore {
	return &RequestStore{}
}

func (s *RequestStore) CreateRequest(req JoinRequest) {
	row := requestRow{
		ID:             req.ID,
		EventID:        req.EventID,
		ApplicantEmail: req.ApplicantEmail,
		Status:         req.Status,
		CreatedAt:      req.CreatedAt,
	}
	DB.Create(&row)
}

func (s *RequestStore) GetRequestsForEvent(eventID string) []JoinRequest {
	var rows []requestRow
	if err := DB.Where("event_id = ? AND status = ?", eventID, "pending").Find(&rows).Error; err != nil {
		return []JoinRequest{}
	}
	out := make([]JoinRequest, 0, len(rows))
	for _, r := range rows {
		out = append(out, r.toRequest())
	}
	return out
}

func (s *RequestStore) GetApprovedCount(eventID string) int {
	var count int64
	DB.Model(&requestRow{}).Where("event_id = ? AND status = ?", eventID, "approved").Count(&count)
	return int(count)
}

func (s *RequestStore) GetApprovedEmails(eventID string) []string {
	var emails []string
	DB.Model(&requestRow{}).
		Where("event_id = ? AND status = ?", eventID, "approved").
		Pluck("applicant_email", &emails)
	if emails == nil {
		return []string{}
	}
	return emails
}

func (s *RequestStore) IsApprovedMember(eventID string, userEmail string) bool {
	var count int64
	DB.Model(&requestRow{}).
		Where("event_id = ? AND applicant_email = ? AND status = ?", eventID, userEmail, "approved").
		Count(&count)
	return count > 0
}

func (s *RequestStore) UpdateRequestStatus(requestID string, status string) error {
	res := DB.Model(&requestRow{}).Where("id = ?", requestID).Update("status", status)
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return errors.New("request not found")
	}
	return nil
}

func (s *RequestStore) ApproveRequest(requestID string, maxParticipants int) error {
	return DB.Transaction(func(tx *gorm.DB) error {
		var req requestRow
		if err := tx.Where("id = ?", requestID).First(&req).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return errors.New("request not found")
			}
			return err
		}
		if req.Status == "approved" {
			return nil
		}

		var evt eventRow
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("id = ?", req.EventID).First(&evt).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				return errors.New("hangout not found or expired")
			}
			return err
		}

		var approved int64
		if err := tx.Model(&requestRow{}).
			Where("event_id = ? AND status = ?", req.EventID, "approved").
			Count(&approved).Error; err != nil {
			return err
		}
		if int(approved)+1 >= maxParticipants {
			return errors.New("hangout has reached maximum capacity")
		}

		return tx.Model(&requestRow{}).Where("id = ?", requestID).
			Update("status", "approved").Error
	})
}

func (s *RequestStore) LeaveEvent(eventID string, userEmail string) error {
	res := DB.Model(&requestRow{}).
		Where("event_id = ? AND applicant_email = ? AND status = ?", eventID, userEmail, "approved").
		Update("status", "left")
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return errors.New("not an active participant of this hangout")
	}
	return nil
}

func (s *RequestStore) KickParticipant(eventID string, participantEmail string) error {
	res := DB.Model(&requestRow{}).
		Where("event_id = ? AND applicant_email = ? AND status = ?", eventID, participantEmail, "approved").
		Update("status", "kicked")
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return errors.New("participant not found in this hangout")
	}
	return nil
}

func (s *RequestStore) HasUserRequested(eventID string, applicantEmail string) bool {
	var count int64
	DB.Model(&requestRow{}).
		Where("event_id = ? AND applicant_email = ? AND status IN ?",
			eventID, applicantEmail, []string{"pending", "approved", "kicked"}).
		Count(&count)
	return count > 0
}

func (s *RequestStore) GetRequestsByApplicant(applicantEmail string) []JoinRequest {
	var rows []requestRow
	if err := DB.Where("applicant_email = ?", applicantEmail).Find(&rows).Error; err != nil {
		return []JoinRequest{}
	}
	out := make([]JoinRequest, 0, len(rows))
	for _, r := range rows {
		out = append(out, r.toRequest())
	}
	return out
}

func (s *RequestStore) GetRequest(requestID string) (JoinRequest, bool) {
	var row requestRow
	if err := DB.Where("id = ?", requestID).First(&row).Error; err != nil {
		return JoinRequest{}, false
	}
	return row.toRequest(), true
}

func (s *RequestStore) CleanupEventRequests(eventIDs []string) {
	if len(eventIDs) == 0 {
		return
	}
	DB.Delete(&requestRow{}, "event_id IN ?", eventIDs)
}
