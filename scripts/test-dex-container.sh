#!/bin/bash

set -e

echo "🧪 Testing Dex Container Locally"
echo "================================"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

# Create a temporary directory for testing
TEST_DIR=$(mktemp -d)
echo "📁 Created test directory: $TEST_DIR"
cd "$TEST_DIR"

# Create the Dex config
echo "📝 Creating Dex configuration..."
cat > dex-config.yaml <<'YAML'
issuer: http://127.0.0.1:5556/dex
storage:
  type: sqlite3
  config:
    file: /var/lib/dex/dex.db
web:
  http: 0.0.0.0:8080
connectors:
- type: oidc
  id: github-actions
  name: github-actions
  config:
    issuer: https://token.actions.githubusercontent.com
    scopes: [ "openid", "groups" ]
    userNameKey: sub
staticClients:
  - name: My app
    id: my-app
    secret: my-secret
    public: true
YAML

# Create the Dockerfile
echo "🐳 Creating Dockerfile..."
cat > Dockerfile <<'DOCKERFILE'
FROM ghcr.io/dexidp/dex:latest

# Copy configuration first
COPY dex-config.yaml /etc/dex/config.docker.yaml

# Create a volume mount point for the database
VOLUME /var/lib/dex

# Set working directory to where database will be stored
WORKDIR /var/lib/dex

EXPOSE 8080
CMD ["dex", "serve", "/etc/dex/config.docker.yaml"]
DOCKERFILE

# Build the container
echo "🔨 Building Docker container..."
docker build -t dex-test:latest .

# Run the container
echo "🚀 Starting Dex container..."
CONTAINER_ID=$(docker run -d -p 8081:8080 --name dex-test dex-test:latest)

echo "📊 Container started with ID: $CONTAINER_ID"
echo "⏳ Waiting for container to be ready..."

# Wait a bit for the container to start
sleep 5

# Check container status
echo "📋 Container status:"
docker ps --filter "id=$CONTAINER_ID"

# Check logs
echo "📝 Container logs:"
docker logs "$CONTAINER_ID"

# Test if the service is responding
echo "🧪 Testing service response..."
if curl -s http://localhost:8081/dex/.well-known/openid_configuration > /dev/null 2>&1; then
    echo "✅ Dex is responding on port 8081!"
    echo "🌐 OpenID Configuration: http://localhost:8081/dex/.well-known/openid_configuration"
else
    echo "❌ Dex is not responding on port 8081"
fi

echo ""
echo "🎯 To stop and clean up:"
echo "   docker stop dex-test"
echo "   docker rm dex-test"
echo "   docker rmi dex-test:latest"
echo ""
echo "🔍 To view logs:"
echo "   docker logs -f dex-test"
echo ""
echo "🧹 To clean up everything:"
echo "   docker stop dex-test 2>/dev/null || true"
echo "   docker rm dex-test 2>/dev/null || true"
echo "   docker rmi dex-test:latest 2>/dev/null || true"
echo "   rm -rf $TEST_DIR"
