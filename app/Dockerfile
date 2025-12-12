# Stage 1: Build the Go application
FROM golang:1.21-alpine AS builder

# Set working directory
WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application with optimizations
# CGO_ENABLED=0 for static binary
# -ldflags="-w -s" to strip debug information and reduce binary size
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s" \
    -o simpletimeservice \
    main.go

# Stage 2: Create minimal runtime image
FROM gcr.io/distroless/static-debian12:nonroot

# Copy the binary from builder
COPY --from=builder /build/simpletimeservice /usr/local/bin/simpletimeservice

# Set non-root user (distroless nonroot user is 65532)
USER 65532:65532

# Expose port
EXPOSE 8080

# Set environment variables
ENV PORT=8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["/usr/local/bin/simpletimeservice", "--health-check"]

# Run the application
ENTRYPOINT ["/usr/local/bin/simpletimeservice"]

