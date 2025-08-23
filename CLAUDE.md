# Luxe Project - Full-Stack Swift Development

You are an expert **full-stack Swift developer** building a Swift-only monorepo. All code must be Swift (except `.sql`,
`.md`, and asset files).

## Core Principles

### 🚀 Swift Everywhere

- **Server**: Vapor framework for APIs and web services
- **Client**: Swift for iOS/macOS apps
- **Shared**: Common Swift packages for models and business logic
- **Testing**: Swift Testing framework (never XCTest)
- **Infrastructure**: Swift-based CLI tools and scripts

### 📋 Development Rule: Roadmap-Only

**CRITICAL**: Never implement features directly. Always:
1. Create a roadmap first (if none exists)
2. Implement ONLY the current roadmap step
3. Add nothing extra - no optimizations, no "helpful" additions

### ✅ Quality Standards

- **Ask when unsure** - Never assume implementation details
- **Small changes** - Each commit should compile and pass tests
- **Cross-platform** - All code must work on macOS and Linux
- **No warnings** - Fix every warning, no matter how minor
- **Clean code** - Remove all trailing whitespace
- **Markdown formatting** - Always run `/format-markdown` after editing any markdown file and fix any linting issues

## Swift Patterns

### Protocol-Oriented Design

```swift
// Define capabilities through protocols
protocol Identifiable {
    var id: UUID { get }
}

protocol Timestamped {
    var createdAt: Date { get }
    var updatedAt: Date? { get }
}

// Compose protocols for complex types
struct User: Identifiable, Timestamped, Codable {
    let id = UUID()
    let createdAt = Date()
    var updatedAt: Date?
}
```

### Dependency Injection

```swift
protocol DatabaseService {
    func execute<T: Decodable>(_ query: String, as: T.Type) async throws -> T
}

struct UserService {
    let database: DatabaseService  // Inject protocol, not concrete type

    func getUser(id: UUID) async throws -> User {
        try await database.execute("SELECT * FROM users WHERE id = ?", as: User.self)
    }
}
```

## Full-Stack Architecture

### Server (Vapor)

```swift
// Clear request/response DTOs
struct CreateUserRequest: Content, Validatable {
    let email: String
    let name: String
}

// Service layer handles business logic
actor UserService {
    func create(from request: CreateUserRequest) async throws -> User {
        // Business logic here
    }
}

// Controller delegates to service
func create(req: Request) async throws -> UserResponse {
    let request = try req.content.decode(CreateUserRequest.self)
    let user = try await userService.create(from: request)
    return UserResponse(from: user)
}
```

### Client Integration

```swift
// Use generated OpenAPI client types
let client = APIClient(baseURL: URL(string: "https://api.example.com")!)
let user = try await client.users.create(
    body: .json(CreateUserRequest(email: "user@example.com", name: "John"))
)
```

### Shared Models

```swift
// Fluent models work across server and are type-safe
final class User: Model, Content {
    static let schema = "users"

    @ID var id: UUID?
    @Field(key: "email") var email: String
    @Field(key: "name") var name: String
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
}
```

## Modern Concurrency

```swift
// Use actors for thread-safe state
actor CacheManager {
    private var cache: [String: any Sendable] = [:]

    func get<T: Sendable>(_ key: String, as type: T.Type) -> T? {
        cache[key] as? T
    }
}

// Structured concurrency for parallel work
func processUsers(_ ids: [UUID]) async throws -> [User] {
    try await withThrowingTaskGroup(of: User.self) { group in
        for id in ids {
            group.addTask { try await self.fetchUser(id) }
        }
        return try await group.reduce(into: []) { $0.append($1) }
    }
}
```

## Testing with Swift Testing

```swift
import Testing

@Suite("User Service")
struct UserServiceTests {
    @Test("Creates user with valid email")
    func testCreateUser() async throws {
        let service = UserService(database: MockDatabase())
        let user = try await service.create(email: "test@example.com")
        #expect(user.email == "test@example.com")
    }
}
```

## Database & Migrations

### Migration Rules

1. SQL files only in `Palette` target
2. Never modify existing migrations
3. Always use UUIDs for primary keys
4. Include timestamps (created_at, updated_at)

### Example Migration

```sql
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## API Development

### OpenAPI-First Workflow

1. Define endpoint in `openapi.yaml`
2. Generate Swift types
3. Implement in `BazaarAPIServer`
4. Test with generated client

### Service Layer Pattern

- HTTP handlers delegate to services
- Services contain business logic
- Repositories handle data access
- Everything is testable

## Development Workflow

### TDD Steps

1. Write Swift Testing test
2. Run: `swift test --filter TestName`
3. Implement code
4. Verify: `swift test`
5. Commit with conventional format

### Quick Start

```bash
# Setup environment
./scripts/setup-development-environment.sh

# Run tests
swift test

# Start server
swift run BazaarServer
```

## Error Handling

```swift
enum ServiceError: Error, LocalizedError {
    case notFound(String)
    case validation([String: String])
    case unauthorized(String)

    var httpStatus: HTTPStatus {
        switch self {
        case .notFound: return .notFound
        case .validation: return .badRequest
        case .unauthorized: return .unauthorized
        }
    }
}
```

## Security

- OAuth2/OIDC via Dex (local) or Cognito (production)
- JWT validation for all API requests
- Role-based access control (customer, staff, admin)
- Row-level security in PostgreSQL

## What You Must NEVER Do

1. **Never** implement without a roadmap
2. **Never** use XCTest (only Swift Testing)
3. **Never** write non-Swift code (except SQL/Markdown)
4. **Never** modify existing migrations
5. **Never** create manual Vapor routes (use OpenAPI)
6. **Never** put business logic in controllers
7. **Never** assume implementation details - always ask

## Key Resources

- [Swift Evolution](https://www.swift.org/swift-evolution/)
- [Vapor Documentation](https://docs.vapor.codes/)
- [Swift OpenAPI Generator](https://github.com/apple/swift-openapi-generator)
- [Swift Testing](https://github.com/apple/swift-testing)
