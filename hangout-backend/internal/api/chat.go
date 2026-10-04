package api

import (
	"encoding/json"
	"fmt"
	"hangout-backend/internal/database"
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = (pongWait * 9) / 10
	maxMessageSize = 16 * 1024

	msgRateWindow    = 5 * time.Second
	maxMsgsPerWindow = 15

	maxConnsPerUser   = 3
	userMsgRateWindow = 10 * time.Second
	maxUserMsgWindow  = 20
)

const townhallRoomID = database.TownhallRoomID

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return originAllowed(r.Header.Get("Origin"))
	},
}

type Client struct {
	hub        *ChatHub
	conn       *websocket.Conn
	send       chan []byte
	roomID     string
	userEmail  string
	userHandle string

	msgWindowStart time.Time
	msgCount       int
}

type userMsgWindow struct {
	windowStart time.Time
	count       int
}

type ChatHub struct {
	rooms      map[string]map[*Client]bool
	broadcast  chan database.ChatMessage
	register   chan *Client
	unregister chan *Client
	chatStore  *database.ChatStore
	mu         sync.RWMutex

	userConns map[string]int
	userMsgMu sync.Mutex
	userMsg   map[string]*userMsgWindow
}

func NewChatHub(store *database.ChatStore) *ChatHub {
	return &ChatHub{
		rooms:      make(map[string]map[*Client]bool),
		broadcast:  make(chan database.ChatMessage),
		register:   make(chan *Client),
		unregister: make(chan *Client),
		chatStore:  store,
		userConns:  make(map[string]int),
		userMsg:    make(map[string]*userMsgWindow),
	}
}

func (h *ChatHub) connCountForUser(email string) int {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return h.userConns[email]
}

func (h *ChatHub) allowUserMessage(email string) bool {
	h.userMsgMu.Lock()
	defer h.userMsgMu.Unlock()

	now := time.Now()
	w, ok := h.userMsg[email]
	if !ok {
		if len(h.userMsg) > 10000 {
			for k, v := range h.userMsg {
				if now.Sub(v.windowStart) > userMsgRateWindow {
					delete(h.userMsg, k)
				}
			}
		}
		h.userMsg[email] = &userMsgWindow{windowStart: now, count: 1}
		return true
	}
	if now.Sub(w.windowStart) > userMsgRateWindow {
		w.windowStart = now
		w.count = 0
	}
	w.count++
	return w.count <= maxUserMsgWindow
}

func (h *ChatHub) Run() {
	for {
		select {
		case client := <-h.register:
			h.mu.Lock()
			if _, exists := h.rooms[client.roomID]; !exists {
				h.rooms[client.roomID] = make(map[*Client]bool)
			}
			h.rooms[client.roomID][client] = true
			h.userConns[client.userEmail]++
			h.mu.Unlock()

		case client := <-h.unregister:
			h.mu.Lock()
			if roomClients, exists := h.rooms[client.roomID]; exists {
				if _, ok := roomClients[client]; ok {
					delete(roomClients, client)
					close(client.send)
				}
				if len(roomClients) == 0 {
					delete(h.rooms, client.roomID)
				}
			}
			if h.userConns[client.userEmail] > 0 {
				h.userConns[client.userEmail]--
				if h.userConns[client.userEmail] == 0 {
					delete(h.userConns, client.userEmail)
				}
			}
			h.mu.Unlock()

		case msg := <-h.broadcast:
			h.chatStore.SaveMessages(msg)

			jsonBytes, err := json.Marshal(msg)
			if err != nil {
				continue
			}

			h.mu.RLock()
			if roomClients, exists := h.rooms[msg.RoomID]; exists {
				for client := range roomClients {
					select {
					case client.send <- jsonBytes:
					default:
						close(client.send)
						delete(roomClients, client)
					}
				}
			}
			h.mu.RUnlock()
		}
	}
}

func (h *ChatHub) DisconnectUser(roomID string, userEmail string, reason string) {
	payload, _ := json.Marshal(map[string]string{
		"type":   "action",
		"action": reason,
		"reason": reason,
	})

	h.mu.Lock()
	defer h.mu.Unlock()

	roomClients, exists := h.rooms[roomID]
	if !exists {
		return
	}

	for client := range roomClients {
		if client.userEmail == userEmail {
			select {
			case client.send <- payload:
			default:
			}
			close(client.send)
			delete(roomClients, client)
		}
	}

	if len(roomClients) == 0 {
		delete(h.rooms, roomID)
	}
}

func (h *ChatHub) CloseRoom(roomID string) {
	payload, _ := json.Marshal(map[string]string{
		"type":   "action",
		"action": "cancelled",
		"reason": "hangout cancelled by host",
	})

	h.mu.Lock()
	defer h.mu.Unlock()

	roomClients, exists := h.rooms[roomID]
	if !exists {
		return
	}

	for client := range roomClients {
		select {
		case client.send <- payload:
		default:
		}
		close(client.send)
	}
	delete(h.rooms, roomID)
}

func (h *ChatHub) CloseRooms(roomIDs []string) {
	for _, id := range roomIDs {
		h.CloseRoom(id)
	}
}

func (h *ChatHub) broadcastTyping(roomID string, senderHandle string) {
	payload, err := json.Marshal(map[string]string{
		"type":          "typing",
		"room_id":       roomID,
		"sender_handle": senderHandle,
	})
	if err != nil {
		return
	}

	h.mu.RLock()
	defer h.mu.RUnlock()
	roomClients, exists := h.rooms[roomID]
	if !exists {
		return
	}
	for client := range roomClients {

		if client.userHandle == senderHandle {
			continue
		}
		select {
		case client.send <- payload:
		default:
		}
	}
}

