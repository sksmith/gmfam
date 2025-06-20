# Build stage
FROM golang:1.24-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata gcc musl-dev

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Generate ent code
RUN go install entgo.io/ent/cmd/ent@latest
RUN go generate ./...

# Build the application
RUN CGO_ENABLED=1 GOOS=linux go build -a -installsuffix cgo -ldflags="-s -w" -o main ./cmd/web && \
    echo "Binary built successfully:" && ls -la main

# Final stage
FROM alpine:latest

# Install runtime dependencies
RUN apk --no-cache add ca-certificates tzdata

# Create app user
RUN adduser -D -s /bin/sh appuser

# Set working directory
WORKDIR /app

# Copy binary from builder stage
COPY --from=builder /app/main .

# Copy static files and config
COPY --from=builder /app/public ./public
COPY --from=builder /app/config ./config

# Verify binary is executable
RUN echo "Verifying binary in final stage:" && ls -la main

# Create directories for app data with proper permissions
RUN mkdir -p /app/dbs /app/uploads && \
    chmod -R 755 /app && \
    chown -R appuser:appuser /app

# Switch to app user
USER appuser

# Expose port
EXPOSE 8000

# Health check - more generous for startup
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8000/ || exit 1

# Run the application with detailed logging
CMD ["sh", "-c", "echo 'Container startup initiated...' && echo 'Current user:' && whoami && echo 'Working directory:' && pwd && echo 'Directory contents:' && ls -la && echo 'Environment variables:' && env | grep PAGODA | sort && echo 'Starting application...' && ./main 2>&1"]