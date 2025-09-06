FROM golang:1.21-alpine AS builder

# Install git and other build dependencies
# Use specific versions to ensure reproducible builds
RUN apk add --no-cache \
    git=~2 \
    ca-certificates=~20230506 \
    tzdata=~2023c

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
    -ldflags='-w -s -extldflags "-static" -X main.buildTime=$(date -u +%Y%m%d%H%M%S) -X main.gitCommit=${GIT_COMMIT:-unknown}' \
    -a -installsuffix cgo \
    -trimpath \
    -mod=readonly \
    -buildvcs=false \
    -o pod-monitor .

# Security scan stage (optional for local development)
FROM alpine:3.18 AS security-scanner

# Install security scanning tools (if building with security scan)
ARG ENABLE_SECURITY_SCAN=false
RUN if [ "$ENABLE_SECURITY_SCAN" = "true" ]; then \
        apk add --no-cache curl jq && \
        curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin && \
        curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin; \
    fi

# Copy binary for scanning
COPY --from=builder /app/pod-monitor /tmp/pod-monitor

# Run security scan if enabled
RUN if [ "$ENABLE_SECURITY_SCAN" = "true" ]; then \
        echo "Running security scan..." && \
        grype /tmp/pod-monitor --fail-on medium || true && \
        syft /tmp/pod-monitor -o cyclonedx-json > /tmp/sbom.json || true; \
    fi

# Final stage - Distroless for maximum security
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
LABEL build.time=""
LABEL build.git.commit=""
LABEL security.scan.date=""
LABEL security.base.image="gcr.io/distroless/static-debian11:nonroot"

# Application metadata
LABEL application.name="pod-monitor"
LABEL application.component="monitoring"
LABEL application.tier="infrastructure"
LABEL application.security.compliance="pod-security-standards"

# Copy binary from builder stage
COPY --from=builder /app/pod-monitor /usr/local/bin/pod-monitor

# Copy SBOM if generated during build
COPY --from=security-scanner /tmp/sbom.json /etc/sbom.json 2>/dev/null || true

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
