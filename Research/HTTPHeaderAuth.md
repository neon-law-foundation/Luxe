# HTTPHeaderAuth Research: ALB/Cognito Integration Patterns

## Executive Summary

This research document outlines the migration from session-based authentication to AWS Application Load Balancer
(ALB) header-based authentication using Amazon Cognito. The new architecture eliminates server-side session
state, enabling horizontal scaling and simplified security management.

## Current Authentication Architecture

### Session-Based Flow (To Be Replaced)

1. **User Login**: User redirects to OAuth provider (Cognito/Keycloak)
2. **Token Exchange**: Authorization code exchanged for JWT tokens
3. **Session Storage**: Tokens stored server-side with session ID
4. **Session Cookie**: Client receives session cookie referencing server state
5. **Request Authentication**: Server validates session and retrieves stored tokens

### Key Components to Replace

- `SessionStorage.swift`: In-memory session management
- `ImperialAuthMiddleware.swift`: Imperial OAuth integration
- `SessionMiddleware.swift`: Session-based request processing
- Session cookies and server-side state management

## Target ALB Header Authentication Architecture

### Header-Based Flow (New Approach)

1. **ALB Authentication**: Load balancer handles OAuth flow with Cognito
2. **Header Injection**: ALB injects authentication headers after successful auth
3. **Stateless Validation**: Application validates headers without server state
4. **Direct Processing**: Each request contains all necessary auth information

### ALB Authentication Headers

After successful authentication, ALB injects three critical headers:

#### `X-Amzn-Oidc-Data` (Primary)

- **Format**: Base64-encoded JWT containing user claims
- **Content**: User identity, groups, email, name, expiration
- **Validation**: Signature verification using ALB public key
- **Security**: ES256 (ECDSA) algorithm with key rotation

```json
{
  "sub": "cognito-user-id",
  "email": "user@example.com", 
  "name": "John Doe",
  "cognito:groups": ["admin", "users"],
  "exp": 1640995200,
  "iss": "https://cognito-idp.region.amazonaws.com/user-pool-id"
}
```

#### `X-Amzn-Oidc-Identity`

- **Format**: Plain text subject identifier
- **Content**: Cognito user ID or email
- **Usage**: Quick user identification without JWT parsing
- **Validation**: Cross-reference with JWT `sub` claim

#### `X-Amzn-Oidc-Accesstoken`

- **Format**: Plain text OAuth access token
- **Content**: Token for API calls to user info endpoint
- **Usage**: Optional - for additional user info queries
- **Validation**: Standard OAuth token validation

### Security Validation Requirements

#### JWT Signature Verification

```swift
// ALB uses rotating keys - fetch from ALB public key endpoint
let keyId = jwt.header.kid
let publicKey = await fetchALBPublicKey(keyId: keyId)
let isValid = jwt.verify(using: publicKey, algorithm: .es256)
```

#### Header Source Validation

- **Production**: Only accept headers from ALB (verify ALB ARN in signer field)
- **Development**: Mock headers for local testing
- **Security**: Reject headers from untrusted sources

#### Token Freshness

- Validate `exp` claim in JWT
- Consider configurable tolerance for clock skew
- Automatic rejection of expired tokens

## ALB Listener Rule Configuration

### Public Routes (No Authentication)

```yaml
Priority: 100
Conditions:
  - PathPattern: ["/", "/health", "/assets/*", "/api/public/*"]
Actions:
  - Type: forward
    TargetGroupArn: !Ref AppTargetGroup
```

### Protected Routes (Require Authentication)

```yaml
Priority: 200
Conditions:
  - PathPattern: ["/app/*", "/admin/*", "/api/protected/*"]
Actions:
  - Type: authenticate-cognito
    AuthenticateCognitoConfig:
      UserPoolArn: !Ref CognitoUserPool
      UserPoolClientId: !Ref CognitoUserPoolClient
      UserPoolDomain: !Ref CognitoUserPoolDomain
      SessionCookieName: "luxe-auth-session"
      SessionTimeout: 86400  # 24 hours
      Scope: "openid email profile"
      OnUnauthenticatedRequest: "authenticate"
  - Type: forward
    TargetGroupArn: !Ref AppTargetGroup
```

