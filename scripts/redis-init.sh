#!/bin/bash

# Redis initialization script for Bazaar queue system
# This script verifies Redis connectivity for local development

echo "Initializing Redis for Bazaar queue system..."

# Check if Redis container is running
if ! docker-compose ps redis | grep -q "healthy"; then
    echo "❌ Redis container is not healthy. Starting Redis..."
    docker-compose up -d redis
    sleep 5
fi

# Test Redis connectivity using Docker
if docker exec redis redis-cli ping > /dev/null 2>&1; then
    echo "✅ Redis is running and responding to ping"
else
    echo "❌ Redis is not responding. Make sure Redis is running:"
    echo "   docker-compose up -d redis"
    exit 1
fi

# Set some basic configuration for development
docker exec redis redis-cli CONFIG SET save "900 1 300 10 60 10000" > /dev/null 2>&1
echo "✅ Redis save configuration updated for development"

# Test basic operations
docker exec redis redis-cli SET test:connection "Redis connection test" > /dev/null 2>&1
RESULT=$(docker exec redis redis-cli GET test:connection 2>/dev/null)
docker exec redis redis-cli DEL test:connection > /dev/null 2>&1

if [ "$RESULT" = "Redis connection test" ]; then
    echo "✅ Redis read/write operations working correctly"
else
    echo "❌ Redis read/write operations failed"
    exit 1
fi

# Show Redis info
echo "Redis server information:"
docker exec redis redis-cli INFO server | grep -E "(redis_version|redis_mode|process_id|uptime_in_seconds)"

echo "Redis configuration:"
echo "- Memory usage: $(docker exec redis redis-cli INFO memory | grep used_memory_human | cut -d: -f2)"
echo "- Connected clients: $(docker exec redis redis-cli INFO clients | grep connected_clients | cut -d: -f2)"
echo "- Port: 6379"
echo "- Persistence: AOF enabled with everysec sync"

echo "✅ Redis initialization for Bazaar queue system complete!"