#!/bin/bash

# Brochure CLI Build Script
# Generates statically-linked binaries for distribution

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/brochure-cli"
VERSION="${1:-latest}"
PRODUCT_NAME="Brochure"

# S3 Configuration for CLI binary hosting
S3_BUCKET="${S3_BUCKET:-cli.neonlaw.com}"
S3_PREFIX="${S3_PREFIX:-brochure}"
UPLOAD_TO_S3="${UPLOAD_TO_S3:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Cleanup function
cleanup() {
    if [[ -n "${BUILD_PID:-}" ]]; then
        kill "$BUILD_PID" 2>/dev/null || true
    fi

    # Cleanup build files if they exist
    cleanup_build_files 2>/dev/null || true
}
trap cleanup EXIT

# Cleanup function to restore original files
cleanup_build_files() {
    local ORIGINAL_VERSION_FILE="$PROJECT_ROOT/Sources/Brochure/Models/VersionInfo.swift"
    local TEMP_VERSION_FILE="$PROJECT_ROOT/Sources/Brochure/Models/VersionInfo.swift.temp"
    local BUILD_VERSION_FILE="$PROJECT_ROOT/Sources/Brochure/Models/BuildVersionInfo.swift"

    # Restore original VersionInfo.swift if temp exists
    if [[ -f "$TEMP_VERSION_FILE" ]]; then
        mv "$TEMP_VERSION_FILE" "$ORIGINAL_VERSION_FILE"
    fi

    # Remove generated BuildVersionInfo.swift
    if [[ -f "$BUILD_VERSION_FILE" ]]; then
        rm -f "$BUILD_VERSION_FILE"
    fi

    # Remove sed backup file
    if [[ -f "$ORIGINAL_VERSION_FILE.bak" ]]; then
        rm -f "$ORIGINAL_VERSION_FILE.bak"
    fi
}

# Check dependencies
check_dependencies() {
    log_step "Checking dependencies..."

    # Check Swift
    if ! command -v swift &> /dev/null; then
        log_error "Swift is not installed or not in PATH"
        exit 1
    fi

    # Check Git (for version info)
    if ! command -v git &> /dev/null; then
        log_error "Git is not installed or not in PATH"
        exit 1
    fi

    # Check if we're in a git repository
    if ! git rev-parse --git-dir &> /dev/null; then
        log_error "Not in a git repository"
        exit 1
    fi

    log_info "All dependencies satisfied"
}

# Get version information
get_version_info() {
    log_step "Gathering version information..."

    # Read version from VERSION file if version is "latest"
    if [[ "$VERSION" == "latest" ]]; then
        if [[ -f "$PROJECT_ROOT/VERSION" ]]; then
            VERSION=$(cat "$PROJECT_ROOT/VERSION" | tr -d '\n\r')
            log_info "Read version from VERSION file: $VERSION"
        else
            log_warn "VERSION file not found, using git describe"
            VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "0.1.0-dev")
        fi
    fi

    # Get git information
    GIT_COMMIT=$(git rev-parse HEAD)
    GIT_SHORT_COMMIT=$(git rev-parse --short=8 HEAD)
    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

    # Check if working directory is clean
    GIT_DIRTY="false"
    if ! git diff-index --quiet HEAD --; then
        log_warn "Working directory has uncommitted changes"
        GIT_DIRTY="true"
    fi

    # Get current date
    BUILD_DATE=$(date -u +"%Y-%m-%d")
    BUILD_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Get Swift version
    SWIFT_VERSION=$(swift --version 2>/dev/null | head -n 1 | sed 's/.*Swift version //' | sed 's/ .*//' || echo "unknown")

    # Get compiler information
    COMPILER_VERSION="Swift $SWIFT_VERSION"

    log_info "Version: $VERSION"
    log_info "Git commit: $GIT_SHORT_COMMIT"
    log_info "Git branch: $GIT_BRANCH"
    log_info "Git dirty: $GIT_DIRTY"
    log_info "Build date: $BUILD_DATE"
    log_info "Swift version: $SWIFT_VERSION"
}