### Mixed Mode Routes (Conditional Authentication)

```yaml
Priority: 300
Conditions:
  - PathPattern: ["/blog/*", "/api/mixed/*"]
Actions:
  - Type: authenticate-cognito
    AuthenticateCognitoConfig:
      OnUnauthenticatedRequest: "allow"  # Forward without auth
  - Type: forward
    TargetGroupArn: !Ref AppTargetGroup
```

## Cognito User Pool Configuration

### Required Configuration

- **User Pool**: Primary identity store
- **User Pool Client**: Application configuration
- **User Pool Domain**: Authentication endpoint
- **Identity Provider**: Social/corporate login integration

### Cognito Groups for Authorization

```yaml
Groups:
  - customer: Basic customer access
  - staff: Internal staff access  
  - admin: Administrative access
  - system: System-level operations
```

### Example CloudFormation Configuration

```yaml
CognitoUserPool:
  Type: AWS::Cognito::UserPool
  Properties:
    UserPoolName: luxe-user-pool
    Policies:
      PasswordPolicy:
        MinimumLength: 8
        RequireUppercase: true
        RequireLowercase: true
        RequireNumbers: true
    AutoVerifiedAttributes:
      - email
    Schema:
      - Name: email
        Required: true
        Mutable: true

CognitoUserPoolClient:
  Type: AWS::Cognito::UserPoolClient
  Properties:
    UserPoolId: !Ref CognitoUserPool
    ClientName: luxe-app-client
    GenerateSecret: true  # Required for ALB
    AllowedOAuthFlows:
      - code
    AllowedOAuthScopes:
      - openid
      - email  
      - profile
    CallbackURLs:
      - https://www.sagebrush.services/oauth2/idpresponse
```

## Local Development Simulation Strategy

### Problem Statement

ALB authentication only works in AWS production environment. Local development needs simulation of ALB headers without
actual AWS infrastructure.

### Mock Authentication Middleware

```swift
struct LocalMockAuthenticator: AsyncRequestAuthenticator {
    let defaultUser: User
    
    func authenticate(request: Request) async throws {
        guard Environment.get("ENV") == "development" else {
            throw Abort(.internalServerError, reason: "Mock auth only for development")
        }
        
        // Create mock ALB headers
        let mockJWT = createMockJWT(for: defaultUser)
        request.headers.replaceOrAdd(name: "X-Amzn-Oidc-Data", value: mockJWT)
        request.headers.replaceOrAdd(name: "X-Amzn-Oidc-Identity", value: defaultUser.username)
        
        request.auth.login(defaultUser)
    }
    
    private func createMockJWT(for user: User) -> String {
        let payload = MockJWTPayload(
            sub: user.username,
            email: user.person?.email ?? user.username,
            name: user.person?.name ?? "Development User",
            cognitoGroups: [user.role.rawValue],
            exp: Date().addingTimeInterval(3600)
        )
        
        return try! JWT(payload: payload).serialize(using: .none)
    }
}
```

### Development Environment Configuration

```swift
// configure.swift
public func configure(_ app: Application) throws {
    switch app.environment {
    case .development:
        // Use mock authentication with automatic user assignment
        let mockUser = try await createOrFindDefaultUser()
        app.middleware.use(LocalMockAuthenticator(defaultUser: mockUser))
        
    case .production:
        // Use real ALB header authentication
        let config = OIDCConfiguration.create(from: app.environment)
        app.middleware.use(ALBHeaderAuthenticator(configuration: config))
        
    default:
        // Testing or staging - use ALB authentication
        let config = OIDCConfiguration.create(from: app.environment)
        app.middleware.use(ALBHeaderAuthenticator(configuration: config))
    }
}
```

### Docker Compose with nginx ALB Simulation

```yaml
# docker-compose.development.yml
version: '3.8'
services:
  nginx-alb-simulator:
    image: nginx:alpine
    ports:
      - "8081:80"
    volumes:
      - ./nginx-alb-simulator.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - app
      
  app:
    build: .
    environment:
      - ENV=development
      - MOCK_AUTH=true
    ports:
      - "8080:8080"
```

