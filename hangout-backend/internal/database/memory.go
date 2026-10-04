package database

import (
	"errors"
	"fmt"
	"regexp"
	"strings"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type User struct {
	Username string `json:"username"`
	Email    string `json:"email"`
	Name     string `json:"name"`
	Gender   string `json:"gender"`
	Bio      string `json:"bio"`
	Avatar   string `json:"avatar"`
}

type UserStore struct{}

func NewUserStore() *UserStore {
	return &UserStore{}
}

func IsValidUsername(username string) bool {
	match, _ := regexp.MatchString(`^[a-zA-Z0-9_.]{3,20}$`, username)
	return match
}

func (s *UserStore) IsUsernameTaken(username string, excludeEmail string) bool {
	clean := strings.ToLower(strings.TrimSpace(username))
	if clean == "" {
		return false
	}
	var row userRow
	err := DB.Where("lower(username) = ?", clean).First(&row).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return false
	}
	if err != nil {
		return false
	}
	return row.Email != excludeEmail
}

func (s *UserStore) SaveUser(u User) error {
	var existing userRow
	err := DB.Where("email = ?", u.Email).First(&existing).Error
	if err == nil {
		return errors.New("user already exists")
	}
	if !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}

	candidate := strings.TrimSpace(u.Username)
	if candidate == "" || !IsValidUsername(candidate) || s.IsUsernameTaken(candidate, u.Email) {
		candidate = fmt.Sprintf("user_%d", time.Now().UnixNano()%1000000)
	}

	row := userRow{
		Email:    u.Email,
		Username: candidate,
		Name:     u.Name,
		Gender:   u.Gender,
		Bio:      u.Bio,
		Avatar:   u.Avatar,
	}
	return DB.Create(&row).Error
}

func (s *UserStore) GetUser(email string) (User, bool) {
	var row userRow
	err := DB.Where("email = ?", email).First(&row).Error
	if err != nil {
		return User{}, false
	}
	return row.toUser(), true
}

func (s *UserStore) DeleteAccount(email string) ([]string, error) {
	var roomIDs []string
	err := DB.Transaction(func(tx *gorm.DB) error {
		var ids []string
		if err := tx.Model(&eventRow{}).Where("creator_email = ?", email).
			Pluck("id", &ids).Error; err != nil {
			return err
		}
		roomIDs = ids

		if len(ids) > 0 {
			if err := tx.Delete(&eventRow{}, "id IN ?", ids).Error; err != nil {
				return err
			}
			if err := tx.Delete(&requestRow{}, "event_id IN ?", ids).Error; err != nil {
				return err
			}
			if err := tx.Delete(&messageRow{}, "room_id IN ?", ids).Error; err != nil {
				return err
			}
		}
		if err := tx.Delete(&requestRow{}, "applicant_email = ?", email).Error; err != nil {
			return err
		}
		if err := tx.Delete(&messageRow{}, "sender_email = ?", email).Error; err != nil {
			return err
		}
		return tx.Delete(&userRow{}, "email = ?", email).Error
	})
	if err != nil {
		return nil, err
	}
	return roomIDs, nil
}

func (s *UserStore) UpdateProfile(email string, username string, name string, gender string, bio string, avatar string) error {
	var row userRow
	if err := DB.Where("email = ?", email).First(&row).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("user not found")
		}
		return err
	}

	cleanUsername := strings.TrimSpace(username)
	if cleanUsername != "" {
		if !IsValidUsername(cleanUsername) {
			return errors.New("username must be 3-20 characters long and contain only letters, numbers, underscores or dots")
		}
		if s.IsUsernameTaken(cleanUsername, email) {
			return errors.New("username is already taken")
		}
		row.Username = cleanUsername
	}
	if name != "" {
		row.Name = name
	}
	if gender != "" {
		row.Gender = gender
	}
	if bio != "" {
		row.Bio = bio
	}
	if avatar != "" {
		row.Avatar = avatar
	}

	err := DB.Clauses(clause.OnConflict{
		Columns:   []clause.Column{{Name: "email"}},
		DoUpdates: clause.AssignmentColumns([]string{"username", "name", "gender", "bio", "avatar"}),
	}).Create(&row).Error
	if err != nil && strings.Contains(strings.ToLower(err.Error()), "idx_users_username_lower") {
		return errors.New("username is already taken")
	}
	return err
}
