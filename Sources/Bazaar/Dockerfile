FROM swift:6.1-bookworm AS builder

# Build-time arguments for version information
ARG GIT_COMMIT
ARG GIT_TAG
ARG BUILD_DATE

WORKDIR /app

# Copy Package files first for better caching
COPY Package.swift Package.resolved ./

# Resolve dependencies first
RUN swift package resolve

# Copy source files
COPY Sources/ ./Sources/
COPY Tests/ ./Tests/

# Build with memory optimizations:
# - Use -j 1 to limit concurrent compilation jobs (reduces peak memory usage)
# - Build products separately to avoid loading all dependencies at once
# - Use --disable-sandbox to reduce overhead
# - Set SWIFT_BUILD_FLAGS for additional memory control
ENV SWIFT_BUILD_FLAGS="-Xswiftc -stats-output-dir -Xswiftc /tmp/stats"
RUN swift build -c release --product Palette --static-swift-stdlib -j 1 --disable-sandbox
RUN swift build -c release --product Bazaar --static-swift-stdlib -j 1 --disable-sandbox

# Runtime stage
FROM debian:bookworm-slim

# Version information from build stage
ARG GIT_COMMIT
ARG GIT_TAG
ARG BUILD_DATE

# Set version environment variables
ENV GIT_COMMIT=${GIT_COMMIT}
ENV GIT_TAG=${GIT_TAG}
ENV BUILD_DATE=${BUILD_DATE}

# Label the image with metadata
LABEL org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.version="${GIT_TAG}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.title="Bazaar" \
      org.opencontainers.image.description="Bazaar unified service"

# Install ca-certificates and download RDS CA certificate bundle
# This is required for PostgresNIO's .makeClientConfiguration() which uses system certificates
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl && \
    curl -sS -o /usr/local/share/ca-certificates/rds-ca-bundle.crt https://truststore.pki.rds.amazonaws.com/us-west-2/us-west-2-bundle.pem && \
    update-ca-certificates && \
    apt-get remove -y curl && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV ENV=PRODUCTION

# Copy the built executables
COPY --from=builder /app/.build/release/Bazaar /app/Bazaar
COPY --from=builder /app/.build/release/Palette /app/Palette

# Copy the built resources containing resources
COPY --from=builder /app/.build/release/Luxe_Bazaar.resources/ /app/Luxe_Bazaar.resources/
COPY --from=builder /app/.build/release/Luxe_Palette.resources/ /app/Luxe_Palette.resources/

# Copy Palette-specific files that aren't in the bundle
COPY --from=builder /app/Sources/Palette/Migrations /app/Sources/Palette/Migrations

# Copy Public files (favicons, etc.) that aren't in the bundle
COPY --from=builder /app/Sources/Bazaar/Public /app/Sources/Bazaar/Public

# Copy Markdown files for blog posts
COPY --from=builder /app/Sources/Bazaar/Markdown /app/Sources/Bazaar/Markdown

EXPOSE 8080

# Create a shell script to run Palette migrations, seeds, and then start Bazaar
RUN echo '#!/bin/sh\nset -e\n./Palette migrate\n./Palette seeds\n./Bazaar' > /app/start.sh && \
    chmod +x /app/start.sh

CMD ["/app/start.sh"]
