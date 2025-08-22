# SagebrushWeb Integration Tests

This directory contains WebDriver-based integration tests that verify the complete authentication flow for SagebrushWeb.

## Overview

The integration tests use Swift WebDriver to automate a real browser and test:

- **Authentication Redirect**: Unauthenticated users are redirected to Keycloak

- **Login Flow**: Users can log in with username `shicholas` and password `Vegas702!`

- **Session Management**: Authenticated sessions persist across page reloads

- **Error Handling**: Invalid credentials show appropriate error messages

## Prerequisites

### Required Software

- **Docker & Docker Compose**: For running Keycloak and PostgreSQL

- **Chrome or Chromium**: WebDriver requires a browser for automation

- **Swift**: For building and running the application

### Browser Installation

**macOS:**

```bash
# Install Chrome via Homebrew
brew install --cask google-chrome

# Or install Chromium
brew install --cask chromium
```

**Ubuntu/Debian:**

```bash
# Install Chrome
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub \
   | sudo apt-key add - echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" \
   | sudo tee
/etc/apt/sources.list.d/google-chrome.list
sudo apt update
sudo apt install google-chrome-stable

# Or install Chromium
sudo apt install chromium-browser
```

## Running Integration Tests

### Quick Start

Use the automated script that sets up everything:

```bash
./scripts/run-integration-tests.sh
```

This script will:

1. Start Docker services (Keycloak, PostgreSQL)
2. Configure Keycloak with realm, client, and user
3. Run database migrations
4. Start SagebrushWeb
5. Run the integration tests
6. Clean up all services

### Manual Setup

If you prefer to run tests manually:

1. **Start services:**

   ```bash
   docker-compose up -d keycloak postgres
   ```

2. **Setup Keycloak:**

   ```bash
   ./scripts/setup-keycloak.sh
   ```

3. **Run migrations:**

   ```bash
   swift run Palette migrate
   ```

4. **Start SagebrushWeb:**

   ```bash
   swift run SagebrushWeb
   ```

5. **Run tests in another terminal:**

   ```bash
   swift test --filter SagebrushWebIntegrationTests
   ```

## Test Scenarios

### `userCanLoginAndAccessProtectedPage`

- Navigates to `/app/me`

- Verifies redirect to Keycloak login page

- Enters credentials (`shicholas` / `Vegas702!`)

- Verifies successful login and redirect back to `/app/me`

- Confirms user information is displayed

### `authenticatedUserCanNavigateBetweenProtectedPages`

- Logs in once

- Navigates to other protected pages

- Verifies no additional login prompts

- Confirms session persistence

### `invalidCredentialsShowErrorMessage`

- Attempts login with invalid credentials

- Verifies error message is displayed

- Confirms user remains on login page

### `userSessionPersistsAcrossBrowserRefresh`

- Logs in successfully

- Refreshes the browser page

- Verifies user remains authenticated

- Confirms no redirect to login page

## Troubleshooting

### WebDriver Issues

**"Chrome not found" or similar errors:**

- Ensure Chrome/Chromium is installed and in PATH

- Try specifying the browser path in WebDriver configuration

**"Connection refused" to localhost:4444:**

- WebDriver uses an embedded driver, not Selenium Grid

- Ensure no other WebDriver processes are running

### Service Issues

**Keycloak not responding:**

- Check Docker logs: `docker-compose logs keycloak`

- Ensure port 2222 is not in use by other services

- Wait longer for Keycloak to start (can take 30+ seconds)

**SagebrushWeb not starting:**

- Check if port 8080 is already in use

- Verify database migrations completed successfully

- Check application logs for startup errors

### Test Failures

**Page elements not found:**

- Keycloak UI may have changed; update element selectors

- Network latency may require longer wait times

- Verify Keycloak realm and client are properly configured

**Authentication fails:**

- Confirm user `shicholas` exists in Keycloak

- Verify password is set to `Vegas702!`

- Check database contains corresponding user record

## Configuration

### Test Credentials

- **Username**: `shicholas`

- **Password**: `Vegas702!`

- **Email**: `admin@neonlaw.com`

### URLs

- **Application**: <http://localhost:8080>

- **Keycloak**: <http://localhost:2222>

- **Keycloak Realm**: `luxe`

- **Client ID**: `luxe-client`

### Timeouts

- **Page load**: 10 seconds

- **Element search**: 5 seconds

- **Redirect wait**: 10 seconds

These can be adjusted in the test code if needed for slower environments.

## Contributing

When adding new integration tests:

1. **Follow the existing pattern** of using helper methods for common actions
2. **Use descriptive test names** that explain the user scenario
3. **Add proper cleanup** with `defer` blocks to quit WebDriver sessions
4. **Handle timeouts gracefully** with appropriate wait conditions
5. **Document any new prerequisites** in this README