```nginx
# nginx-alb-simulator.conf
server {
    listen 80;
    server_name localhost;
    
    # Simulate ALB authentication headers for development
    location / {
        proxy_pass http://app:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        
        # Mock ALB headers for development
        proxy_set_header X-Amzn-Oidc-Identity "dev@example.com";
        proxy_set_header X-Amzn-Oidc-Data "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...";
        proxy_set_header X-Amzn-Oidc-Accesstoken "mock-access-token";
    }
}
```

## Integration Patterns

### Smart Middleware Pattern

```swift
final class SmartAuthMiddleware: AsyncMiddleware {
    private let publicRoutes = ["/", "/health", "/api/public/*"]
    private let adminRoutes = ["/admin/*", "/api/admin/*"]
    private let authenticator: ALBHeaderAuthenticator
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let path = request.url.path
        
        // Skip authentication for public routes
        if isPublicRoute(path) {
            return try await next.respond(to: request)
        }
        
        // Perform authentication
        try await authenticator.authenticate(request: request)
        
        guard let user = request.auth.get(User.self) else {
            throw Abort(.unauthorized)
        }
        
        // Check admin access for admin routes
        if isAdminRoute(path) && !user.hasAdminRole() {
            throw Abort(.forbidden, reason: "Admin access required")
        }
        
        return try await CurrentUserContext.$user.withValue(user) {
            try await next.respond(to: request)
        }
    }
}
```

### Role-Based Authorization Integration

```swift
extension User {
    func hasRole(_ role: UserRole) -> Bool {
        return self.role == role || self.role == .admin
    }
    
    func hasAnyRole(_ roles: [UserRole]) -> Bool {
        return roles.contains(self.role) || self.role == .admin
    }
}

// Usage in route handlers
func adminOnlyEndpoint(req: Request) async throws -> Response {
    let user = CurrentUserContext.user
    guard user.hasRole(.admin) else {
        throw Abort(.forbidden, reason: "Admin access required")
    }
    // ... admin logic
}
```

## Testing Strategy

### Unit Testing with Mock Headers

```swift
@Suite("ALB Authentication Tests")
struct ALBAuthTests {
    @Test("Should authenticate user with valid ALB headers")
    func testValidALBAuth() async throws {
        let app = try await Application.make(.testing)
        defer { app.shutdown() }
        
        try await app.test(.GET, "/admin/users") { req in
            req.headers.add(name: "X-Amzn-Oidc-Identity", value: "admin@example.com")
            req.headers.add(name: "X-Amzn-Oidc-Data", value: createMockJWT(
                sub: "admin@example.com",
                groups: ["admin"]
            ))
        } afterResponse: { res in
            #expect(res.status == .ok)
        }
    }
    
    @Test("Should reject requests without authentication")
    func testMissingAuth() async throws {
        let app = try await Application.make(.testing)
        defer { app.shutdown() }
        
        try await app.test(.GET, "/admin/users") { req in
            // No authentication headers
        } afterResponse: { res in
            #expect(res.status == .unauthorized)
        }
    }
}
```

### Integration Testing with Postman Collection

```json
{
  "name": "ALB Authentication Collection",
  "requests": [
    {
      "name": "Admin Access with ALB Headers",
      "method": "GET",
      "url": "{{base_url}}/admin/users",
      "headers": {
        "X-Amzn-Oidc-Identity": "{{admin_username}}",
        "X-Amzn-Oidc-Data": "{{mock_admin_jwt}}"
      }
    },
    {
      "name": "Customer Access",
      "method": "GET", 
      "url": "{{base_url}}/api/profile",
      "headers": {
        "X-Amzn-Oidc-Identity": "{{customer_username}}",
        "X-Amzn-Oidc-Data": "{{mock_customer_jwt}}"
      }
    }
  ]
}
```

## Migration Path

### Phase 0: Research (Current)

- Document current authentication patterns
- Research ALB/Cognito integration
- Plan local development strategy

