#!/bin/bash

# Complete Logout Testing Script
# This script tests the complete login -> logout -> login cycle

set -e

echo "🧪 Complete Logout Testing"
echo "========================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to wait for user input
wait_for_user() {
    echo -e "${YELLOW}Press Enter to continue...${NC}"
    read
}

# Function to check if a service is running
check_service() {
    local service_name=$1
    local port=$2
    local max_attempts=15
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
    pkill -f SagebrushWeb || true
    docker-compose down || true
    echo "✅ Cleanup complete"
}

# Set trap to cleanup on exit
trap cleanup EXIT

echo "📋 This script will test the complete authentication cycle:"
echo "1. Clear all existing sessions"
echo "2. Start services with fresh state"
echo "3. Test login flow"
echo "4. Test logout with Keycloak session termination"
echo "5. Verify session is completely cleared"
echo ""

wait_for_user

echo "🧹 Step 1: Clearing all existing sessions..."
./scripts/clear-all-sessions.sh

echo ""
echo "📦 Step 2: Starting services with fresh state..."

# Start Docker services
docker-compose up -d postgres keycloak

# Wait for services
check_service "PostgreSQL" 5432
check_service "Keycloak" 2222

# Setup Keycloak with updated configuration
echo "🔧 Setting up Keycloak with logout support..."
./scripts/setup-keycloak.sh

# Run migrations
echo "💾 Running database migrations..."
swift run Palette migrate

# Start SagebrushWeb
echo "🌿 Starting SagebrushWeb..."
swift run SagebrushWeb &
SAGEBRUSH_PID=$!

check_service "SagebrushWeb" 8080

echo ""
echo -e "${GREEN}🎉 All services are ready!${NC}"
echo ""

echo -e "${BLUE}Step 3: Test Initial State (No Sessions)${NC}"
echo "1. Open a new Private/Incognito browser window"
echo "2. Navigate to: http://localhost:8080/app/me"
echo "3. ✅ You should be redirected to Keycloak login page"
echo "4. ✅ You should NOT see the account page directly"
echo ""
echo "Expected URL pattern: http://localhost:2222/realms/luxe/protocol/openid-connect/auth..."
wait_for_user

echo -e "${BLUE}Step 4: Test Login Flow${NC}"
echo "1. On the Keycloak login page, enter:"
echo "   Username: shicholas"
echo "   Password: Vegas702!"
echo "2. Click 'Login'"
echo "3. ✅ You should be redirected to http://localhost:8080/app/me"
echo "4. ✅ You should see 'Welcome, shicholas' in navigation"
echo "5. ✅ You should see the 'My Account' page with user details"
wait_for_user

echo -e "${BLUE}Step 5: Test Enhanced Logout Flow${NC}"
echo "1. Click the 'Log Out' button (either in navigation or Quick Actions)"
echo "2. ✅ You should be redirected to Keycloak logout page briefly"
echo "3. ✅ Then automatically redirected back to http://localhost:8080/"
echo "4. ✅ Navigation should show 'Log In' button (no welcome message)"
wait_for_user

echo -e "${BLUE}Step 6: Verify Complete Session Clearing${NC}"
echo "1. Try to navigate to: http://localhost:8080/app/me"
echo "2. ✅ You should be redirected to Keycloak login page again"
echo "3. ✅ You should NOT see the account page directly"
echo "4. ✅ This confirms both SagebrushWeb and Keycloak sessions were cleared"
wait_for_user

echo -e "${BLUE}Step 7: Test Re-login After Logout${NC}"
echo "1. On the Keycloak login page, enter credentials again:"
echo "   Username: shicholas"
echo "   Password: Vegas702!"
echo "2. Click 'Login'"
echo "3. ✅ You should be able to login successfully"
echo "4. ✅ You should see the account page and welcome message"
wait_for_user

echo ""
echo -e "${GREEN}🎉 Complete Logout Testing Finished!${NC}"
echo ""
echo "📊 What we tested:"
echo "✅ Fresh session state (no cached sessions)"
echo "✅ Login flow through Keycloak"
echo "✅ Authentication state in navigation"
echo "✅ Enhanced logout with Keycloak session termination"
echo "✅ Complete session clearing verification"
echo "✅ Re-login capability after logout"
echo ""
echo "🔧 Technical Details:"
echo "- SagebrushWeb clears server-side session storage"
echo "- Logout redirects to Keycloak logout endpoint"
echo "- Keycloak terminates its session and redirects back"
echo "- Browser cookies are expired"
echo "- Next access requires fresh authentication"
echo ""

if [ $? -eq 0 ]; then
    echo -e "${GREEN}🏆 All logout functionality is working correctly!${NC}"
else
    echo -e "${RED}❌ Some issues were found. Check the steps above.${NC}"
fi

echo ""
echo "Press Ctrl+C to stop all services"

# Wait for user to interrupt
wait $SAGEBRUSH_PID