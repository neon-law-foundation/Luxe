# Local ALB Authentication Testing Guide

This guide covers how to test AWS ALB/Cognito header-based authentication locally without requiring AWS infrastructure.

## Overview

Phase 5 of the HTTP Header Authentication roadmap provides multiple tools for local testing:

1. **MockALBHeaders Test Utility** - For automated tests
2. **Integration Tests** - Comprehensive test coverage
3. **Postman Collection** - Manual API testing
4. **Docker ALB Simulation** - Full ALB behavior simulation
5. **Development Middleware** - Easy auth mode switching
6. **This Documentation** - Complete testing procedures

## Quick Start

### 1. Enable Development Authentication

Add to your application configuration (development only):

```swift
// In configure.swift or your app setup
if app.environment.isDevelopment {
    app.addDevelopmentAuth()
}
```

### 2. Test Different Auth Modes via URL Parameters

```bash
# Admin authentication
curl "http://localhost:8080/admin?auth=admin"

# Staff authentication  
curl "http://localhost:8080/staff?auth=staff"

# Customer authentication
curl "http://localhost:8080/app?auth=customer"

# No authentication
curl "http://localhost:8080/public?auth=none"
```

## Testing Methods

## Method 1: Development Middleware (Recommended)

The `DevelopmentAuthMiddleware` provides the easiest way to test different authentication scenarios.

### URL Parameter Authentication

Override authentication mode for any request:

```bash
# Test admin access to admin dashboard
curl "http://localhost:8080/admin?auth=admin" -H "Accept: text/html"

# Test customer trying to access admin (should fail)
curl "http://localhost:8080/admin?auth=customer" -H "Accept: text/html"

# Test staff access to reports
curl "http://localhost:8080/staff/reports?auth=staff" -H "Accept: text/html"

# Test app route with customer auth
curl "http://localhost:8080/app/me?auth=customer" -H "Accept: application/json"
```

### Environment Variable Authentication

Set default authentication mode:

```bash
# Set default to admin mode
export DEV_AUTH_MODE=admin

# Set specific test user
export DEV_AUTH_USER=test-admin@neonlaw.com

# Start your app - all requests will use admin auth
swift run BazaarServer
```

### Route-Based Auto-Detection

The middleware automatically detects appropriate auth based on route patterns:

- `/admin/*` routes → Admin authentication
- `/staff/*`, `/reports/*` routes → Staff authentication  
- `/app/*`, `/api/*` routes → Customer authentication
- All other routes → No authentication

```bash
# These automatically get appropriate auth
curl http://localhost:8080/admin          # → Admin auth
curl http://localhost:8080/staff          # → Staff auth  
curl http://localhost:8080/app            # → Customer auth
curl http://localhost:8080/pricing        # → No auth
```

## Method 2: Docker ALB Simulation

For full ALB behavior simulation with Nginx proxy.

### Setup

```bash
# Start the ALB simulation environment
docker-compose -f docker-compose.alb-simulation.yml up -d

# Check services are running
docker-compose -f docker-compose.alb-simulation.yml ps
```

### Testing

```bash
# Access through ALB simulator (port 8081)
curl http://localhost:8081/admin?auth=admin
curl http://localhost:8081/app?auth=customer

# Compare with direct access (port 8080)
curl http://localhost:8080/app/me  # No ALB headers → 401

# Special test endpoints
curl http://localhost:8081/test/admin     # Always admin
curl http://localhost:8081/test/staff     # Always staff
curl http://localhost:8081/test/customer  # Always customer
curl http://localhost:8081/test/no-auth   # No headers
```

### View ALB Logs

```bash
# See header injection in action
docker-compose -f docker-compose.alb-simulation.yml logs -f alb-simulator
```

## Method 3: Postman Collection

Import the Postman collection for interactive testing.

### Import Collection

1. Open Postman
2. Import `Luxe_ALB_Authentication.postman_collection.json`
3. Set `baseUrl` variable to `http://localhost:8080` or `http://localhost:8081`

### Collection Structure

- **Public Routes** - No authentication required
- **Customer Authentication** - Basic user access
- **Staff Authentication** - Employee-level access  
- **Admin Authentication** - Full system access
- **Authentication Error Cases** - Testing failure scenarios