### Phase 1: Data Layer

- Remove session-based database tables
- Implement structured logging for authentication events
- Update user models to support Cognito integration

### Phase 2: Core Authentication (Bouncer)

- Remove Imperial dependencies
- Implement ALBHeaderAuthenticator
- Create SmartAuthMiddleware for route pattern matching
- Add LocalMockAuthenticator for development

### Phase 3: Infrastructure (Vegas)

- Configure Cognito User Pool with ALB integration
- Implement ALB listener rules for authentication
- Set up CloudFormation templates

### Phase 4: Application Integration (Bazaar/Destined)

- Replace session middleware with ALB authentication
- Update all protected routes
- Implement mixed public/protected route handling

### Phase 5: Testing & Development Tools

- Create comprehensive test utilities
- Set up local development simulation
- Document testing procedures

### Phase 6: Migration & Cleanup

- Remove all session-related code
- Clean up unused dependencies
- Update documentation

## Security Considerations

### Header Trust Boundaries

- **Production**: Only trust headers from verified ALB sources
- **Development**: Mock headers acceptable for local development only
- **Staging**: Use real ALB headers with test Cognito user pool

### JWT Signature Verification

```swift
struct ALBJWTValidator {
    func validateJWT(_ jwtString: String) async throws -> ALBJWTPayload {
        let jwt = try JWT<ALBJWTPayload>(from: jwtString)
        
        // Fetch current ALB public key
        let keyId = jwt.header.keyID ?? throw ValidationError.missingKeyId
        let publicKey = try await fetchALBPublicKey(keyId: keyId)
        
        // Verify signature
        let isValid = try jwt.verify(using: .es256(key: publicKey))
        guard isValid else {
            throw ValidationError.invalidSignature
        }
        
        // Verify claims
        try jwt.payload.verify()
        
        return jwt.payload
    }
}
```

### Rate Limiting and Abuse Protection

- Leverage ALB's built-in rate limiting
- Implement additional application-level controls
- Monitor authentication failure patterns
- Alert on suspicious header patterns

## Performance Implications

### Benefits of Header-Based Authentication

- **Zero Database Lookups**: No session table queries
- **Horizontal Scaling**: No shared session state
- **Reduced Memory**: No in-memory session storage
- **Faster Authentication**: Direct header validation

### Potential Concerns

- **Header Size**: JWT tokens add request overhead
- **Validation CPU**: JWT signature verification per request
- **Network Latency**: Additional ALB processing time

### Optimization Strategies

- **Caching**: Cache public keys for JWT validation
- **Connection Pooling**: Reuse connections for key fetching
- **Async Processing**: Non-blocking authentication flow

## Conclusion

The migration from session-based to ALB header authentication provides:

1. **Simplified Architecture**: No server-side session management
2. **Improved Scalability**: Stateless authentication enables horizontal scaling
3. **Enhanced Security**: AWS-managed authentication with industry standards
4. **Operational Benefits**: Reduced infrastructure complexity
5. **Development Velocity**: Clear separation between authentication and application logic

The implementation requires careful attention to security validation, comprehensive testing, and gradual migration
to ensure system reliability throughout the transition.

## Current Authentication Touchpoint Analysis

### Bouncer Target (Authentication Library)

#### Imperial Dependencies to Remove

**Package.swift Dependencies:**
- `Imperial` package from vapor-community
- Used in Bouncer target imports

**ImperialAuthMiddleware.swift:**
- Handles OAuth session-based authentication for HTML pages
- Integrates with Imperial for OAuth flow management
- Supports both AWS Cognito (production) and Keycloak (development)
- Uses `ImperialToken` structure for session storage
- Includes user lookup by `sub` field with username fallback
- **Removal Required**: Complete file to be deleted

**ImperialIntegrationAnalysis.md:**
- Comprehensive analysis of existing Imperial OAuth configuration
- Documents reuse of OIDCConfiguration for Imperial providers
- Details callback route compatibility and session integration
- **Status**: Research document - can remain for historical reference

#### Session Management Dependencies to Remove

