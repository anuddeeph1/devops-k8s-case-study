FROM golang:1.21-alpine AS builder

# Install git and other build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download && go mod verify

# Copy source code
COPY main.go ./

# Build the application with optimizations
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -o pod-monitor .

# Final stage
FROM alpine:3.18

# Install ca-certificates for HTTPS connections
RUN apk --no-cache add ca-certificates tzdata

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /root/

# Copy binary from builder stage
COPY --from=builder /app/pod-monitor .

# Change ownership to non-root user
RUN chown appuser:appgroup pod-monitor

# Switch to non-root user
USER appuser

# Set environment variables
ENV NAMESPACE=devops-case-study

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep -f pod-monitor || exit 1

# Run the binary
ENTRYPOINT ["./pod-monitor"]