### Key Test Scenarios

```bash
# Test public access
GET http://localhost:8080/health

# Test customer authentication
GET http://localhost:8080/app/me
Headers: x-amzn-oidc-data, x-amzn-oidc-identity, x-amzn-oidc-accesstoken

# Test role-based access control
GET http://localhost:8080/admin  # With customer headers → 403
GET http://localhost:8080/admin  # With admin headers → 200
```

## Method 4: Automated Tests

Run the comprehensive test suite.

### Unit Tests

```bash
# Test MockALBHeaders utility
swift test --filter "ALBHeaderValidatorTests"

# Test SmartAuthMiddleware 
swift test --filter "SmartAuthMiddlewareTests"
```

### Integration Tests

```bash
# Full ALB integration tests
swift test --filter "ALBIntegrationTests"

# All authentication tests
swift test --filter "Auth" --no-parallel
```

### Test Patterns in Code

```swift
import TestUtilities

@Test("Customer can access app routes")
func testCustomerAppAccess() async throws {
    try await TestUtilities.withApp { app, database in
        try configureALBApp(app)
        
        // Create test user
        try await TestUtilities.createTestUser(
            database,
            name: "Test Customer",
            email: "customer@example.com", 
            username: "customer@example.com",
            role: "customer"
        )
        
        // Test with ALB headers
        let headers = TestUtilities.createMockALBCustomerHeaders(
            sub: "customer-sub",
            email: "customer@example.com",
            name: "Test Customer"
        )
        
        try await app.test(.GET, "/app/me", headers: headers) { response in
            #expect(response.status == .ok)
        }
    }
}
```

## Authentication Scenarios

### Scenario 1: Public Route Access

**Expectation**: Public routes accessible without authentication

```bash
curl http://localhost:8080/               # Home page
curl http://localhost:8080/health         # Health check
curl http://localhost:8080/pricing        # Pricing page

# Expected: 200 OK responses
```

### Scenario 2: Protected Route Access

**Expectation**: Protected routes require valid authentication

```bash
# Without auth headers → 401 Unauthorized
curl http://localhost:8080/app/me

# With customer auth → 200 OK
curl "http://localhost:8080/app/me?auth=customer"

# Expected: Authentication required for /app, /api routes
```

### Scenario 3: Role-Based Access Control

**Expectation**: Admin routes require admin role

```bash
# Customer trying admin route → 403 Forbidden
curl "http://localhost:8080/admin?auth=customer"

# Admin accessing admin route → 200 OK
curl "http://localhost:8080/admin?auth=admin"

# Staff accessing staff route → 200 OK  
curl "http://localhost:8080/staff?auth=staff"
```

### Scenario 4: Invalid Authentication

**Expectation**: Invalid/malformed headers are rejected

```bash
# Test malformed headers
curl http://localhost:8080/app/me \
  -H "x-amzn-oidc-data: invalid-data" \
  -H "x-amzn-oidc-identity: test@example.com"

# Expected: 401 Unauthorized
```

### Scenario 5: User Not in Database

**Expectation**: Valid headers but non-existent user rejected

```bash
# Valid header format but user doesn't exist in database
curl "http://localhost:8080/app/me?auth=customer" \
  -H "DEV_AUTH_USER=nonexistent@example.com"

# Expected: 401 Unauthorized (user not found)
```

## Debugging Authentication

### Debug Headers

The development middleware adds debug headers to responses:

```bash
curl -I "http://localhost:8080/app?auth=admin"

# Response headers:
# x-dev-auth-processed: true
# x-dev-auth-mode: admin  
# x-dev-auth-user: dev-admin@neonlaw.com
# x-dev-auth-role: admin
# x-dev-auth-hint: Add ?auth=admin|staff|customer|none to URL
```

### Server Logs

Enable detailed logging to see authentication flow:

```bash
# Set log level
export LOG_LEVEL=debug

# Start server
swift run BazaarServer

# Watch for auth-related log messages:
# 🛠️ DevelopmentAuthMiddleware processing: /app
# 🎭 Using development auth mode: customer  
# ✅ Injected development auth for: dev-customer@example.com
```

### Database Verification

