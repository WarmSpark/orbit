package api

import (
	"encoding/json"
	"fmt"
	"hangout-backend/internal/database"
	"net/http"
	"strconv"
	"strings"
	"time"
)

type EventHandler struct {
	EventStore   *database.EventStore
	RequestStore *database.RequestStore
	UserStore    *database.UserStore
	ChatHub      *ChatHub
	ChatStore    *database.ChatStore
}

type CancelEventRequest struct {
	EventId string `json:"event_id"`
}

type LeaveEventRequest struct {
	EventId string `json:"event_id"`
}

type KickParticipantRequest struct {
	EventId          string `json:"event_id"`
	ParticipantEmail string `json:"participant_email"`
}

func NewEventHandler(
	eventStore *database.EventStore,
	requestStore *database.RequestStore,
	userStore *database.UserStore,
	chatHub *ChatHub,
	chatStore *database.ChatStore,
) *EventHandler {
	return &EventHandler{
		EventStore:   eventStore,
		RequestStore: requestStore,
		UserStore:    userStore,
		ChatHub:      chatHub,
		ChatStore:    chatStore,
	}
}

type CreateEventRequest struct {
	Title           string  `json:"title"`
	Category        string  `json:"category"`
	Location        string  `json:"location"`
	Latitude        float64 `json:"latitude"`
	Longitude       float64 `json:"longitude"`
	Time            string  `json:"time"`
	MaxParticipants int     `json:"max_participants"`
}

func (h *EventHandler) CreateEvent(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	var req CreateEventRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Invalid Input"})
		return
	}

	req.Title = sanitizeText(req.Title, maxTitleLen)
	req.Location = sanitizeText(req.Location, maxLocationLen)
	req.Time = sanitizeText(req.Time, 40)
	req.Category = normalizeCategory(req.Category)
	req.MaxParticipants = clampCapacity(req.MaxParticipants)

	if req.Title == "" || req.Time == "" || req.Location == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Title, time and location are required"})
		return
	}

	if containsBlockedContent(req.Title) || containsBlockedContent(req.Location) {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Hangout contains content that is not allowed"})
		return
	}

	if !validLatLng(req.Latitude, req.Longitude) {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Invalid location coordinates"})
		return
	}

	if !withinNCR(req.Latitude, req.Longitude) {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Hangouts can only be created inside the NCR"})
		return
	}

	if !withinCampus(req.Latitude, req.Longitude) {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Hangouts can only be created on campus"})
		return
	}

	eventId := strconv.FormatInt(time.Now().UnixNano(), 10)
	userEmail := GetUserEmail(r.Context())
	if h.EventStore.HasActiveEvent(userEmail) {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{
			Status:  "error",
			Message: "You can only create one active hangout at a time",
		})
		return
	}
	newEvent := database.Event{
		ID:              eventId,
		Title:           req.Title,
		Category:        req.Category,
		Time:            req.Time,
		CreatorEmail:    userEmail,
		Location:        req.Location,
		Latitude:        req.Latitude,
		Longitude:       req.Longitude,
		MaxParticipants: req.MaxParticipants,
		CreatedAt:       time.Now().Format(time.RFC3339),
	}
	h.EventStore.SaveEvent(newEvent)
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(AuthResponse{Status: "ok", Message: "Hangout created successfully"})
}

type EventView struct {
	ID              string  `json:"id"`
	Title           string  `json:"title"`
	Category        string  `json:"category"`
	Location        string  `json:"location"`
	Latitude        float64 `json:"latitude"`
	Longitude       float64 `json:"longitude"`
	Time            string  `json:"time"`
	MaxParticipants int     `json:"max_participants"`
	ApprovedCount   int     `json:"approved_count"`
	IsFull          bool    `json:"is_full"`
	IsHost          bool    `json:"is_host"`
	CreatedAt       string  `json:"created_at"`
	HostUsername    string  `json:"host_username"`
	HostName        string  `json:"host_name"`
	HostGender      string  `json:"host_gender"`
	HostAvatar      string  `json:"host_avatar"`
	HostBio         string  `json:"host_bio"`
}

func (h *EventHandler) buildView(e database.Event, userEmail string) EventView {
	approved := h.RequestStore.GetApprovedCount(e.ID)
	hostUsername := ""
	hostName := ""
	hostGender := ""
	hostBio := ""
	hostAvatar := "default_white"
	if host, ok := h.UserStore.GetUser(e.CreatorEmail); ok {
		hostUsername = host.Username
		hostName = host.Name
		hostGender = host.Gender
		hostBio = host.Bio
		if host.Avatar != "" {
			hostAvatar = host.Avatar
		}
	}
	return EventView{
		ID:       e.ID,
		Title:    e.Title,
		Category: e.Category,
		Location: e.Location,

		Latitude:        fuzzCoord(e.Latitude),
		Longitude:       fuzzCoord(e.Longitude),
		Time:            e.Time,
		MaxParticipants: e.MaxParticipants,
		ApprovedCount:   approved,
		IsFull:          approved+1 >= e.MaxParticipants,
		IsHost:          e.CreatorEmail == userEmail,
		CreatedAt:       e.CreatedAt,
		HostUsername:    hostUsername,
		HostName:        hostName,
		HostGender:      hostGender,
		HostAvatar:      hostAvatar,
		HostBio:         hostBio,
	}
}

