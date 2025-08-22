FROM swift:6.1-bookworm AS builder

# Build-time arguments for version information
ARG GIT_COMMIT=unknown
ARG GIT_TAG=unknown
ARG BUILD_DATE=unknown

WORKDIR /app

# Copy Package files first for better caching
COPY Package.swift Package.resolved ./

# Clean up any existing SwiftPM cache to avoid HyperEnv issues
RUN rm -rf /root/.cache/org.swift.swiftpm

# Resolve dependencies first
RUN swift package resolve

# Copy source files
COPY Sources/ ./Sources/
COPY Tests/ ./Tests/

RUN swift build -c release --product Destined --static-swift-stdlib

# Runtime stage
FROM debian:bookworm-slim

# Version information from build stage
ARG GIT_COMMIT=unknown
ARG GIT_TAG=unknown
ARG BUILD_DATE=unknown

# Set version environment variables
ENV GIT_COMMIT=${GIT_COMMIT}
ENV GIT_TAG=${GIT_TAG}
ENV BUILD_DATE=${BUILD_DATE}

# Label the image with metadata
LABEL org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.version="${GIT_TAG}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.title="Destined" \
      org.opencontainers.image.description="Destined service"

# Install ca-certificates
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/.build/release/Destined .

# Set production environment
ENV ENV=PRODUCTION

# Copy public assets
COPY --from=builder /app/Sources/Destined/Public ./Sources/Destined/Public

EXPOSE 8080

CMD ["./Destined"]
