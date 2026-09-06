package api

import (
	"encoding/json"
	"hangout-backend/internal/database"
	"net/http"
	"strconv"
	"time"
)

type RequestHandler struct {
	RequestStore *database.RequestStore
	EventStore   *database.EventStore
	UserStore    *database.UserStore
}

func NewRequestHandler(store *database.RequestStore, eventStore *database.EventStore, userStore *database.UserStore) *RequestHandler {
	return &RequestHandler{RequestStore: store, EventStore: eventStore, UserStore: userStore}
}

type ApplyJoinRequest struct {
	EventID string `json:"event_id"`
}

type RespondRequest struct {
	RequestID string `json:"request_id"`
	Status    string `json:"status"`
}

type ApplicantView struct {
	RequestID string `json:"request_id"`
	Username  string `json:"username"`
	Name      string `json:"name"`
	Gender    string `json:"gender"`
	Avatar    string `json:"avatar"`
	Bio       string `json:"bio"`
	CreatedAt string `json:"created_at"`
}

func (h *RequestHandler) ApplyJoin(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	var req ApplyJoinRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.EventID == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Invalid Input"})
		return
	}
	userEmail := GetUserEmail(r.Context())

	event, exists := h.EventStore.GetEvent(req.EventID)
	if !exists {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Hangout not found"})
		return
	}

	if event.CreatorEmail == userEmail {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "You cannot join your own hangout"})
		return
	}

	if h.RequestStore.HasUserRequested(req.EventID, userEmail) {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{
			Status:  "error",
			Message: "You have already requested or joined this hangout",
		})
		return
	}

	reqID := strconv.FormatInt(time.Now().UnixNano(), 10)
	h.RequestStore.CreateRequest(database.JoinRequest{
		ID:             reqID,
		EventID:        req.EventID,
		ApplicantEmail: userEmail,
		Status:         "pending",
		CreatedAt:      time.Now().Format(time.RFC3339),
	})
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(AuthResponse{Status: "ok", Message: "Join request sent!"})
}

func (h *RequestHandler) GetEventRequests(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	eventId := r.URL.Query().Get("event_id")
	if eventId == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "event_id required"})
		return
	}

	userEmail := GetUserEmail(r.Context())
	event, exists := h.EventStore.GetEvent(eventId)
	if !exists {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Hangout not found"})
		return
	}
	if event.CreatorEmail != userEmail {
		w.WriteHeader(http.StatusForbidden)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Only the host can view join requests"})
		return
	}

	requests := h.RequestStore.GetRequestsForEvent(eventId)
	views := make([]ApplicantView, 0, len(requests))
	for _, req := range requests {
		view := ApplicantView{
			RequestID: req.ID,
			CreatedAt: req.CreatedAt,
			Avatar:    "default_white",
		}
		if user, ok := h.UserStore.GetUser(req.ApplicantEmail); ok {
			view.Username = user.Username
			view.Name = user.Name
			view.Gender = user.Gender
			view.Bio = user.Bio
			if user.Avatar != "" {
				view.Avatar = user.Avatar
			}
		}
		views = append(views, view)
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(views)
}

func (h *RequestHandler) RespondRequest(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	var req RespondRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.RequestID == "" || (req.Status != "approved" && req.Status != "declined") {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Invalid Input"})
		return
	}

	userEmail := GetUserEmail(r.Context())
	joinReq, exists := h.RequestStore.GetRequest(req.RequestID)
	if !exists {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Request not found"})
		return
	}

	event, eventExists := h.EventStore.GetEvent(joinReq.EventID)
	if !eventExists {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Hangout not found"})
		return
	}

	if event.CreatorEmail != userEmail {
		w.WriteHeader(http.StatusForbidden)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Only the host can respond to requests"})
		return
	}

	if req.Status == "approved" {

		if err := h.RequestStore.ApproveRequest(req.RequestID, event.MaxParticipants); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: err.Error()})
			return
		}
	} else {
		if err := h.RequestStore.UpdateRequestStatus(req.RequestID, "declined"); err != nil {
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: err.Error()})
			return
		}
	}

	msg := "Request declined"
	if req.Status == "approved" {
		msg = "Request approved! Member added to hangout."
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(AuthResponse{Status: "ok", Message: msg})
}

func (h *RequestHandler) GetMyJoinRequest(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	userEmail := GetUserEmail(r.Context())
	requests := h.RequestStore.GetRequestsByApplicant(userEmail)
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(requests)
}
