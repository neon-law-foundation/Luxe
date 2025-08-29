#!/bin/bash

# Script to run SagebrushWeb integration tests
# This script sets up the environment and runs WebDriver-based tests

set -e

echo "🚀 Setting up environment for SagebrushWeb integration tests..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Start required services
echo "📦 Starting Docker services..."
docker-compose up -d keycloak postgres

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

# Setup Keycloak
echo "🔐 Setting up Keycloak..."
./scripts/setup-keycloak.sh

# Run database migrations
echo "🗃️ Running database migrations..."
swift run Palette migrate

# Check if Chrome/Chromium is available
if command -v google-chrome > /dev/null 2>&1; then
    echo "✅ Google Chrome found"
elif command -v chromium > /dev/null 2>&1; then
    echo "✅ Chromium found"
elif command -v chromium-browser > /dev/null 2>&1; then
    echo "✅ Chromium browser found"
else
    echo "⚠️ Chrome/Chromium not found. WebDriver tests may fail."
    echo "Please install Chrome or Chromium to run integration tests."
fi

# Start SagebrushWeb in background
echo "🌐 Starting SagebrushWeb..."
swift run SagebrushWeb &
SAGEBRUSH_PID=$!

# Wait for SagebrushWeb to start
echo "⏳ Waiting for SagebrushWeb to start..."
sleep 5

# Check if SagebrushWeb is responding
if curl -f http://localhost:8080/health > /dev/null 2>&1; then
    echo "✅ SagebrushWeb is ready"
else
    echo "❌ SagebrushWeb failed to start"
    kill $SAGEBRUSH_PID 2>/dev/null || true
    exit 1
fi

# Run the integration tests
echo "🧪 Running integration tests..."
if swift test --no-parallel --filter SagebrushWebIntegrationTests; then
    echo "✅ Integration tests passed!"
    TEST_RESULT=0
else
    echo "❌ Integration tests failed!"
    TEST_RESULT=1
fi

# Cleanup
echo "🧹 Cleaning up..."
kill $SAGEBRUSH_PID 2>/dev/null || true

# Stop Docker services if they were started by this script
echo "🛑 Stopping Docker services..."
docker-compose down

echo "✨ Integration test run complete!"
exit $TEST_RESULT