# Build stage
FROM docker.io/golang:1.24-alpine AS builder

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
FROM docker.io/alpine:latest

# Install runtime dependencies including PostgreSQL client for debugging
RUN apk --no-cache add ca-certificates tzdata python3 postgresql-client

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

# Switch to non-root user for security
USER appuser

# Expose port
EXPOSE 8000

# Health check - more generous for startup
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8000/ || exit 1

# Run the application
CMD ["./main"]