# Detect platform and architecture
detect_platform() {
    log_step "Detecting platform and architecture..."

    local OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    local ARCH=$(uname -m)

    case "$OS" in
        darwin)
            PLATFORM="darwin"
            ;;
        linux)
            PLATFORM="linux"
            ;;
        *)
            log_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac

    case "$ARCH" in
        x86_64)
            ARCHITECTURE="x64"
            ;;
        arm64|aarch64)
            ARCHITECTURE="arm64"
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    PLATFORM_ARCH="${PLATFORM}-${ARCHITECTURE}"

    log_info "Platform: $PLATFORM"
    log_info "Architecture: $ARCHITECTURE"
    log_info "Platform-Architecture: $PLATFORM_ARCH"
}

# Clean build directory
clean_build_directory() {
    log_step "Cleaning build directory..."

    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR/$VERSION/$PLATFORM_ARCH"

    log_info "Build directory cleaned: $BUILD_DIR"
}

# Build binary for current platform
build_binary() {
    log_step "Building Brochure CLI binary..."

    cd "$PROJECT_ROOT"

    local BUILD_CONFIG="release"
    local OUTPUT_DIR="$BUILD_DIR/$VERSION/$PLATFORM_ARCH"

    # Create a temporary version of VersionInfo.swift with build-time constants
    log_info "Generating version constants..."
    local ORIGINAL_VERSION_FILE="$PROJECT_ROOT/Sources/Brochure/Models/VersionInfo.swift"
    local TEMP_VERSION_FILE="$PROJECT_ROOT/Sources/Brochure/Models/VersionInfo.swift.temp"

    # Copy original file
    cp "$ORIGINAL_VERSION_FILE" "$TEMP_VERSION_FILE"

    # Replace the currentVersion initialization with build-time constants
    cat > "$PROJECT_ROOT/Sources/Brochure/Models/BuildVersionInfo.swift" <<EOF
// This file is auto-generated by build-brochure-cli.sh
// DO NOT EDIT MANUALLY - It will be removed after build

import Foundation

/// Build-time version information (overrides currentVersion)
internal let buildTimeVersionInfo = VersionInfo(
    version: "$VERSION",
    gitCommit: "$GIT_COMMIT",
    gitBranch: "$GIT_BRANCH",
    gitDirty: $GIT_DIRTY,
    platform: "$PLATFORM",
    architecture: "$ARCHITECTURE",
    buildConfiguration: "$BUILD_CONFIG",
    swiftVersion: "$SWIFT_VERSION",
    compiler: "$COMPILER_VERSION"
)
EOF

    # Replace currentVersion to use build-time info
    sed -i.bak '/^public let currentVersion: VersionInfo = {$/,/^}()$/c\
/// Current version information for this build.\
/// This is populated by the build system with actual build-time values.\
public let currentVersion: VersionInfo = buildTimeVersionInfo
' "$ORIGINAL_VERSION_FILE"

    if [[ "$PLATFORM" == "darwin" ]]; then
        # macOS build (static stdlib is no longer supported on macOS)
        log_info "Building for macOS with standard linking..."
        swift build \
            -c "$BUILD_CONFIG" \
            --product "$PRODUCT_NAME"

    elif [[ "$PLATFORM" == "linux" ]]; then
        # Linux build with static linking
        log_info "Building for Linux with static linking..."
        swift build \
            -c "$BUILD_CONFIG" \
            --product "$PRODUCT_NAME" \
            -Xswiftc -static-executable
    else
        log_error "Unsupported platform for building: $PLATFORM"
        exit 1
    fi

    # Copy binary to output directory
    local BUILT_BINARY=".build/release/$PRODUCT_NAME"
    local OUTPUT_BINARY="$OUTPUT_DIR/brochure"

    if [[ ! -f "$BUILT_BINARY" ]]; then
        log_error "Built binary not found at: $BUILT_BINARY"
        exit 1
    fi

    cp "$BUILT_BINARY" "$OUTPUT_BINARY"
    chmod +x "$OUTPUT_BINARY"

    log_info "Binary copied to: $OUTPUT_BINARY"
}

# Generate checksums
generate_checksums() {
    log_step "Generating checksums..."

    local OUTPUT_DIR="$BUILD_DIR/$VERSION/$PLATFORM_ARCH"
    local BINARY_PATH="$OUTPUT_DIR/brochure"

    # Generate SHA256 checksum
    if command -v sha256sum &> /dev/null; then
        # Linux
        SHA256_HASH=$(sha256sum "$BINARY_PATH" | cut -d' ' -f1)
    elif command -v shasum &> /dev/null; then
        # macOS
        SHA256_HASH=$(shasum -a 256 "$BINARY_PATH" | cut -d' ' -f1)
    else
        log_error "No SHA256 utility found (sha256sum or shasum)"
        exit 1
    fi

    # Save checksum to file
    echo "$SHA256_HASH" > "$OUTPUT_DIR/brochure.sha256"

    log_info "SHA256: $SHA256_HASH"
    log_info "Checksum saved to: $OUTPUT_DIR/brochure.sha256"
}

