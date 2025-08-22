#!/bin/bash

echo "🧪 Testing Dex OIDC setup..."

# Check if Dex is running
if ! curl -s http://localhost:5556/healthz > /dev/null; then
    echo "❌ Dex is not running. Starting it with docker-compose..."
    docker-compose up -d dex

    echo "⏳ Waiting for Dex to be ready..."
    sleep 5

    # Wait for Dex to be healthy
    attempt=1
    max_attempts=30
    while ! curl -s http://localhost:5556/healthz > /dev/null; do
        if [ $attempt -eq $max_attempts ]; then
            echo "❌ Dex failed to start"
            exit 1
        fi
        echo "   Attempt $attempt/$max_attempts - Dex not ready yet..."
        sleep 2
        ((attempt++))
    done
    echo "✅ Dex is ready!"
else
    echo "✅ Dex is already running"
fi

# Test Dex endpoints
echo "🔍 Testing Dex endpoints..."

echo "   Health check:"
curl -s http://localhost:5556/healthz | jq . 2>/dev/null || echo "   Raw response: $(curl -s http://localhost:5556/healthz)"

echo "   Well-known OIDC:"
curl -s http://localhost:5556/.well-known/openid_configuration | jq . 2>/dev/null || echo "   Raw response: $(curl -s http://localhost:5556/.well-known/openid_configuration)"

echo "   JWKS endpoint:"
curl -s http://localhost:5556/keys | jq . 2>/dev/null || echo "   Raw response: $(curl -s http://localhost:5556/keys)"

echo ""
echo "🔗 You can now use Dex for OIDC authentication in your tests"
echo "   Update your OIDCConfiguration.swift to use Dex instead of Keycloak for development"
echo ""
echo "   Dex issuer: http://localhost:5556/dex"
echo "   Client ID: luxe-client"
echo "   Client Secret: luxe-client-secret"