**SessionStorage.swift:**
- Enhanced session storage supporting OAuth tokens
- Stores session data with user IDs, access tokens, refresh tokens
- Implements session expiration and cleanup
- Uses `EnhancedSessionStorageKey` for application storage
- **Removal Required**: Complete session infrastructure

**Session-Related Middleware:**
- `EnhancedSessionMiddleware`: Session-based user context setting
- Database user loading from stored session data
- Cookie-based session identification
- **Removal Required**: All session middleware components

### Bazaar Target (Web Application)

#### Current Authentication Infrastructure

**ALBAuthMiddleware.swift:**
- Already implements ALB header authentication
- Supports both Bearer tokens and ALB-injected headers
- Falls back to session cookies for backward compatibility
- Handles X-Amzn-Oidc-Identity header parsing
- Creates mock JWT payloads for consistency
- **Status**: Partially complete - needs enhancement for full ALB integration

**SessionMiddleware.swift:**
- Checks session authentication on all routes
- Sets CurrentUserContext.user for authenticated sessions
- Handles hardcoded session patterns (shicholas:, `admin@neonlaw.com:`)
- **Removal Required**: Replace with ALB-only authentication

**OAuthCallbackHandler.swift:**
- Processes OAuth callbacks from Cognito/Dex
- Exchanges authorization codes for tokens
- Creates server-side sessions with SessionStorageKey
- Handles both development (Dex) and production (Cognito) flows
- **Removal Required**: ALB handles OAuth flow, callback not needed

#### Authentication Route Configuration

**App.swift Middleware Configuration:**

```swift
// Current middleware stack
app.middleware.use(ErrorMiddleware.default(environment: app.environment))
app.middleware.use(FileMiddleware(publicDirectory: publicDirectory))
app.middleware.use(SessionMiddleware()) // TO REMOVE

// Authentication middleware
let oidcMiddleware = OIDCMiddleware(configuration: oidcConfig) // FOR API
let albAuthMiddleware = ALBAuthMiddleware(configuration: oidcConfig) // FOR WEB

// Session storage initialization
app.storage[SessionStorageKey.self] = [:] // TO REMOVE
```

**Protected Route Groups:**

```swift
// App routes (authenticated web pages)
let protectedRoutes = appRoutes
    .grouped(albAuthMiddleware)
    .grouped(PostgresRoleMiddleware())

// Admin routes (admin-only web pages)  
let adminRoutes = app.grouped("admin")
    .grouped(albAuthMiddleware)
    .grouped(PostgresRoleMiddleware())

// API routes (JWT bearer token authentication)
apiRoutes.grouped(oidcMiddleware).grouped(PostgresRoleMiddleware())
```

**Public Routes (No Authentication Required):**
- `/` - Home page
- `/health` - Health check
- `/version` - Version endpoint  
- `/api/version` - API version
- `/api/public/*` - Public API endpoints
- Static file serving (`/assets/*`, `/favicon.*`)

**Session-Based Routes (To Be Converted):**
- `/login` - Login redirect (currently builds OIDC auth URL)
- `/auth/callback` - OAuth callback handler (TO REMOVE)
- `/oauth2/idpresponse` - Cognito callback (TO REMOVE) 
- `/auth/logout` - Logout handler (needs ALB logout URL)

**Protected Web Routes (Require Authentication):**
- `/app/me` - User profile endpoint
- All `/admin/*` routes - Administrative interface
- Newsletter management routes
- Admin CRUD operations (people, addresses, entities, etc.)

**Mixed Authentication Routes:**
- Some routes check for authentication state but don't require it
- Navigation components show different content for authenticated users
- Public pages with optional authentication context

#### Session Storage Usage Patterns

**SessionStorageKey Definition:**

```swift
// In Bazaar/App.swift
struct SessionStorageKey: StorageKey {
    typealias Value = [String: String]  // sessionId -> token
}
```

**Current Session Token Format:**
- `"username:jwt-token"` - OAuth JWT tokens
- `"shicholas:"` - Mock admin token 
- `"admin@neonlaw.com:"` - Hardcoded admin pattern
- Sessions stored in application memory (not persistent)