func (h *EventHandler) ListEvents(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	userEmail := GetUserEmail(r.Context())
	events := h.EventStore.GetAllEvents()

	views := make([]EventView, 0, len(events))
	for _, e := range events {
		views = append(views, h.buildView(e, userEmail))
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(views)
}

func (h *EventHandler) GetEvent(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	eventID := strings.TrimSpace(r.URL.Query().Get("event_id"))
	if eventID == "" || len(eventID) > 32 {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "event_id is required"})
		return
	}
	event, exists := h.EventStore.GetEvent(eventID)
	if !exists {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Hangout not found or expired"})
		return
	}
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(h.buildView(event, GetUserEmail(r.Context())))
}

func (h *EventHandler) CancelEvent(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	var req CancelEventRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.EventId == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Invalid Input"})
		return
	}
	userEmail := GetUserEmail(r.Context())
	if err := h.EventStore.DeleteEvent(req.EventId, userEmail); err != nil {
		w.WriteHeader(http.StatusForbidden)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: err.Error()})
		return
	}

	h.ChatHub.CloseRoom(req.EventId)
	h.ChatStore.DeleteRoomHistory(req.EventId)
	h.RequestStore.CleanupEventRequests([]string{req.EventId})

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(AuthResponse{Status: "ok", Message: "Hangout cancelled successfully"})
}

func (h *EventHandler) LeaveEvent(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	var req LeaveEventRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.EventId == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Invalid Input"})
		return
	}

	userEmail := GetUserEmail(r.Context())
	event, exists := h.EventStore.GetEvent(req.EventId)
	if !exists {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Hangout not found"})
		return
	}

	if event.CreatorEmail == userEmail {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Host cannot leave. Please cancel the hangout instead."})
		return
	}

	if err := h.RequestStore.LeaveEvent(req.EventId, userEmail); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: err.Error()})
		return
	}

	h.ChatHub.DisconnectUser(req.EventId, userEmail, "left")

	user, _ := h.UserStore.GetUser(userEmail)
	handle := user.Username
	if handle == "" {
		handle = userEmail
	}
	h.ChatHub.BroadcastSystem(req.EventId, fmt.Sprintf("@%s left the hangout", handle))

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(AuthResponse{Status: "ok", Message: "Left hangout successfully"})
}

func (h *EventHandler) KickParticipant(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	var req KickParticipantRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.EventId == "" || req.ParticipantEmail == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Invalid Input"})
		return
	}

	userEmail := GetUserEmail(r.Context())
	event, exists := h.EventStore.GetEvent(req.EventId)
	if !exists {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Hangout not found"})
		return
	}

	if event.CreatorEmail != userEmail {
		w.WriteHeader(http.StatusForbidden)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Only the hangout host can kick participants"})
		return
	}

	if err := h.RequestStore.KickParticipant(req.EventId, req.ParticipantEmail); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: err.Error()})
		return
	}

	h.ChatHub.DisconnectUser(req.EventId, req.ParticipantEmail, "kicked")

	kickedUser, _ := h.UserStore.GetUser(req.ParticipantEmail)
	handle := kickedUser.Username
	if handle == "" {
		handle = req.ParticipantEmail
	}
	h.ChatHub.BroadcastSystem(req.EventId, fmt.Sprintf("@%s was removed from the hangout", handle))

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(AuthResponse{Status: "ok", Message: "Participant kicked successfully"})
}

func (h *EventHandler) GetEventMembers(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	userEmail := GetUserEmail(r.Context())
	eventID := r.URL.Query().Get("event_id")
	if eventID == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "event_id is required"})
		return
	}

	event, exists := h.EventStore.GetEvent(eventID)
	if !exists {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Hangout not found"})
		return
	}

	isHost := event.CreatorEmail == userEmail
	isApproved := h.RequestStore.IsApprovedMember(eventID, userEmail)

	if !isHost && !isApproved {
		w.WriteHeader(http.StatusForbidden)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Forbidden: You are not a member of this hangout"})
		return
	}

	var members []database.EventMember

	hostUser, hostExists := h.UserStore.GetUser(event.CreatorEmail)
	if hostExists {
		members = append(members, database.EventMember{
			Username: hostUser.Username,
			Name:     hostUser.Name,
			Gender:   hostUser.Gender,
			Avatar:   hostUser.Avatar,
			Bio:      hostUser.Bio,
			IsHost:   true,
		})
	}

	approvedEmails := h.RequestStore.GetApprovedEmails(eventID)
	for _, email := range approvedEmails {
		user, uExists := h.UserStore.GetUser(email)
		if uExists {
			member := database.EventMember{
				Username: user.Username,
				Name:     user.Name,
				Gender:   user.Gender,
				Avatar:   user.Avatar,
				Bio:      user.Bio,
				IsHost:   false,
			}

			if isHost {
				member.Email = email
			}
			members = append(members, member)
		}
	}

	if members == nil {
		members = []database.EventMember{}
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(members)
}
