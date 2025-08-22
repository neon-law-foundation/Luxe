#!/bin/bash
# install-brochure-cli.sh - Install Brochure CLI
#
# This script automatically detects the platform and downloads the appropriate
# Brochure CLI binary from the official distribution site.
#
# Usage:
#   curl -fsSL https://cli.neonlaw.com/brochure/install.sh | bash
#   curl -fsSL https://cli.neonlaw.com/brochure/install.sh | bash -s v1.2.0
#   INSTALL_DIR=$HOME/.local/bin curl -fsSL https://cli.neonlaw.com/brochure/install.sh | bash

set -euo pipefail

# Configuration
BASE_URL="${BROCHURE_URL:-https://cli.neonlaw.com/brochure}"
VERSION="${1:-latest}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/bin}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect platform and architecture
detect_platform() {
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
            log_error "Supported platforms: macOS (darwin), Linux"
            exit 1
            ;;
    esac
    
    case "$ARCH" in
        x86_64|amd64)
            ARCH="x64"
            ;;
        arm64|aarch64)
            ARCH="arm64"
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            log_error "Supported architectures: x86_64, arm64"
            exit 1
            ;;
    esac
    
    # Use universal binary for macOS if available
    if [ "$PLATFORM" = "darwin" ]; then
        echo "darwin-universal"
    else
        echo "$PLATFORM-$ARCH"
    fi
}

# Check dependencies
check_dependencies() {
    log_step "Checking dependencies..."
    
    if ! command_exists curl; then
        log_error "curl is required but not installed"
        log_error "Please install curl and try again"
        exit 1
    fi
    
    # Check for shasum (macOS) or sha256sum (Linux)
    if [ "$PLATFORM" = "darwin" ]; then
        if ! command_exists shasum; then
            log_error "shasum is required but not installed"
            exit 1
        fi
        CHECKSUM_CMD="shasum -a 256"
    else
        if ! command_exists sha256sum; then
            log_error "sha256sum is required but not installed"
            exit 1
        fi
        CHECKSUM_CMD="sha256sum"
    fi
    
    log_info "Dependencies check passed"
}

# Download and verify binary
download_binary() {
    local PLATFORM_ARCH=$1
    local URL="$BASE_URL/$VERSION/$PLATFORM_ARCH/brochure"
    local CHECKSUM_URL="$BASE_URL/$VERSION/$PLATFORM_ARCH/brochure.sha256"
    local TEMP_DIR=$(mktemp -d)
    local BINARY_PATH="$TEMP_DIR/brochure"
    
    log_step "Downloading Brochure CLI..."
    log_info "Platform: $PLATFORM_ARCH"
    log_info "Version: $VERSION"
    log_info "URL: $URL"
    
    # Download binary
    if ! curl -fsSL -o "$BINARY_PATH" "$URL"; then
        log_error "Failed to download binary from $URL"
        log_error "Please check your internet connection and try again"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    log_info "Binary downloaded successfully"
    
    # Download and verify checksum
    log_step "Verifying checksum..."
    local EXPECTED_SHA
    if ! EXPECTED_SHA=$(curl -fsSL "$CHECKSUM_URL"); then
        log_error "Failed to download checksum from $CHECKSUM_URL"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    local ACTUAL_SHA
    if [ "$PLATFORM" = "darwin" ]; then
        ACTUAL_SHA=$(shasum -a 256 "$BINARY_PATH" | cut -d' ' -f1)
    else
        ACTUAL_SHA=$(sha256sum "$BINARY_PATH" | cut -d' ' -f1)
    fi
    
    if [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]; then
        log_error "Checksum verification failed!"
        log_error "Expected: $EXPECTED_SHA"
        log_error "Actual:   $ACTUAL_SHA"
        log_error "This could indicate a corrupted download or security issue"
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    log_info "Checksum verified successfully"
    log_info "Expected: $EXPECTED_SHA"
    log_info "Actual:   $ACTUAL_SHA"
    
    # Make executable
    chmod +x "$BINARY_PATH"
    
    echo "$BINARY_PATH"
}