### Destined Target (Astrology Service)

#### Current State: No Authentication

**App.swift Analysis:**
- No authentication middleware configured
- All routes are public/unauthenticated
- No protected content or user-specific functionality
- Simple static page serving with health/version endpoints

**Public Routes:**
- `/` - Home page
- `/health` - Health check
- `/version` - Version info
- `/scorpio`, `/scorpio/moon` - Astrology content
- `/about-astrocartography` - Information page
- `/services` - Services page  
- `/blog`, `/blog/neptune-line` - Blog content
- `/privacy-policy` - Privacy policy

**Authentication Requirements:**
- **Current**: None - fully public service
- **Future**: May need authentication for personalized horoscopes, user preferences
- **Migration**: Simple addition of ALB authentication when needed

### Authentication Touchpoint Summary

#### High Priority Changes (Bazaar)

1. **Remove Imperial Dependencies**: Package.swift, ImperialAuthMiddleware.swift
2. **Remove Session Infrastructure**: SessionStorage.swift, SessionMiddleware.swift, SessionStorageKey
3. **Remove OAuth Callbacks**: OAuthCallbackHandler.swift, callback routes
4. **Enhance ALB Authentication**: Improve ALBAuthMiddleware for full ALB integration
5. **Update Route Configuration**: Remove session middleware, configure ALB-only auth

#### Medium Priority Changes (Bazaar)

1. **Update Admin Routes**: Ensure all admin functionality works with ALB headers
2. **Replace Login Flow**: ALB-managed login instead of manual OIDC redirect
3. **Update Logout**: ALB logout URL instead of session clearing
4. **Navigation Updates**: Remove session-based authentication state checks

#### Low Priority Changes

1. **Destined Enhancement**: Add optional authentication when user-specific features needed
2. **Testing Updates**: Replace session-based test utilities with ALB header mocks

#### Dependencies to Remove Completely

- `Imperial` package dependency
- `SessionStorageKey` and related session storage
- All session middleware components  
- OAuth callback handling infrastructure
- In-memory session management

#### Infrastructure Changes Required

- ALB listener rule configuration in Vegas
- Cognito User Pool setup with ALB integration
- CloudFormation template updates for authentication
- Local development simulation setup

## Comprehensive Local Development Simulation Strategy

### Current Development Infrastructure

The project already includes comprehensive local development services:

**docker-compose.yaml Services:**
- **postgres**: PostgreSQL 17 database on port 5432
- **dex**: OpenID Connect provider on port 2222 (replaces Keycloak)
- **localstack**: AWS service simulation for SQS/S3 on port 4566  
- **redis**: Redis server for queue system on port 6379

### ALB Header Simulation Approaches

#### 1. Environment-Based Mock Authentication (Recommended)

Extend the existing ALBAuthMiddleware for development mode:

```swift
// ALBAuthMiddleware.swift enhancement for development
public struct ALBAuthMiddleware: AsyncMiddleware {
    private let configuration: OIDCConfiguration
    private let developmentUser: DevelopmentUser?
    
    public init(configuration: OIDCConfiguration, developmentUser: DevelopmentUser? = nil) {
        self.configuration = configuration
        self.developmentUser = developmentUser
    }
    
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Development mode: inject mock ALB headers
        if Environment.get("ENV") == "development", 
           let devUser = developmentUser {
            return try await simulateALBHeaders(for: devUser, request: request, next: next)
        }
        
        // Production mode: validate real ALB headers
        return try await validateProductionALBHeaders(request: request, next: next)
    }
    
    private func simulateALBHeaders(
        for user: DevelopmentUser, 
        request: Request, 
        next: AsyncResponder
    ) async throws -> Response {
        // Create mock ALB headers
        let mockOIDCData = createMockOIDCData(for: user)
        request.headers.replaceOrAdd(name: "X-Amzn-Oidc-Data", value: mockOIDCData)
        request.headers.replaceOrAdd(name: "X-Amzn-Oidc-Identity", value: user.email)
        request.headers.replaceOrAdd(name: "X-Amzn-Oidc-Accesstoken", value: "dev-access-token")
        
        request.logger.info("🧪 Development mode: Injected mock ALB headers for \(user.email)")
        
        // Process as normal ALB request
        return try await validateALBHeaders(request: request, next: next)
    }
}

struct DevelopmentUser {
    let email: String
    let name: String
    let groups: [String]
    let sub: String
    
    init(email: String, name: String, groups: [String]) {
        self.email = email
        self.name = name  
        self.groups = groups
        self.sub = email // Use email as sub for development
    }
    
    static let admin = DevelopmentUser(
        email: "admin@neonlaw.com",
        name: "Development Admin",
        groups: ["admin", "staff", "customer"]
    )
    
    static let staff = DevelopmentUser(
        email: "staff@neonlaw.com", 
        name: "Development Staff",
        groups: ["staff", "customer"]
    )
    
    static let customer = DevelopmentUser(
        email: "customer@example.com",
        name: "Development Customer", 
        groups: ["customer"]
    )
}
```

