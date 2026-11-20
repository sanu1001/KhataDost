# KhataDost Go backend.
# One image, two jobs: `api` (the server, the default command) and `goose`
# (runs the SQL migrations in db/migrations). docker-compose.yml uses both.

# ── Build stage: compile both binaries ────────────────────────────────────────
FROM golang:1.25-alpine AS build
WORKDIR /src

# Modules first, so this layer stays cached until go.mod or go.sum change.
COPY go.mod go.sum ./
RUN go mod download

# goose, pinned so every build uses the same migration tool.
RUN CGO_ENABLED=0 go install github.com/pressly/goose/v3/cmd/goose@v3.26.0

# The server. CGO off gives a static binary that runs on plain Alpine.
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/api ./cmd/api

# ── Runtime stage: just the binaries and the migrations ──────────────────────
FROM alpine:3.22
# CA certificates so the server can call Gemini over HTTPS.
RUN apk add --no-cache ca-certificates && adduser -D -H app
WORKDIR /app
COPY --from=build /out/api /usr/local/bin/api
COPY --from=build /go/bin/goose /usr/local/bin/goose
COPY db/migrations ./db/migrations
# Don't run as root inside the container.
USER app
EXPOSE 8080
CMD ["api"]
