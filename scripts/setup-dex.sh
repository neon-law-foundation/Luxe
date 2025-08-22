#!/bin/bash

# Script to set up Dex identity provider for local development
# Run this after starting Dex with docker-compose

set -e

DEX_URL="http://localhost:2222"
ISSUER_URL="$DEX_URL/dex"

echo "Setting up Dex identity provider..."

# Wait for Dex to be ready
echo "Waiting for Dex to be ready..."
until curl -s "$DEX_URL/dex/healthz" > /dev/null 2>&1; do
  echo "Dex not ready, waiting..."
  sleep 2
done
echo "Dex is ready!"

# Check Dex configuration
echo "Checking Dex OIDC configuration..."
DISCOVERY_URL="$ISSUER_URL/.well-known/openid-configuration"
if curl -s "$DISCOVERY_URL" | grep -q "authorization_endpoint"; then
  echo "✓ Dex OIDC discovery endpoint working"
else
  echo "❌ Dex OIDC discovery endpoint not responding"
  exit 1
fi

# Verify JWKS endpoint
JWKS_URL="$ISSUER_URL/keys"
if curl -s "$JWKS_URL" | grep -q "keys"; then
  echo "✓ Dex JWKS endpoint working"
else
  echo "❌ Dex JWKS endpoint not responding"
  exit 1
fi

# Display configuration information
echo ""
echo "Dex setup complete!"
echo ""
echo "Configuration:"
echo "  Issuer URL: $ISSUER_URL"
echo "  Authorization endpoint: $ISSUER_URL/auth"
echo "  Token endpoint: $ISSUER_URL/token"
echo "  JWKS endpoint: $JWKS_URL"
echo "  Discovery endpoint: $DISCOVERY_URL"
echo ""
echo "Static Users (password: Vegas702!):"
echo "  • admin@neonlaw.com (Admin User)"
echo "  • teststaff@example.com (Test Staff User)"
echo "  • testcustomer@example.com (Test Customer User)"
echo ""
echo "Static Client:"
echo "  • Client ID: luxe-client (public client)"
echo ""
echo "You can now:"
echo "1. Test authentication: Navigate to http://localhost:8080/app/me"
echo "2. Login with any of the static users above"
echo "3. Password for all users: Vegas702!"

# Optional: Display Dex configuration
if command -v jq &> /dev/null; then
  echo ""
  echo "Dex OIDC Discovery Configuration:"
  curl -s "$DISCOVERY_URL" | jq .
fi