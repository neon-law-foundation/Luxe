#!/bin/bash

# Script to run WebDriver authentication tests
# This script sets up the complete testing environment including:
# - PostgreSQL database
# - Keycloak authentication server
# - SagebrushWeb application
# - Safari WebDriver
# - Runs the WebDriver tests

set -e

echo "🚀 Starting WebDriver Authentication Tests"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if a service is running
check_service() {
    local service_name=$1
    local port=$2
    local max_attempts=30
    local attempt=1

    echo "⏳ Waiting for $service_name to be ready on port $port..."
    
    while ! nc -z localhost $port; do
        if [ $attempt -eq $max_attempts ]; then
            echo -e "${RED}❌ $service_name failed to start after $max_attempts attempts${NC}"
            return 1
        fi
        echo "   Attempt $attempt/$max_attempts - $service_name not ready yet..."
        sleep 2
        ((attempt++))
    done
    
    echo -e "${GREEN}✅ $service_name is ready${NC}"
    return 0
}

# Function to cleanup processes
cleanup() {
    echo "🧹 Cleaning up..."
    
    # Kill SagebrushWeb if running
    pkill -f SagebrushWeb || true
    
    # Stop Docker services
    docker-compose down || true
    
    echo "✅ Cleanup complete"
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Step 1: Start Docker services (PostgreSQL and Keycloak)
echo "📦 Starting Docker services..."
docker-compose up -d postgres keycloak

# Step 2: Wait for services to be ready
check_service "PostgreSQL" 5432
check_service "Keycloak" 2222

# Step 3: Setup Keycloak configuration
echo "🔧 Setting up Keycloak..."
./scripts/setup-keycloak.sh

# Step 4: Run database migrations
echo "💾 Running database migrations..."
swift run Palette migrate

# Step 5: Start SagebrushWeb in background
echo "🌿 Starting SagebrushWeb..."
swift run SagebrushWeb &
SAGEBRUSH_PID=$!

# Wait for SagebrushWeb to be ready
check_service "SagebrushWeb" 8080

# Step 6: Check if SafariDriver is available
echo "🧪 Checking SafariDriver..."
if ! command -v safaridriver &> /dev/null; then
    echo -e "${YELLOW}⚠️  SafariDriver not found in PATH${NC}"
    echo "To enable SafariDriver:"
    echo "1. Open Safari"
    echo "2. Go to Safari → Preferences → Advanced"
    echo "3. Check 'Show Develop menu in menu bar'"
    echo "4. Go to Develop → Allow Remote Automation"
    echo "5. Run: safaridriver --enable"
    exit 1
fi

# Step 7: Start SafariDriver
echo "🚗 Starting SafariDriver..."
safaridriver --port 4444 &
SAFARI_PID=$!

# Wait for SafariDriver to be ready
check_service "SafariDriver" 4444

# Step 8: Run the WebDriver tests
echo "🧪 Running WebDriver tests..."
echo -e "${YELLOW}Note: These tests are currently disabled by default${NC}"
echo -e "${YELLOW}To run them, remove the .disabled() attribute from the @Test annotations${NC}"

# For now, just run a build to verify everything compiles
swift test --build-tests --filter AuthenticationWebDriverTests

echo -e "${GREEN}🎉 WebDriver test setup complete!${NC}"
echo ""
echo "📋 Manual test steps:"
echo "1. Open Safari and navigate to http://localhost:8080"
echo "2. Click 'Log In' - should redirect to Keycloak"
echo "3. Login with username: shicholas, password: Vegas702!"
echo "4. Should redirect back to SagebrushWeb with 'Welcome, shicholas' and 'Log Out' button"
echo "5. Click 'Log Out' - should redirect to home with 'Log In' button"
echo "6. Try accessing http://localhost:8080/app/me - should redirect to Keycloak again"
echo ""
echo "🔧 To run actual WebDriver tests:"
echo "1. Edit Tests/SagebrushWebTests/AuthenticationWebDriverTests.swift"
echo "2. Remove .disabled() from @Test annotations"
echo "3. Run: swift test --filter AuthenticationWebDriverTests"
echo ""
echo "Services running:"
echo "- SagebrushWeb: http://localhost:8080"
echo "- Keycloak: http://localhost:2222"
echo "- PostgreSQL: localhost:5432"
echo "- SafariDriver: localhost:4444"
echo ""
echo "Press Ctrl+C to stop all services"

# Wait for user to interrupt
wait $SAGEBRUSH_PID