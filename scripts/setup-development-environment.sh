#!/bin/bash

# Luxe Development Environment Setup
# This script sets up a macOS machine for local development

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored headers
print_header() {
    echo -e "\n${BLUE}======================================"
    echo -e "$1"
    echo -e "======================================${NC}"
}

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a service is running
check_service() {
    local service_name=$1
    local port=$2
    local max_attempts=30
    local attempt=1

    echo "⏳ Waiting for $service_name to be ready on port $port..."

    while ! nc -z localhost $port; do
        if [ $attempt -eq $max_attempts ]; then
            print_error "$service_name failed to start after $max_attempts attempts"
            return 1
        fi
        echo "   Attempt $attempt/$max_attempts - $service_name not ready yet..."
        sleep 2
        ((attempt++))
    done

    print_status "$service_name is ready"
    return 0
}

echo -e "${YELLOW}🚀 Setting up Luxe Development Environment${NC}"
echo "This script will install and configure everything needed for local development."

# Step 1: Check Prerequisites
print_header "🔧 Checking Prerequisites"

# Check for macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script is designed for macOS only"
    exit 1
fi
print_status "Running on macOS"

# Check for Swift
if ! command_exists swift; then
    print_error "Swift not found. Please install Xcode or Swift toolchain first."
    exit 1
fi
print_status "Swift found"

# Check for Docker
if ! command_exists docker; then
    print_error "Docker not found. Please install Docker Desktop first."
    echo "Download from: https://www.docker.com/products/docker-desktop"
    exit 1
fi
print_status "Docker found"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker Desktop first."
    exit 1
fi
print_status "Docker is running"

# Step 2: Install Dependencies via Homebrew
print_header "🍺 Installing Dependencies via Homebrew"

# Check for Homebrew
if ! command_exists brew; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    print_status "Homebrew installed"
else
    print_status "Homebrew already installed"
fi

# Install dependencies
echo "Installing required packages..."
brew install pandoc \
  chromedriver \
  postgresql \
  gh \
  yq \
  netcat

print_status "All Homebrew dependencies installed"

# Step 3: Setup Git Hooks
print_header "🪝 Setting up Git Hooks"

# Check if .githooks directory exists
if [ -d ".githooks" ]; then
    for hook in .githooks/*; do
        if [ -f "$hook" ]; then
            hook_name=$(basename "$hook")
            echo "Installing $hook_name hook..."
            cp "$hook" ".git/hooks/$hook_name"
            chmod +x ".git/hooks/$hook_name"
        fi
    done
    print_status "Git hooks installed successfully"
else
    print_warning "No .githooks directory found - skipping git hooks setup"
fi

# Step 4: Start Docker Services
print_header "🐳 Starting Docker Services"

echo "Starting PostgreSQL, Dex, and LocalStack..."
docker-compose up -d postgres dex localstack

# Wait for services to be ready
check_service "PostgreSQL" 5432
check_service "Dex" 2222
check_service "LocalStack" 4566

print_status "All Docker services are running"

# Step 5: Setup Dex
print_header "🔐 Setting up Dex"

echo "Configuring Dex identity provider..."
./scripts/setup-dex.sh

print_status "Dex setup complete"

# Step 6: Run Database Migrations
print_header "💾 Running Database Migrations"

echo "Running Palette migrations..."
swift run Palette migrate

print_status "Database migrations complete"

# Step 7: Verify Installation
print_header "✅ Verifying Installation"

# Test Swift build
echo "Testing Swift build..."
if swift build > /dev/null 2>&1; then
    print_status "Swift build successful"
else
    print_error "Swift build failed - please check your setup"
fi

# Test Docker services
echo "Verifying Docker services..."
if curl -f http://localhost:2222/realms/master > /dev/null 2>&1; then
    print_status "Keycloak is responding"
else
    print_warning "Keycloak may not be fully ready yet"
fi

if docker-compose ps | grep -q "Up"; then
    print_status "Docker services are running"
else
    print_warning "Some Docker services may not be running properly"
fi

echo "Configuring context7 MCP server for Claude Code.."
claude mcp add --transport sse context7 https://mcp.context7.com/sse

echo ""
echo "Configuring OpenAI deep research MCP server for Claude Code.."
echo -e "${YELLOW}This requires an OpenAI API key for deep research capabilities.${NC}"
read -p "Enter your OpenAI API key (or press Enter to skip): " OPENAI_API_KEY

if [ -n "$OPENAI_API_KEY" ]; then
    claude mcp add openai-deep-research -s user npx github:fbettag/openai-deep-research-mcp -e OPENAI_API_KEY=$OPENAI_API_KEY
    echo -e "${GREEN}✓ OpenAI deep research MCP server configured${NC}"
else
    echo -e "${YELLOW}⚠ Skipping OpenAI deep research MCP server (no API key provided)${NC}"
fi

# Final Success Message
print_header "🎉 Development Environment Setup Complete!"

echo ""
echo -e "${GREEN}Your Luxe development environment is ready!${NC}"
echo ""
echo -e "${BLUE}What's been set up:${NC}"
echo "- ✅ Homebrew dependencies (stripe, pandoc, chromedriver, etc.)"
echo "- ✅ Git hooks (if .githooks directory exists)"
echo "- ✅ Docker services (PostgreSQL, Dex, LocalStack)"
echo "- ✅ Dex identity provider with static users and luxe-client"
echo "- ✅ Database migrations"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Start any target: ${YELLOW}swift run TargetName${NC}"
echo "2. Test authentication: Navigate to ${YELLOW}http://localhost:8080/app/me${NC}"
echo "3. Login with: ${YELLOW}admin@neonlaw.com / Vegas702!${NC}"
echo ""
echo -e "${BLUE}Service URLs:${NC}"
echo "- Dex Login UI: http://localhost:2222/dex/auth (static users configured)"
echo "- PostgreSQL: localhost:5432"
echo "- LocalStack: http://localhost:4566"
echo ""
echo -e "${BLUE}Common commands:${NC}"
echo "- Run tests: swift test"
echo "- Start Bazaar: swift run Bazaar"
echo "- Run migrations: swift run Palette migrate"
echo "- Integration tests: ./scripts/run-integration-tests.sh"
echo ""
echo -e "${YELLOW}Happy coding! 🚀${NC}"