#### 2. Development Configuration in App.swift

```swift
// In Bazaar/App.swift configure function
public func configureApp(_ app: Application) async throws {
    // ... existing configuration ...
    
    let oidcConfig = OIDCConfiguration.create(from: app.environment)
    let albAuthMiddleware: ALBAuthMiddleware
    
    if app.environment == .development {
        // Use mock authentication for development
        let devUser = DevelopmentUser.admin // Default to admin for development
        albAuthMiddleware = ALBAuthMiddleware(
            configuration: oidcConfig, 
            developmentUser: devUser
        )
        app.logger.info("🧪 Development mode: Using mock ALB authentication as \(devUser.email)")
    } else {
        // Use real ALB authentication for production/testing
        albAuthMiddleware = ALBAuthMiddleware(configuration: oidcConfig)
    }
    
    // ... rest of configuration
}
```

#### 3. nginx Proxy Simulation (Alternative Approach)

For teams wanting to simulate the full ALB experience:

**docker-compose.development.yml:**

```yaml
services:
  nginx-alb:
    image: nginx:alpine
    ports:
      - "8081:80"
    volumes:
      - ./nginx-alb-simulator.conf:/etc/nginx/conf.d/default.conf
      - ./nginx-auth-sim.lua:/etc/nginx/auth-sim.lua
    depends_on:
      - dex
      - app
      
  app:
    build: .
    environment:
      - ENV=development
      - MOCK_ALB=false  # Use nginx simulation instead
    ports:
      - "8080:8080"
    depends_on:
      - postgres
      - redis
```

**nginx-alb-simulator.conf:**

```nginx
server {
    listen 80;
    server_name localhost;
    
    # Simulate ALB authentication check
    location / {
        # Check for auth cookie
        set $authenticated "";
        if ($cookie_alb_auth) {
            set $authenticated "true";
        }
        
        # If not authenticated, redirect to Dex
        if ($authenticated = "") {
            return 302 http://localhost:2222/auth?client_id=luxe-client&redirect_uri=http://localhost:8081/auth/callback&response_type=code&scope=openid+email+profile;
        }
        
        # If authenticated, add ALB headers and proxy to app
        proxy_pass http://app:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        
        # Mock ALB authentication headers
        proxy_set_header X-Amzn-Oidc-Identity "admin@neonlaw.com";
        proxy_set_header X-Amzn-Oidc-Data "eyJ0eXAiOiJKV1QiLCJhbGciOiJFUzI1NiIsImtpZCI6IjEifQ.eyJpc3MiOiJkZXYtYWxiIiwiYXVkIjoibHV4ZS1jbGllbnQiLCJleHAiOjk5OTk5OTk5OTksInN1YiI6ImFkbWluQG5lb25sYXcuY29tIiwiZW1haWwiOiJhZG1pbkBuZW9ubGF3LmNvbSIsIm5hbWUiOiJEZXZlbG9wbWVudCBBZG1pbiIsImNvZ25pdG9fZ3JvdXBzIjpbImFkbWluIiwic3RhZmYiLCJjdXN0b21lciJdfQ.mock-signature";
        proxy_set_header X-Amzn-Oidc-Accesstoken "dev-access-token";
    }
    
    # OAuth callback endpoint
    location /auth/callback {
        # Set authentication cookie
        add_header Set-Cookie "alb_auth=authenticated; Path=/; HttpOnly; SameSite=Lax";
        return 302 /;
    }
}
```

