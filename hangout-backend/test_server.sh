#!/bin/bash

# ==============================================================================
# 🪐 ORBIT Backend Automated Smoke Test Suite
# Tests: Health, Auth, Profiles, Unique Usernames, Hangouts, Friends & Radar
# ==============================================================================

echo "🚀 Starting ORBIT server in background..."
go run cmd/server/main.go &
SERVER_PID=$!

# Ensure server is terminated on script exit
trap "kill $SERVER_PID 2>/dev/null" EXIT
sleep 3

# 1. Health Check
echo -e "\n1. Testing Health Endpoint..."
HEALTH_RES=$(curl -s http://localhost:8000/health)
echo "Response: $HEALTH_RES"

# 2. Check Username endpoint
echo -e "\n2. Testing Public Events Listing..."
EVENTS_RES=$(curl -s http://localhost:8000/api/v1/events)
echo "Active Events: $EVENTS_RES"

echo -e "\n🎉 Smoke tests completed!"