# Generate metadata
generate_metadata() {
    log_step "Generating metadata..."

    local OUTPUT_DIR="$BUILD_DIR/$VERSION/$PLATFORM_ARCH"
    local METADATA_FILE="$OUTPUT_DIR/metadata.json"
    local BINARY_PATH="$OUTPUT_DIR/brochure"

    # Get binary size
    local BINARY_SIZE=$(stat -f%z "$BINARY_PATH" 2>/dev/null || stat -c%s "$BINARY_PATH" 2>/dev/null || echo "0")

    # Read checksum
    local SHA256_HASH=$(cat "$OUTPUT_DIR/brochure.sha256")

    # Parse semantic version
    local MAJOR_VERSION=$(echo "$VERSION" | cut -d. -f1 | sed 's/v//')
    local MINOR_VERSION=$(echo "$VERSION" | cut -d. -f2 2>/dev/null || echo "0")
    local PATCH_VERSION=$(echo "$VERSION" | cut -d. -f3 2>/dev/null | cut -d- -f1 || echo "0")

    # Extract pre-release and build metadata if present
    local PRE_RELEASE=""
    local BUILD_METADATA=""
    if [[ "$VERSION" == *"-"* ]]; then
        PRE_RELEASE=$(echo "$VERSION" | cut -d- -f2- | cut -d+ -f1)
    fi
    if [[ "$VERSION" == *"+"* ]]; then
        BUILD_METADATA=$(echo "$VERSION" | cut -d+ -f2-)
    fi

    # Generate comprehensive metadata JSON
    cat > "$METADATA_FILE" <<EOF
{
  "version": "$VERSION",
  "major_version": $MAJOR_VERSION,
  "minor_version": $MINOR_VERSION,
  "patch_version": $PATCH_VERSION,$(if [[ -n "$PRE_RELEASE" ]]; then echo "
  \"pre_release\": \"$PRE_RELEASE\","; fi)$(if [[ -n "$BUILD_METADATA" ]]; then echo "
  \"build_metadata\": \"$BUILD_METADATA\","; fi)
  "git_commit": "$GIT_COMMIT",
  "git_short_commit": "$GIT_SHORT_COMMIT",
  "git_branch": "$GIT_BRANCH",
  "git_dirty": $GIT_DIRTY,
  "build_date": "$BUILD_DATE",
  "build_timestamp": "$BUILD_TIMESTAMP",
  "platform": "$PLATFORM",
  "architecture": "$ARCHITECTURE",
  "platform_arch": "$PLATFORM_ARCH",
  "build_configuration": "release",
  "swift_version": "$SWIFT_VERSION",
  "compiler_version": "$COMPILER_VERSION",
  "binary_name": "brochure",
  "binary_size": $BINARY_SIZE,
  "sha256": "$SHA256_HASH",
  "download_url": "https://cli.neonlaw.com/brochure/$VERSION/$PLATFORM_ARCH/brochure",
  "checksum_url": "https://cli.neonlaw.com/brochure/$VERSION/$PLATFORM_ARCH/brochure.sha256",
  "metadata_url": "https://cli.neonlaw.com/brochure/$VERSION/$PLATFORM_ARCH/metadata.json"
}
EOF

    log_info "Metadata saved to: $METADATA_FILE"
}