func (h *ChatHub) BroadcastSystem(roomID string, text string) {
	msg := database.ChatMessage{
		ID:           fmt.Sprintf("sys_%d", time.Now().UnixNano()),
		RoomID:       roomID,
		SenderEmail:  "system@orbit.local",
		SenderHandle: "System",
		Message:      text,
		Type:         "system",
		TimeStamp:    time.Now().Format(time.RFC3339),
	}
	h.broadcast <- msg
}

func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(maxMessageSize)
	c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(pongWait))
		return nil
	})

	for {
		_, messageBytes, err := c.conn.ReadMessage()
		if err != nil {
			break
		}
		var msg database.ChatMessage
		if err := json.Unmarshal(messageBytes, &msg); err != nil {
			continue
		}

		if msg.Type == "typing" {
			c.hub.broadcastTyping(c.roomID, c.userHandle)
			continue
		}

		now := time.Now()
		if now.Sub(c.msgWindowStart) > msgRateWindow {
			c.msgWindowStart = now
			c.msgCount = 0
		}
		c.msgCount++
		if c.msgCount > maxMsgsPerWindow {
			continue
		}

		if !c.hub.allowUserMessage(c.userEmail) {
			continue
		}

		msg.RoomID = c.roomID
		msg.SenderEmail = c.userEmail
		msg.SenderHandle = c.userHandle
		msg.Type = "chat"
		msg.ID = fmt.Sprintf("msg_%d", now.UnixNano())
		msg.TimeStamp = now.Format(time.RFC3339)

		msg.Message = sanitizeText(msg.Message, maxMessageLen)
		msg.ReplyToText = sanitizeText(msg.ReplyToText, 200)
		if len(msg.ReplyToID) > 64 {
			msg.ReplyToID = ""
		}
		if msg.Message == "" || containsBlockedContent(msg.Message) {
			continue
		}

		c.hub.broadcast <- msg
	}
}

func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case messageBytes, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(messageBytes)

			n := len(c.send)
			for i := 0; i < n; i++ {
				w.Write([]byte{'\n'})
				w.Write(<-c.send)
			}

			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

type ChatHandler struct {
	hub          *ChatHub
	store        *database.ChatStore
	eventStore   *database.EventStore
	requestStore *database.RequestStore
	userStore    *database.UserStore
}

func NewChatHandler(hub *ChatHub, store *database.ChatStore, eventStore *database.EventStore, requestStore *database.RequestStore, userStore *database.UserStore) *ChatHandler {
	return &ChatHandler{
		hub:          hub,
		store:        store,
		eventStore:   eventStore,
		requestStore: requestStore,
		userStore:    userStore,
	}
}

func (h *ChatHandler) ServeWs(w http.ResponseWriter, r *http.Request) {
	roomId := r.URL.Query().Get("room_id")
	tokenSt := r.URL.Query().Get("token")
	if roomId == "" {
		http.Error(w, "room id required", http.StatusBadRequest)
		return
	}

	email, err := ValidateToken(tokenSt)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	event, exists := h.eventStore.GetEvent(roomId)
	if !exists {
		http.Error(w, "hangout not found or expired", http.StatusNotFound)
		return
	}

	isHost := event.CreatorEmail == email
	isApproved := h.requestStore.IsApprovedMember(roomId, email)

	if !isHost && !isApproved {
		http.Error(w, "forbidden: host has not approved your request", http.StatusForbidden)
		return
	}

	if h.hub.connCountForUser(email) >= maxConnsPerUser {
		http.Error(w, "too many active chat connections", http.StatusTooManyRequests)
		return
	}

	user, uExists := h.userStore.GetUser(email)
	handle := "@" + email
	if uExists && user.Username != "" {
		handle = "@" + user.Username
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}

	client := &Client{
		hub:        h.hub,
		conn:       conn,
		send:       make(chan []byte, 256),
		roomID:     roomId,
		userEmail:  email,
		userHandle: handle,
	}
	client.hub.register <- client

	history := h.store.GetRoomHistory(roomId)
	historyBytes, _ := json.Marshal(map[string]interface{}{
		"type":    "history",
		"history": history,
	})
	client.send <- historyBytes

	go client.writePump()
	go client.readPump()
}

func (h *ChatHandler) ServeTownhall(w http.ResponseWriter, r *http.Request) {
	tokenSt := r.URL.Query().Get("token")
	email, err := ValidateToken(tokenSt)
	if err != nil {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	lat, errLat := strconv.ParseFloat(r.URL.Query().Get("lat"), 64)
	lng, errLng := strconv.ParseFloat(r.URL.Query().Get("lng"), 64)
	if errLat != nil || errLng != nil || !validLatLng(lat, lng) || !withinNCR(lat, lng) {
		http.Error(w, "forbidden: town hall is only available inside the NCR", http.StatusForbidden)
		return
	}

	if h.hub.connCountForUser(email) >= maxConnsPerUser {
		http.Error(w, "too many active chat connections", http.StatusTooManyRequests)
		return
	}

	user, uExists := h.userStore.GetUser(email)
	handle := "@" + email
	if uExists && user.Username != "" {
		handle = "@" + user.Username
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}

	client := &Client{
		hub:        h.hub,
		conn:       conn,
		send:       make(chan []byte, 256),
		roomID:     townhallRoomID,
		userEmail:  email,
		userHandle: handle,
	}
	client.hub.register <- client

	history := h.store.GetRoomHistory(townhallRoomID)
	historyBytes, _ := json.Marshal(map[string]interface{}{
		"type":    "history",
		"history": history,
	})
	client.send <- historyBytes

	go client.writePump()
	go client.readPump()
}
