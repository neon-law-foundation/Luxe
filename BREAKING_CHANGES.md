# Breaking Changes: Session to Header-Based Authentication

## Overview

This document outlines the breaking changes introduced when migrating from session-based to ALB/Cognito header-based authentication.

**Effective Date**: Phase 6 of HTTPHeaderAuth roadmap (Issue #13)

## 🚨 Critical Breaking Changes

### 1. Session Storage Removed

**What Changed:**
- `SessionStorageKey` and related session storage functionality completely removed
- No more server-side session management
- `luxe-session` cookies no longer used for authentication

**Impact:**
- Applications relying on `SessionStorageKey` will fail to compile
- Any code checking `request.cookies["luxe-session"]` will no longer work
- Session-based authentication flows are non-functional

**Migration Required:**

```swift
// OLD: Session-based auth
if let sessionId = request.cookies["luxe-session"]?.string,
   let accessToken = request.application.storage[SessionStorageKey.self]?[sessionId] {
    // Auth logic
}

// NEW: Header-based auth  
if let userData = request.headers.first(name: "x-amzn-oidc-data") {
    let authenticator = ALBHeaderAuthenticator()
    let user = try await authenticator.authenticate(request: request)
    // Auth logic
}
```

### 2. Middleware Changes

**What Changed:**
- `SessionMiddleware` completely removed
- `ALBHeaderAuthenticator` is now the primary authentication middleware
- `SmartAuthMiddleware` handles route-specific auth patterns

**Impact:**
- Applications using `SessionMiddleware` will fail to compile
- Authentication flow completely changed
- Route protection mechanisms updated

**Migration Required:**

```swift
// OLD: Session middleware
app.middleware.use(SessionMiddleware())

// NEW: ALB header middleware
let smartAuth = SmartAuthMiddleware(
    authenticator: ALBHeaderAuthenticator(),
    protectedPaths: ["/admin", "/api/protected"]
)
app.middleware.use(smartAuth)
```

### 3. OAuth Callback Handler Changes

**What Changed:**
- OAuth callbacks no longer create server-side sessions
- `OAuthCallbackHandler` updated to work with header-based auth
- Session creation logic removed

**Impact:**
- Custom OAuth integrations may break
- Session-based OAuth flows non-functional
- Callback URLs may need updates

**Migration Required:**
- Update OAuth callback handling to work with ALB/Cognito
- Remove session creation from custom OAuth handlers
- Test OAuth flows thoroughly

### 4. Current User Context Changes

**What Changed:**
- User context now populated from headers instead of sessions
- `CurrentUserContext.user` lifecycle changed
- Per-request user resolution updated

**Impact:**
- User context may be `nil` where it previously had values
- Authentication checks need updating
- User lookup patterns changed

**Migration Required:**

```swift
// OLD: Session-based user context
// User set in SessionMiddleware from session storage

// NEW: Header-based user context
// User set in ALBHeaderAuthenticator from headers
// Available in same CurrentUserContext.$user
```

## 📋 API Changes

### Removed Components

| Component | Replacement | Migration Notes |
|-----------|-------------|----------------|
| `SessionStorageKey` | N/A | Remove all references |
| `SessionMiddleware` | `ALBHeaderAuthenticator` + `SmartAuthMiddleware` | Update middleware stack |
| Session cookies | HTTP headers | Use `x-amzn-oidc-*` headers |
| `app.storage[SessionStorageKey.self]` | Request headers | Parse JWT from headers |

### Updated Components

| Component | Changes | Migration Notes |
|-----------|---------|----------------|
| `OAuthCallbackHandler` | No session creation | Update OAuth flows |
| `CurrentUserContext` | Header-based population | Test user resolution |
| `App.swift` | Removed session init | Update app configuration |
| Authentication routes | Header-based checks | Update route handlers |

## 🔧 Development Environment Changes

### Local Development

**What Changed:**
- Local development now uses `LocalMockAuthenticator`
- No more session cookies in development
- Headers automatically injected in dev mode

**Required Changes:**

```bash
# Set development environment
export LUXE_ENV=development

# Headers automatically provided by LocalMockAuthenticator
# No manual session setup required
```

### Testing Changes

**What Changed:**
- Test utilities updated to use header-based mocks
- `MockALBHeaders` replaces session-based test setup
- All auth tests need header injection

**Required Changes:**

```swift
// OLD: Session-based test setup
app.storage[SessionStorageKey.self] = [sessionId: testToken]

// NEW: Header-based test setup  
let headers = MockALBHeaders.adminUser()
try app.test(.GET, "/admin", headers: headers.httpHeaders) { response in
    // Test logic
}
```

## 🚀 Production Deployment Changes

### Infrastructure Requirements

**New Requirements:**
- AWS Application Load Balancer with Cognito integration
- Cognito User Pool configured for your domains
- ALB listener rules for authentication
- SSL certificates for HTTPS (required for Cognito)

**Deployment Steps:**
1. Deploy ALB with Cognito integration (handled by Vegas)
2. Update DNS to point to ALB
3. Test header injection before deploying app changes
4. Deploy application with header-based auth

### DNS Changes

**Required DNS Updates:**
- Domain must point to ALB (not directly to ECS)
- SSL certificate must be valid for Cognito
- ALB handles authentication before forwarding to app

## 🧪 Testing & Validation

### Development Testing

1. **Local Headers**: Use `LocalMockAuthenticator` in development
2. **Manual Testing**: Use Postman collection with header injection
3. **Integration Tests**: All updated to use `MockALBHeaders`

### Production Validation

1. **ALB Health**: Verify ALB forwards requests with headers
2. **Cognito Auth**: Test login/logout flows
3. **Header Injection**: Confirm all required headers present
4. **User Resolution**: Validate user lookup from headers

## 📖 Migration Checklist

### For Application Developers

- [ ] Remove all `SessionStorageKey` references
- [ ] Update middleware configuration
- [ ] Replace session-based auth checks with header-based
- [ ] Update OAuth callback handlers
- [ ] Test local development with `LocalMockAuthenticator`
- [ ] Update integration tests to use `MockALBHeaders`
- [ ] Verify user context resolution works correctly

### For Infrastructure Teams  

- [ ] Deploy ALB with Cognito integration
- [ ] Configure Cognito User Pool
- [ ] Set up ALB listener rules
- [ ] Update DNS to point to ALB
- [ ] Test header injection before app deployment
- [ ] Validate SSL certificates for Cognito

### For QA Teams

- [ ] Test authentication flows end-to-end
- [ ] Verify logout functionality
- [ ] Validate user role/permission checks
- [ ] Test both public and protected routes
- [ ] Confirm error handling for auth failures

## 🚑 Rollback Plan

If issues occur after deployment:

1. **Immediate**: Keep ALB but bypass Cognito temporarily
2. **Headers**: ALB can forward without authentication
3. **Code**: Previous session code available in git history
4. **Database**: No database changes, so no data migration needed

## 📞 Support & Questions

For questions about this migration:

1. **Documentation**: Check `/Research/HTTPHeaderAuth.md`
2. **Migration Tool**: Use `swift run Vegas migrate-sessions`
3. **Testing**: Use `MockALBHeaders` utilities in tests
4. **Issues**: Report bugs via GitHub issues

## 🗓️ Timeline

- **Phase 0-5**: ✅ Completed - Infrastructure and core implementation
- **Phase 6**: 🚧 Current - Session removal and cleanup
- **Post-Migration**: Documentation and developer support

---

**⚠️ IMPORTANT**: This is a breaking change that affects authentication across the entire application.
Plan deployment carefully and ensure all teams are prepared for the changes.