# Verify binary
verify_binary() {
    log_step "Verifying binary..."

    local OUTPUT_DIR="$BUILD_DIR/$VERSION/$PLATFORM_ARCH"
    local BINARY_PATH="$OUTPUT_DIR/brochure"

    # Test that binary is executable
    if [[ ! -x "$BINARY_PATH" ]]; then
        log_error "Binary is not executable: $BINARY_PATH"
        exit 1
    fi

    # Test basic execution
    log_info "Testing binary execution..."
    if ! "$BINARY_PATH" --help &> /dev/null; then
        log_error "Binary failed to execute basic --help command"
        exit 1
    fi

    # Verify checksum
    log_info "Verifying checksum..."
    local EXPECTED_SHA256=$(cat "$OUTPUT_DIR/brochure.sha256")
    local ACTUAL_SHA256

    if command -v sha256sum &> /dev/null; then
        ACTUAL_SHA256=$(sha256sum "$BINARY_PATH" | cut -d' ' -f1)
    else
        ACTUAL_SHA256=$(shasum -a 256 "$BINARY_PATH" | cut -d' ' -f1)
    fi

    if [[ "$EXPECTED_SHA256" != "$ACTUAL_SHA256" ]]; then
        log_error "Checksum verification failed!"
        log_error "Expected: $EXPECTED_SHA256"
        log_error "Actual: $ACTUAL_SHA256"
        exit 1
    fi

    log_info "Binary verification successful!"
}

# Upload binary and metadata to S3
upload_to_s3() {
    if [[ "$UPLOAD_TO_S3" != "true" ]]; then
        log_info "Skipping S3 upload (UPLOAD_TO_S3 not set to 'true')"
        return 0
    fi

    log_step "Uploading binary to S3..."

    local OUTPUT_DIR="$BUILD_DIR/$VERSION/$PLATFORM_ARCH"
    local S3_VERSION_PATH="s3://$S3_BUCKET/$S3_PREFIX/$VERSION/$PLATFORM_ARCH"

    # Check if AWS CLI is available
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed or not in PATH"
        log_error "Install AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured or invalid"
        log_error "Run 'aws configure' or set AWS_PROFILE environment variable"
        exit 1
    fi

    local aws_identity=$(aws sts get-caller-identity --output text --query 'Arn' 2>/dev/null || echo "unknown")
    log_info "Using AWS identity: $aws_identity"

    # Upload binary with specific content type and metadata
    log_info "Uploading binary: $OUTPUT_DIR/brochure -> $S3_VERSION_PATH/brochure"
    aws s3 cp "$OUTPUT_DIR/brochure" "$S3_VERSION_PATH/brochure" \
        --content-type "application/octet-stream" \
        --metadata "version=$VERSION,platform=$PLATFORM,architecture=$ARCHITECTURE,build-date=$BUILD_DATE" \
        --no-progress

    # Upload checksum file
    log_info "Uploading checksum: $OUTPUT_DIR/brochure.sha256 -> $S3_VERSION_PATH/brochure.sha256"
    aws s3 cp "$OUTPUT_DIR/brochure.sha256" "$S3_VERSION_PATH/brochure.sha256" \
        --content-type "text/plain" \
        --no-progress

    # Upload metadata
    log_info "Uploading metadata: $OUTPUT_DIR/metadata.json -> $S3_VERSION_PATH/metadata.json"
    aws s3 cp "$OUTPUT_DIR/metadata.json" "$S3_VERSION_PATH/metadata.json" \
        --content-type "application/json" \
        --no-progress

    # Create version-agnostic "latest" symlinks for the current platform
    local S3_LATEST_PATH="s3://$S3_BUCKET/$S3_PREFIX/latest/$PLATFORM_ARCH"

    log_info "Creating latest symlinks for $PLATFORM_ARCH..."

    # Copy to latest (S3 doesn't have symlinks, so we copy)
    aws s3 cp "$S3_VERSION_PATH/brochure" "$S3_LATEST_PATH/brochure" \
        --content-type "application/octet-stream" \
        --metadata "version=$VERSION,platform=$PLATFORM,architecture=$ARCHITECTURE,build-date=$BUILD_DATE,latest=true" \
        --no-progress

    aws s3 cp "$S3_VERSION_PATH/brochure.sha256" "$S3_LATEST_PATH/brochure.sha256" \
        --content-type "text/plain" \
        --no-progress

    aws s3 cp "$S3_VERSION_PATH/metadata.json" "$S3_LATEST_PATH/metadata.json" \
        --content-type "application/json" \
        --no-progress

    # Generate and upload version index
    generate_version_index

    log_info "✅ Successfully uploaded binary to S3!"
    log_info "📄 Download URLs:"
    log_info "   Version-specific: https://$S3_BUCKET/$S3_PREFIX/$VERSION/$PLATFORM_ARCH/brochure"
    log_info "   Latest: https://$S3_BUCKET/$S3_PREFIX/latest/$PLATFORM_ARCH/brochure"
    log_info "   Metadata: https://$S3_BUCKET/$S3_PREFIX/$VERSION/$PLATFORM_ARCH/metadata.json"
    log_info "   Checksum: https://$S3_BUCKET/$S3_PREFIX/$VERSION/$PLATFORM_ARCH/brochure.sha256"
}

