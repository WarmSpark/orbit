# syntax=docker/dockerfile:1

# ---- build stage ----
FROM golang:1.26-alpine AS build
WORKDIR /src

# Download modules first so this layer is cached until go.mod/go.sum change.
COPY go.mod go.sum ./
RUN go mod download

COPY . .

# Static, stripped binary — no libc needed, so it runs on a distroless base.
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/server ./cmd/server

# ---- run stage ----
# Distroless "static" is a tiny, non-root image with no shell or package manager,
# which keeps the attack surface minimal.
FROM gcr.io/distroless/static-debian12:nonroot

# Config is injected at runtime as Heroku config vars:
#   ORBIT_ENV=production, GOOGLE_CLIENT_ID=..., (optional) JWT_SECRET, ALLOWED_ORIGINS
# The server reads $PORT (Heroku sets it) and falls back to 8000 locally.
COPY --from=build /out/server /server

USER nonroot:nonroot
EXPOSE 8000
ENTRYPOINT ["/server"]
