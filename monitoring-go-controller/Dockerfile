FROM golang:1.21-alpine AS builder

# Install git and other build dependencies
# Use latest available versions for compatibility
RUN apk add --no-cache \
    git \
    ca-certificates \
    tzdata

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies and verify
RUN go mod download && go mod verify

# Copy source code
COPY main.go ./

# Build the application with security-focused optimizations
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a -installsuffix cgo \
    -trimpath \
    -mod=readonly \
    -buildvcs=false \
    -o pod-monitor .

# Final stage - Distroless for maximum security
# Security scanning is handled externally via CI/CD pipeline and security scripts
FROM gcr.io/distroless/static-debian11:nonroot

# Metadata for security scanning and attestation
LABEL maintainer="DevOps Case Study <devops@example.com>"
LABEL version="1.0.0"
LABEL description="Pod monitoring agent with security scanning support"

# Security scanning labels
LABEL security.scan.enabled="true"
LABEL security.sbom.enabled="true"
LABEL security.vex.enabled="true"
LABEL grype.anchore.io/enabled="true"
LABEL syft.anchore.io/enabled="true"
LABEL cosign.sigstore.dev/attestation="true"

# Build and security information
LABEL build.date="2024-01-01"
LABEL build.system="github-actions"
LABEL security.scan.enabled="true"
LABEL security.base.image="gcr.io/distroless/static-debian11:nonroot"

# Application metadata
LABEL application.name="pod-monitor"
LABEL application.component="monitoring"
LABEL application.tier="infrastructure"
LABEL application.security.compliance="pod-security-standards"

# Copy binary from builder stage
COPY --from=builder /app/pod-monitor /usr/local/bin/pod-monitor

# Note: SBOM can be generated at runtime or via external tools
# Keeping the container minimal and focused

# Set environment variables for security compliance
ENV NAMESPACE=devops-case-study
ENV USER_ID=65532
ENV GROUP_ID=65532
ENV GOMAXPROCS=1
ENV GOGC=80

# Health check with minimal footprint
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ["/usr/local/bin/pod-monitor", "--health-check"]

# Use distroless nonroot user (uid=65532, gid=65532)
# This provides maximum security compliance
USER 65532:65532

# Run the binary
ENTRYPOINT ["/usr/local/bin/pod-monitor"]