# Generate and upload version index
generate_version_index() {
    log_step "Generating version index..."

    local INDEX_FILE="$BUILD_DIR/index.json"
    local S3_INDEX_PATH="s3://$S3_BUCKET/$S3_PREFIX/index.json"

    # Create a comprehensive index of all available versions
    cat > "$INDEX_FILE" <<EOF
{
  "service": "brochure-cli",
  "repository": "https://github.com/neon-law-foundation/Luxe",
  "last_updated": "$BUILD_TIMESTAMP",
  "latest_version": "$VERSION",
  "platforms": ["darwin-arm64", "darwin-x64", "linux-arm64", "linux-x64"],
  "download_urls": {
    "latest": {
      "darwin-arm64": "https://$S3_BUCKET/$S3_PREFIX/latest/darwin-arm64/brochure",
      "darwin-x64": "https://$S3_BUCKET/$S3_PREFIX/latest/darwin-x64/brochure",
      "linux-arm64": "https://$S3_BUCKET/$S3_PREFIX/latest/linux-arm64/brochure",
      "linux-x64": "https://$S3_BUCKET/$S3_PREFIX/latest/linux-x64/brochure"
    },
    "versioned": "https://$S3_BUCKET/$S3_PREFIX/{version}/{platform}/brochure"
  },
  "checksums": {
    "latest": {
      "darwin-arm64": "https://$S3_BUCKET/$S3_PREFIX/latest/darwin-arm64/brochure.sha256",
      "darwin-x64": "https://$S3_BUCKET/$S3_PREFIX/latest/darwin-x64/brochure.sha256",
      "linux-arm64": "https://$S3_BUCKET/$S3_PREFIX/latest/linux-arm64/brochure.sha256",
      "linux-x64": "https://$S3_BUCKET/$S3_PREFIX/latest/linux-x64/brochure.sha256"
    },
    "versioned": "https://$S3_BUCKET/$S3_PREFIX/{version}/{platform}/brochure.sha256"
  },
  "metadata": {
    "latest": {
      "darwin-arm64": "https://$S3_BUCKET/$S3_PREFIX/latest/darwin-arm64/metadata.json",
      "darwin-x64": "https://$S3_BUCKET/$S3_PREFIX/latest/darwin-x64/metadata.json",
      "linux-arm64": "https://$S3_BUCKET/$S3_PREFIX/latest/linux-arm64/metadata.json",
      "linux-x64": "https://$S3_BUCKET/$S3_PREFIX/latest/linux-x64/metadata.json"
    },
    "versioned": "https://$S3_BUCKET/$S3_PREFIX/{version}/{platform}/metadata.json"
  },
  "installation": {
    "curl_install": "curl -fsSL https://$S3_BUCKET/$S3_PREFIX/install.sh | sh",
    "manual_steps": [
      "1. Download: curl -L -o brochure https://$S3_BUCKET/$S3_PREFIX/latest/\\$(uname -s | tr '[:upper:]' '[:lower:]')-\\$(uname -m | sed 's/x86_64/x64/; s/aarch64/arm64/')/brochure",
      "2. Verify: curl -L https://$S3_BUCKET/$S3_PREFIX/latest/\\$(uname -s | tr '[:upper:]' '[:lower:]')-\\$(uname -m | sed 's/x86_64/x64/; s/aarch64/arm64/')/brochure.sha256 | shasum -a 256 -c",
      "3. Install: chmod +x brochure && sudo mv brochure /usr/local/bin/"
    ]
  },
  "current_build": {
    "version": "$VERSION",
    "platform": "$PLATFORM_ARCH",
    "build_date": "$BUILD_DATE",
    "git_commit": "$GIT_SHORT_COMMIT",
    "git_branch": "$GIT_BRANCH"
  }
}
EOF

    # Upload index
    log_info "Uploading version index: $S3_INDEX_PATH"
    aws s3 cp "$INDEX_FILE" "$S3_INDEX_PATH" \
        --content-type "application/json" \
        --no-progress

    log_info "Version index available at: https://$S3_BUCKET/$S3_PREFIX/index.json"
}

