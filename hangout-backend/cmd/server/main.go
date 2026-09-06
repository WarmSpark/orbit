package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"hangout-backend/internal/api"
	"hangout-backend/internal/database"

	"github.com/joho/godotenv"
)

func main() {

	_ = godotenv.Load()

	if err := api.ProdConfigError(); err != nil {
		log.Fatalf("[startup] refusing to start: %v", err)
	}

	if err := database.Connect(); err != nil {
		log.Fatalf("[startup] database: %v", err)
	}

	userStore := database.NewUserStore()
	authHandler := api.NewAuthHandler(userStore)

	eventStore := database.NewEventStore()
	requestStore := database.NewRequestStore()

	chatStore := database.NewChatStore()
	chatHub := api.NewChatHub(chatStore)
	go chatHub.Run()

	chatHandler := api.NewChatHandler(chatHub, chatStore, eventStore, requestStore, userStore)
	eventHandler := api.NewEventHandler(eventStore, requestStore, userStore, chatHub, chatStore)
	requestHandler := api.NewRequestHandler(requestStore, eventStore, userStore)

	database.StartReaper(eventStore, requestStore, chatStore, 5*time.Minute)

	mux := http.NewServeMux()

	mux.Handle("GET /", landingHandler())

	mux.HandleFunc("GET /health", api.HealthHandler)
	mux.HandleFunc("POST /api/v1/auth/google", authHandler.GoogleLogin)

	if api.DevAuthEnabled() {
		mux.HandleFunc("POST /api/v1/auth/dev", authHandler.DevLogin)
	}
	mux.HandleFunc("GET /api/v1/chat/ws", chatHandler.ServeWs)
	mux.HandleFunc("GET /api/v1/townhall/ws", chatHandler.ServeTownhall)

	mux.Handle("GET /api/v1/events", api.AuthMiddleWare(http.HandlerFunc(eventHandler.ListEvents)))

	mux.Handle("GET /api/v1/user/profile", api.AuthMiddleWare(http.HandlerFunc(authHandler.GetProfile)))
	mux.Handle("PUT /api/v1/user/profile", api.AuthMiddleWare(http.HandlerFunc(authHandler.UpdateProfile)))
	mux.Handle("GET /api/v1/users/check-username", api.AuthMiddleWare(http.HandlerFunc(authHandler.CheckUsernameAvailability)))

	mux.Handle("POST /api/v1/events", api.AuthMiddleWare(http.HandlerFunc(eventHandler.CreateEvent)))
	mux.Handle("POST /api/v1/events/cancel", api.AuthMiddleWare(http.HandlerFunc(eventHandler.CancelEvent)))
	mux.Handle("POST /api/v1/events/leave", api.AuthMiddleWare(http.HandlerFunc(eventHandler.LeaveEvent)))
	mux.Handle("POST /api/v1/events/kick", api.AuthMiddleWare(http.HandlerFunc(eventHandler.KickParticipant)))
	mux.Handle("GET /api/v1/events/members", api.AuthMiddleWare(http.HandlerFunc(eventHandler.GetEventMembers)))

	mux.Handle("POST /api/v1/events/join", api.AuthMiddleWare(http.HandlerFunc(requestHandler.ApplyJoin)))
	mux.Handle("GET /api/v1/events/requests", api.AuthMiddleWare(http.HandlerFunc(requestHandler.GetEventRequests)))
	mux.Handle("POST /api/v1/events/requests/respond", api.AuthMiddleWare(http.HandlerFunc(requestHandler.RespondRequest)))
	mux.Handle("GET /api/v1/user/requests", api.AuthMiddleWare(http.HandlerFunc(requestHandler.GetMyJoinRequest)))

	var handler http.Handler = mux
	handler = api.MaxBodyBytes(handler)
	handler = api.LoggingMiddleware(handler)
	handler = api.RateLimitMiddleware(handler)
	handler = api.CORSMiddleware(handler)

	port := strings.TrimSpace(os.Getenv("PORT"))
	if port == "" {
		port = "8000"
	}

	srv := &http.Server{
		Addr:    ":" + port,
		Handler: handler,

		ReadHeaderTimeout: 10 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	go func() {
		log.Printf("Server running on :%s (prod=%t)", port, api.IsProd())
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("Server error: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	<-stop

	log.Println("Shutting down…")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("graceful shutdown failed: %v", err)
	}
}