Check what users exist in your test database:

```sql
-- Connect to database
psql postgres://postgres@localhost:5432/luxe

-- View test users
SELECT u.username, u.role, p.name, p.email 
FROM auth.users u 
JOIN directory.people p ON u.person_id = p.id
ORDER BY u.role, u.username;
```

## Common Issues & Solutions

### Issue: "User not found in system"

**Cause**: ALB headers reference user that doesn't exist in database

**Solution**: 
```bash
# Create test user via migration or seed data
swift run Palette migrate

# Or use development middleware to create temporary users
curl "http://localhost:8080/app?auth=customer"
```

### Issue: "Invalid authentication headers"

**Cause**: Malformed or expired JWT in ALB headers

**Solution**: Use the MockALBHeaders utility or development middleware which create valid headers

### Issue: "Route requires authentication"

**Cause**: Protected route accessed without proper headers

**Solution**: 
```bash
# Add auth parameter
curl "http://localhost:8080/app/me?auth=customer"

# Or set environment variable
export DEV_AUTH_MODE=customer
```

### Issue: "Forbidden access"

**Cause**: User role insufficient for route

**Solution**: Use appropriate auth mode
```bash
# Use admin auth for admin routes
curl "http://localhost:8080/admin?auth=admin"

# Use staff auth for staff routes  
curl "http://localhost:8080/staff?auth=staff"
```

## Production vs Local Differences

### Production (AWS ALB + Cognito)
- Real JWT tokens with cryptographic signatures
- Headers injected by AWS infrastructure
- User authentication via Cognito flows
- Headers only present on protected routes

### Local Development  
- Mock JWT tokens with dummy signatures
- Headers injected by development middleware or nginx simulation
- Automatic user creation/simulation
- Headers can be added to any route for testing

### Key Compatibility Points
- Same header names (`x-amzn-oidc-*`)
- Same JWT payload structure
- Same authentication logic in application
- Same role-based access control

## Performance Testing

### Load Testing with Authentication

```bash
# Install hey (HTTP load testing tool)
go install github.com/rakyll/hey@latest

# Test authenticated endpoints
hey -n 1000 -c 10 "http://localhost:8081/app/me?auth=customer"

# Test ALB simulation performance  
hey -n 1000 -c 10 "http://localhost:8081/admin?auth=admin"
```

### Monitoring Authentication Performance

```bash
# Monitor authentication timing
curl -w "@curl-format.txt" "http://localhost:8080/app?auth=customer"

# curl-format.txt content:
#     time_namelookup:  %{time_namelookup}\n
#     time_connect:     %{time_connect}\n  
#     time_appconnect:  %{time_appconnect}\n
#     time_pretransfer: %{time_pretransfer}\n
#     time_redirect:    %{time_redirect}\n
#     time_starttransfer: %{time_starttransfer}\n
#     time_total:       %{time_total}\n
```

## Best Practices

### 1. Use Different Methods for Different Purposes

- **Unit Tests**: MockALBHeaders utility
- **Integration Tests**: Full test application with ALB authenticator
- **Manual Testing**: Development middleware with URL parameters
- **Load Testing**: Docker ALB simulation
- **API Testing**: Postman collection

### 2. Test All Authentication Scenarios

- Public route access (no auth)
- Protected route access (auth required)
- Role-based access control (different user roles)
- Authentication failures (invalid headers, non-existent users)
- Edge cases (expired tokens, malformed data)

### 3. Maintain Test Data

- Keep test users in database consistent
- Use realistic test data (emails, names)
- Test with different Cognito groups
- Verify role mappings work correctly

### 4. Environment Isolation

- Only enable development middleware in development
- Use separate databases for testing vs development
- Clean up test data between test runs
- Document which tools to use in which environments

## Next Steps

After verifying local authentication works:

1. **Deploy to Staging**: Test with real ALB/Cognito setup
2. **Performance Testing**: Load test authentication flows
3. **Security Review**: Validate authentication logic
4. **Documentation**: Update API docs with authentication requirements
5. **Monitoring**: Add authentication metrics and alerts

This completes the Phase 5 testing toolkit. All tools work together to provide comprehensive local testing of ALB header-based authentication.