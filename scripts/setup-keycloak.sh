#!/bin/bash

# Script to set up Keycloak with the luxe realm and client
# Run this after starting Keycloak with docker-compose

set -e

KEYCLOAK_URL="http://localhost:2222"
ADMIN_USER="admin"
ADMIN_PASSWORD="admin"
REALM_NAME="luxe"
CLIENT_ID="luxe-client"

echo "Setting up Keycloak realm and client..."

# Wait for Keycloak to be ready
echo "Waiting for Keycloak to be ready..."
until curl -s "$KEYCLOAK_URL/realms/master" > /dev/null; do
  echo "Keycloak not ready, waiting..."
  sleep 2
done
echo "Keycloak is ready!"

# Get admin access token
echo "Getting admin access token..."
ADMIN_TOKEN=$(curl -s -X POST \
  "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$ADMIN_USER" \
  -d "password=$ADMIN_PASSWORD" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" | \
  python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")

echo "Admin token obtained."

# Create realm
echo "Creating realm '$REALM_NAME'..."
curl -s -X POST \
  "$KEYCLOAK_URL/admin/realms" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "realm": "'$REALM_NAME'",
    "enabled": true,
    "displayName": "Luxe Realm"
  }' || echo "Realm might already exist"

echo "Realm created."

# Create client
echo "Creating client '$CLIENT_ID'..."
curl -s -X POST \
  "$KEYCLOAK_URL/admin/realms/$REALM_NAME/clients" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "'$CLIENT_ID'",
    "enabled": true,
    "publicClient": true,
    "redirectUris": [
      "http://localhost:8080/*",
      "http://127.0.0.1:8080/*"
    ],
    "webOrigins": [
      "http://localhost:8080",
      "http://127.0.0.1:8080"
    ],
    "protocol": "openid-connect",
    "frontchannelLogout": true
  }' || echo "Client might already exist"

echo "Client created."

# Create user
echo "Creating user 'admin@neonlaw.com'..."
curl -s -X POST \
  "$KEYCLOAK_URL/admin/realms/$REALM_NAME/users" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin@neonlaw.com",
    "email": "admin@neonlaw.com",
    "firstName": "Admin",
    "lastName": "User",
    "enabled": true,
    "emailVerified": true
  }' || echo "User might already exist"

# Get user ID
USER_ID=$(curl -s -X GET \
  "$KEYCLOAK_URL/admin/realms/$REALM_NAME/users?username=admin@neonlaw.com" \
  -H "Authorization: Bearer $ADMIN_TOKEN" | \
  python3 -c "import sys, json; users = json.load(sys.stdin); print(users[0]['id'] if users else '')")

if [ -n "$USER_ID" ]; then
  echo "Setting password for user 'admin@neonlaw.com'..."
  curl -s -X PUT \
    "$KEYCLOAK_URL/admin/realms/$REALM_NAME/users/$USER_ID/reset-password" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "type": "password",
      "value": "Vegas702!",
      "temporary": false
    }'
  echo "Password set."
else
  echo "Could not find user ID for admin@neonlaw.com"
fi

echo "Keycloak setup complete!"
echo ""
echo "You can now:"
echo "1. Access Keycloak admin: $KEYCLOAK_URL (admin/admin)"
echo "2. Test login: Navigate to http://localhost:8080/app/me"
echo "3. Login with: admin@neonlaw.com/Vegas702!"
