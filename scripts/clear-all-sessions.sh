#!/bin/bash

# Clear All Authentication Sessions Script
# This script clears sessions from all levels: browser, SagebrushWeb server, and Dex

set -e

echo "🧹 Clearing All Authentication Sessions"
echo "======================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "1. 🛑 Stopping SagebrushWeb server..."
pkill -f SagebrushWeb || echo "   SagebrushWeb was not running"

echo "2. 🗄️ Clearing server-side session storage..."
echo "   (Server restart will clear in-memory sessions)"

echo "3. 🌐 Clearing browser sessions..."
echo ""
echo -e "${YELLOW}MANUAL BROWSER STEPS:${NC}"
echo "   Safari:"
echo "   - Go to Safari → Preferences → Privacy"
echo "   - Click 'Manage Website Data...'"
echo "   - Search for 'localhost' and remove all entries"
echo "   - OR just clear all website data"
echo ""
echo "   Chrome:"
echo "   - Go to Chrome → Settings → Privacy and Security → Clear browsing data"
echo "   - Select 'Cookies and other site data'"
echo "   - Choose 'All time' and click 'Clear data'"
echo ""
echo "   Firefox:"
echo "   - Go to Firefox → Preferences → Privacy & Security"
echo "   - Under Cookies and Site Data, click 'Clear Data'"
echo ""

echo "4. 🔐 Clearing Dex sessions..."

# Check if Dex is running
if docker ps | grep -q dex; then
    echo "   Dex is running, clearing sessions by restarting..."
    
    # Dex doesn't have session management APIs like Keycloak
    # The simplest way to clear sessions is to restart the container
    echo "   Restarting Dex container..."
    docker-compose restart dex
    
    # Wait for Dex to be ready
    echo "   Waiting for Dex to restart..."
    sleep 5
    
    local attempt=1
    local max_attempts=30
    while ! curl -s http://localhost:2222/dex/healthz >/dev/null 2>&1; do
        if [ $attempt -eq $max_attempts ]; then
            echo -e "   ${RED}❌ Dex failed to restart${NC}"
            break
        fi
        echo "   Attempt $attempt/$max_attempts - Dex not ready yet..."
        sleep 2
        ((attempt++))
    done
    
    if curl -s http://localhost:2222/dex/healthz >/dev/null 2>&1; then
        echo "   ✅ Dex restarted (sessions cleared)"
    fi
else
    echo "   Dex is not running, starting it..."
    docker-compose up -d dex
    
    # Wait for Dex
    local attempt=1
    local max_attempts=30
    while ! curl -s http://localhost:2222/dex/healthz >/dev/null 2>&1; do
        if [ $attempt -eq $max_attempts ]; then
            echo -e "   ${RED}❌ Dex failed to start${NC}"
            exit 1
        fi
        echo "   Attempt $attempt/$max_attempts - Dex starting..."
        sleep 2
        ((attempt++))
    done
    
    echo "   ✅ Dex started"
fi

echo ""
echo -e "${GREEN}🎉 Session clearing complete!${NC}"
echo ""
echo "📋 What was cleared:"
echo "✅ SagebrushWeb server stopped (clears in-memory sessions)"
echo "✅ Dex sessions cleared by container restart"
echo "⚠️  Browser cookies (requires manual clearing - see instructions above)"
echo ""
echo "🚀 Next steps:"
echo "1. Clear your browser cookies manually (see instructions above)"
echo "2. Start SagebrushWeb: swift run SagebrushWeb"
echo "3. Test login flow: http://localhost:8080/app/me"
echo "   - Should redirect to Dex login page"
echo "   - Should require username/password entry"
echo ""
echo -e "${YELLOW}💡 Pro tip: Use Private/Incognito browsing mode to avoid cookie issues${NC}"