#### 4. Testing Utilities for Different User Types

**TestUtilities/ALBAuthTestHelpers.swift:**

```swift
import Vapor

extension Application {
    func withALBAuth(as userType: TestUserType = .admin) {
        let user = userType.developmentUser
        let mockJWT = createMockALBJWT(for: user)
        
        self.middleware.use(MockALBHeaderMiddleware(
            identity: user.email,
            oidcData: mockJWT,
            accessToken: "test-access-token"
        ), at: .beginning)
    }
}

enum TestUserType {
    case admin, staff, customer
    
    var developmentUser: DevelopmentUser {
        switch self {
        case .admin: return .admin
        case .staff: return .staff  
        case .customer: return .customer
        }
    }
}

struct MockALBHeaderMiddleware: AsyncMiddleware {
    let identity: String
    let oidcData: String
    let accessToken: String
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        request.headers.replaceOrAdd(name: "X-Amzn-Oidc-Identity", value: identity)
        request.headers.replaceOrAdd(name: "X-Amzn-Oidc-Data", value: oidcData)
        request.headers.replaceOrAdd(name: "X-Amzn-Oidc-Accesstoken", value: accessToken)
        return try await next.respond(to: request)
    }
}
```

#### 5. Developer Experience Commands

Add convenience commands for switching user types:

**scripts/dev-auth.sh:**

```bash
#!/bin/bash

USER_TYPE=${1:-admin}

case $USER_TYPE in
    "admin")
        export DEV_USER_EMAIL="admin@neonlaw.com"
        export DEV_USER_GROUPS="admin,staff,customer"
        ;;
    "staff")
        export DEV_USER_EMAIL="staff@neonlaw.com" 
        export DEV_USER_GROUPS="staff,customer"
        ;;
    "customer")
        export DEV_USER_EMAIL="customer@example.com"
        export DEV_USER_GROUPS="customer"
        ;;
    *)
        echo "Usage: $0 [admin|staff|customer]"
        exit 1
        ;;
esac

echo "🧪 Development authentication set to: $DEV_USER_EMAIL"
echo "🎭 User groups: $DEV_USER_GROUPS"
```

**Usage:**

```bash
# Run as admin (default)
./scripts/dev-auth.sh admin && swift run BazaarServer

# Run as staff user  
./scripts/dev-auth.sh staff && swift run BazaarServer

# Run as customer
./scripts/dev-auth.sh customer && swift run BazaarServer
```

#### 6. Integration with Existing Dex Service

The project already has Dex configured - we can extend it for ALB simulation:

**dex-config.yaml Enhancement:**

```yaml
# Existing Dex config can be enhanced to simulate ALB flows
staticClients:
  - id: alb-simulator
    name: 'ALB Simulator'
    redirectURIs:
      - 'http://localhost:8081/auth/callback'
      - 'http://localhost:8080/auth/callback'
    secret: alb-dev-secret
    
  - id: luxe-client  # Existing client
    name: 'Luxe Development'
    # ... existing config
```

### Development Workflow Recommendations

#### Quick Development (Recommended)

1. Use environment-based mock authentication
2. Set DEV_USER_EMAIL and DEV_USER_GROUPS environment variables
3. ALBAuthMiddleware automatically injects headers in development mode
4. Switch user types by changing environment variables

#### Full ALB Simulation (Advanced)

1. Use nginx proxy with Dex integration  
2. Full OAuth flow simulation
3. Cookie-based session management
4. More realistic production behavior

#### Testing Strategy

1. Unit tests use MockALBHeaderMiddleware
2. Integration tests use Application.withALBAuth() extension
3. Different test user types for role-based testing
4. Automated switching between authenticated/unauthenticated states

This comprehensive approach provides flexibility for different development styles while maintaining compatibility
with the existing development infrastructure.
