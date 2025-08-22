#!/bin/bash

set -e

echo "🚀 Publishing Dex Container to GitHub Container Registry"
echo "========================================================"

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed. Please install it first:"
    echo "   brew install gh"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ Not authenticated with GitHub CLI. Please run:"
    echo "   gh auth login"
    exit 1
fi

# Get GitHub token with package write permissions
echo "🔑 Getting GitHub token..."
GITHUB_TOKEN=$(gh auth token)

if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Failed to get GitHub token. Please ensure you have write:packages scope."
    exit 1
fi

echo "✅ Got GitHub token"

# Login to GitHub Container Registry
echo "🐳 Logging into GitHub Container Registry..."
echo "$GITHUB_TOKEN" | docker login ghcr.io -u $(gh api user --jq .login) --password-stdin

# Set variables
REGISTRY="ghcr.io"
IMAGE_NAME="neon-law-foundation/luxe-dex"
TAG="latest"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo "📁 Created temp directory: $TEMP_DIR"
cd "$TEMP_DIR"

# Create Dex config
echo "📝 Creating Dex configuration..."
cat > dex-config.yaml <<'EOF'
issuer: http://127.0.0.1:8080/dex
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
EOF

# Create Dockerfile
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

# Build the image
echo "🔨 Building Docker image for AMD64 platform..."
docker build --platform linux/amd64 -t "$REGISTRY/$IMAGE_NAME:$TAG" .

# Push to registry
echo "📤 Pushing to GitHub Container Registry..."
docker push "$REGISTRY/$IMAGE_NAME:$TAG"

# Tag with latest and push
docker tag "$REGISTRY/$IMAGE_NAME:$TAG" "$REGISTRY/$IMAGE_NAME:latest"
docker push "$REGISTRY/$IMAGE_NAME:latest"

echo ""
echo "✅ Successfully published Dex container!"
echo "📦 Image: $REGISTRY/$IMAGE_NAME:$TAG"
echo "🌐 View at: https://github.com/neon-law-foundation/luxe-dex/packages"

# Cleanup
echo "🧹 Cleaning up..."
cd /
rm -rf "$TEMP_DIR"

echo "🎉 Done!"