# Install binary to target directory
install_binary() {
    local BINARY_PATH=$1
    local TARGET_PATH="$INSTALL_DIR/brochure"
    
    log_step "Installing binary..."
    
    # Check if we need sudo
    local SUDO=""
    if [ -w "$INSTALL_DIR" ]; then
        log_info "Installing to $TARGET_PATH"
    else
        log_warn "Installation requires sudo access to $INSTALL_DIR"
        SUDO="sudo"
    fi
    
    # Create install directory if it doesn't exist
    if [ ! -d "$INSTALL_DIR" ]; then
        log_info "Creating install directory: $INSTALL_DIR"
        $SUDO mkdir -p "$INSTALL_DIR"
    fi
    
    # Install binary
    if $SUDO mv "$BINARY_PATH" "$TARGET_PATH"; then
        log_info "Binary installed successfully to $TARGET_PATH"
    else
        log_error "Failed to install binary to $TARGET_PATH"
        exit 1
    fi
    
    # Set executable permissions (in case they were lost)
    $SUDO chmod +x "$TARGET_PATH"
}

# Verify installation
verify_installation() {
    local TARGET_PATH="$INSTALL_DIR/brochure"
    
    log_step "Verifying installation..."
    
    # Check if binary exists and is executable
    if [ ! -f "$TARGET_PATH" ]; then
        log_error "Binary not found at $TARGET_PATH"
        exit 1
    fi
    
    if [ ! -x "$TARGET_PATH" ]; then
        log_error "Binary is not executable: $TARGET_PATH"
        exit 1
    fi
    
    # Test binary execution
    local VERSION_OUTPUT
    if VERSION_OUTPUT=$("$TARGET_PATH" --version 2>/dev/null); then
        log_info "Installation verified successfully"
        log_info "Version: $VERSION_OUTPUT"
    else
        log_warn "Binary installed but version check failed"
        log_warn "This may indicate a compatibility issue"
    fi
    
    # Check if binary is in PATH
    if command_exists brochure; then
        log_info "✓ brochure command is available in PATH"
        
        # Test self-verification if the verify command exists
        if brochure verify --self >/dev/null 2>&1; then
            log_info "✓ Self-verification passed"
        else
            log_warn "Self-verification failed or not available"
        fi
    else
        log_warn "brochure command not found in PATH"
        log_warn "Add $INSTALL_DIR to your PATH or use full path: $TARGET_PATH"
        
        # Provide instructions to add to PATH
        case "$SHELL" in
            */bash)
                log_info "Add to PATH with: echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
                ;;
            */zsh)
                log_info "Add to PATH with: echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
                ;;
            */fish)
                log_info "Add to PATH with: fish_add_path $INSTALL_DIR"
                ;;
            *)
                log_info "Add $INSTALL_DIR to your PATH environment variable"
                ;;
        esac
    fi
}

# Print usage examples
print_usage_examples() {
    log_info ""
    log_info "🎉 Installation complete!"
    log_info ""
    log_info "Get started with:"
    log_info "  brochure --help"
    log_info ""
    log_info "Upload a website:"
    log_info "  brochure upload MySite"
    log_info ""
    log_info "Verify binary integrity:"
    log_info "  brochure verify --self"
    log_info ""
    log_info "Check version:"
    log_info "  brochure --version"
    log_info ""
    log_info "Bootstrap a new project:"
    log_info "  brochure bootstrap MyNewSite"
    log_info ""
}

# Cleanup function
cleanup() {
    if [ -n "${TEMP_DIR:-}" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Main installation function
main() {
    log_info "Brochure CLI Installer"
    log_info "====================="
    log_info ""
    
    # Check if already installed
    if command_exists brochure; then
        local CURRENT_VERSION
        CURRENT_VERSION=$(brochure --version 2>/dev/null || echo "unknown")
        log_warn "Brochure CLI is already installed: $CURRENT_VERSION"
        log_warn "This will overwrite the existing installation"
        
        # Give user a chance to cancel
        if [ -t 0 ] && [ -t 1 ]; then  # Check if running interactively
            echo -n "Continue? [y/N] "
            read -r REPLY
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_info "Installation cancelled"
                exit 0
            fi
        fi
    fi
    
    # Detect platform
    PLATFORM_ARCH=$(detect_platform)
    log_info "Detected platform: $PLATFORM_ARCH"
    
    # Extract platform for dependency checks
    PLATFORM=$(echo "$PLATFORM_ARCH" | cut -d'-' -f1)
    
    # Check dependencies
    check_dependencies
    
    # Download binary
    BINARY_PATH=$(download_binary "$PLATFORM_ARCH")
    
    # Install
    install_binary "$BINARY_PATH"
    
    # Verify
    verify_installation
    
    # Show usage examples
    print_usage_examples
    
    log_info "For documentation and support, visit:"
    log_info "  https://github.com/neon-law/Luxe"
}

# Run main function with all arguments
main "$@"