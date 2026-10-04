package api

import (
	"encoding/json"
	"hangout-backend/internal/database"
	"net/http"
	"os"
	"strings"
)

type GoogleAuthRequest struct {
	IDToken string `json:"id_token"`
}

type GoogleTokenInfo struct {
	Email         string `json:"email"`
	EmailVerified string `json:"email_verified"`
	Name          string `json:"name"`
	Picture       string `json:"picture"`
	Aud           string `json:"aud"`
}

type UpdateProfileRequest struct {
	Username string `json:"username"`
	Name     string `json:"name"`
	Gender   string `json:"gender"`
	Bio      string `json:"bio"`
	Avatar   string `json:"avatar"`
}

type AuthResponse struct {
	Status    string         `json:"status"`
	Message   string         `json:"message"`
	Token     string         `json:"token,omitempty"`
	IsNewUser bool           `json:"is_new_user,omitempty"`
	User      *database.User `json:"user,omitempty"`
}

type DeleteAccountRequest struct {
	Confirm string `json:"confirm"`
}

type AuthHandler struct {
	Store   *database.UserStore
	ChatHub *ChatHub
}

func NewAuthHandler(store *database.UserStore) *AuthHandler {
	return &AuthHandler{Store: store}
}

func (h *AuthHandler) SetChatHub(hub *ChatHub) { h.ChatHub = hub }

func (h *AuthHandler) DeleteAccount(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	if !IsProd() && strings.TrimSpace(os.Getenv("ORBIT_DELETE_KEY")) != "" {
		if strings.TrimSpace(r.Header.Get("X-Delete-Key")) != strings.TrimSpace(os.Getenv("ORBIT_DELETE_KEY")) {
			w.WriteHeader(http.StatusForbidden)
			json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Forbidden"})
			return
		}
	}
	var req DeleteAccountRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || strings.ToLower(strings.TrimSpace(req.Confirm)) != "delete" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Type delete to confirm"})
		return
	}

	userEmail := GetUserEmail(r.Context())
	roomIDs, err := h.Store.DeleteAccount(userEmail)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Could not delete account"})
		return
	}

	if h.ChatHub != nil {
		h.ChatHub.CloseRooms(roomIDs)
		h.ChatHub.DisconnectUser(townhallRoomID, userEmail, "account_deleted")
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(AuthResponse{Status: "ok", Message: "Account deleted"})
}

func (h *AuthHandler) GoogleLogin(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	var req GoogleAuthRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.IDToken == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Missing id_token"})
		return
	}

	googleURL := "https://oauth2.googleapis.com/tokeninfo?id_token=" + req.IDToken
	resp, err := http.Get(googleURL)
	if err != nil || resp.StatusCode != http.StatusOK {
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Invalid Google token"})
		return
	}
	defer resp.Body.Close()

	var tokenInfo GoogleTokenInfo
	if err := json.NewDecoder(resp.Body).Decode(&tokenInfo); err != nil || tokenInfo.Email == "" {
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Failed to read Google token info"})
		return
	}

	if tokenInfo.EmailVerified != "true" {
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Google email is not verified"})
		return
	}

	if googleClientID != "" && tokenInfo.Aud != googleClientID {
		w.WriteHeader(http.StatusUnauthorized)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Google token was not issued for this app"})
		return
	}

	user, exists := h.Store.GetUser(tokenInfo.Email)
	isNewUser := false
	if !exists {
		isNewUser = true

		user = database.User{
			Username: tokenInfo.Name,
			Email:    tokenInfo.Email,
			Name:     sanitizeText(tokenInfo.Name, maxNameLen),
			Bio:      "Hey there! I am using Orbit",
			Avatar:   "default_white",
		}
		h.Store.SaveUser(user)

		user, _ = h.Store.GetUser(tokenInfo.Email)
	}

	token, err := GenerateToken(user.Email)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Failed to Generate Token"})
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(AuthResponse{
		Status:    "ok",
		Message:   "Google Login success",
		Token:     token,
		IsNewUser: isNewUser,
		User:      &user,
	})
}

type DevLoginRequest struct {
	Email    string `json:"email"`
	Username string `json:"username"`
}

func (h *AuthHandler) DevLogin(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")

	if !devAuthEnabled {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Not found"})
		return
	}

	var req DevLoginRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Invalid input"})
		return
	}

	email := strings.ToLower(strings.TrimSpace(req.Email))
	if email == "" || !strings.Contains(email, "@") {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "A valid email is required"})
		return
	}

	user, exists := h.Store.GetUser(email)
	isNewUser := false
	if !exists {
		isNewUser = true
		name := strings.TrimSpace(req.Username)
		if name == "" {
			name = strings.SplitN(email, "@", 2)[0]
		}
		user = database.User{
			Username: name,
			Email:    email,
			Bio:      "Hey there! I am using Orbit",
			Avatar:   "default_white",
		}
		h.Store.SaveUser(user)

		user, _ = h.Store.GetUser(email)
	}

	token, err := GenerateToken(user.Email)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Failed to Generate Token"})
		return
	}

	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(AuthResponse{
		Status:    "ok",
		Message:   "Dev login success",
		Token:     token,
		IsNewUser: isNewUser,
		User:      &user,
	})
}

func (h *AuthHandler) GetProfile(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	userEmail := GetUserEmail(r.Context())
	user, exists := h.Store.GetUser(userEmail)
	if !exists {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "User not found"})
		return
	}
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(user)
}

func (h *AuthHandler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	userEmail := GetUserEmail(r.Context())

	var req UpdateProfileRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Invalid Input"})
		return
	}

	req.Bio = sanitizeText(req.Bio, maxBioLen)
	req.Name = sanitizeText(req.Name, maxNameLen)
	if containsBlockedContent(req.Username) || containsBlockedContent(req.Name) || containsBlockedContent(req.Bio) {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Profile contains content that is not allowed"})
		return
	}

	gender, ok := normalizeGender(req.Gender)
	if !ok {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: "Invalid gender"})
		return
	}

	if err := h.Store.UpdateProfile(userEmail, req.Username, req.Name, gender, req.Bio, sanitizeAvatar(req.Avatar)); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(AuthResponse{Status: "error", Message: err.Error()})
		return
	}

	updatedUser, _ := h.Store.GetUser(userEmail)
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(AuthResponse{
		Status:  "ok",
		Message: "Profile updated successfully",
		User:    &updatedUser,
	})
}

func (h *AuthHandler) CheckUsernameAvailability(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	userEmail := GetUserEmail(r.Context())
	username := strings.TrimSpace(r.URL.Query().Get("username"))

	if username == "" {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]interface{}{"available": false, "message": "Username cannot be empty"})
		return
	}

	if !database.IsValidUsername(username) {
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]interface{}{"available": false, "message": "Must be 3-20 letters/numbers/_"})
		return
	}

	isTaken := h.Store.IsUsernameTaken(username, userEmail)
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"available": !isTaken,
		"message":   map[bool]string{true: "Username is available", false: "Username is already taken"}[!isTaken],
	})
}