# Display build summary
display_summary() {
    log_step "Build Summary"

    local OUTPUT_DIR="$BUILD_DIR/$VERSION/$PLATFORM_ARCH"
    local BINARY_PATH="$OUTPUT_DIR/brochure"
    local BINARY_SIZE=$(stat -f%z "$BINARY_PATH" 2>/dev/null || stat -c%s "$BINARY_PATH" 2>/dev/null || echo "0")

    # Format binary size
    local FORMATTED_SIZE
    if [[ $BINARY_SIZE -gt 1048576 ]]; then
        FORMATTED_SIZE="$(echo "scale=1; $BINARY_SIZE / 1048576" | bc)MB"
    elif [[ $BINARY_SIZE -gt 1024 ]]; then
        FORMATTED_SIZE="$(echo "scale=1; $BINARY_SIZE / 1024" | bc)KB"
    else
        FORMATTED_SIZE="${BINARY_SIZE}B"
    fi

    echo
    log_info "✅ Build completed successfully!"
    echo
    echo "📋 Build Details:"
    echo "   Version: $VERSION"
    echo "   Platform: $PLATFORM_ARCH"
    echo "   Git Commit: $GIT_SHORT_COMMIT"
    echo "   Binary Size: $FORMATTED_SIZE"
    echo "   Output Directory: $OUTPUT_DIR"
    echo
    echo "📁 Generated Files:"
    echo "   • brochure (executable)"
    echo "   • brochure.sha256 (checksum)"
    echo "   • metadata.json (build info)"
    echo
    echo "🧪 Test the binary:"
    echo "   $BINARY_PATH --help"
    echo "   $BINARY_PATH upload --help"
    echo
}

# Usage information
usage() {
    echo "Usage: $0 [VERSION]"
    echo
    echo "Build statically-linked Brochure CLI binary for distribution"
    echo
    echo "Arguments:"
    echo "  VERSION    Version tag (defaults to 'latest')"
    echo
    echo "Environment Variables:"
    echo "  UPLOAD_TO_S3    Set to 'true' to upload binary to S3 (default: 'false')"
    echo "  S3_BUCKET       S3 bucket for hosting (default: 'cli.neonlaw.com')"
    echo "  S3_PREFIX       S3 key prefix (default: 'brochure')"
    echo "  AWS_PROFILE     AWS profile to use for S3 upload"
    echo
    echo "Examples:"
    echo "  $0                                    # Build with 'latest' version"
    echo "  $0 v1.0.0                            # Build with specific version"
    echo "  $0 \$(git describe)                    # Build with git describe version"
    echo "  UPLOAD_TO_S3=true $0 v1.0.0          # Build and upload to S3"
    echo "  AWS_PROFILE=production UPLOAD_TO_S3=true $0 v1.0.0  # Upload with specific AWS profile"
    echo
    echo "Output:"
    echo "  build/brochure-cli/VERSION/PLATFORM-ARCH/"
    echo "    ├── brochure         (executable binary)"
    echo "    ├── brochure.sha256  (SHA256 checksum)"
    echo "    └── metadata.json    (build metadata)"
    echo
    echo "S3 Upload Structure (when UPLOAD_TO_S3=true):"
    echo "  s3://S3_BUCKET/S3_PREFIX/"
    echo "    ├── VERSION/PLATFORM-ARCH/"
    echo "    │   ├── brochure"
    echo "    │   ├── brochure.sha256"
    echo "    │   └── metadata.json"
    echo "    ├── latest/PLATFORM-ARCH/"
    echo "    │   ├── brochure"
    echo "    │   ├── brochure.sha256"
    echo "    │   └── metadata.json"
    echo "    └── index.json       (version index)"
    echo
}

# Main function
main() {
    # Handle help flag
    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        usage
        exit 0
    fi

    log_info "🚀 Starting Brochure CLI build process..."
    echo

    check_dependencies
    get_version_info
    detect_platform
    clean_build_directory
    build_binary
    generate_checksums
    generate_metadata
    verify_binary
    upload_to_s3
    display_summary

    # Clean up temporary build files
    cleanup_build_files
    log_info "Cleaned up temporary build files"

    log_info "🎉 Build process completed successfully!"
}

# Run main function
main "$@"
