# PitBoss Slack Bot - Research & Design Document

## Executive Summary

PitBoss is a Slack bot designed to provide real-time team metrics and system health information through slash
commands. This document outlines the research findings and architectural design for implementing a secure, scalable
Slack bot integration with the Luxe platform.

## Current Authentication Patterns

### Existing Bouncer Authentication Strategies

The Bouncer authentication system currently implements three authentication strategies via the `AuthenticationStrategy` enum:

1. **JWT Authentication** (`jwt`): Bearer token validation using OIDC JWT validation for stateless API
   endpoints
2. **OAuth Authentication** (`oauth`): Session-based authentication using OAuth authorization code flow for
   browser-based HTML pages
3. **Hybrid Authentication** (`hybrid`): Attempts JWT first, then falls back to OAuth session validation

### Authentication Middleware Architecture

```swift
AuthenticationStrategy -> AuthenticationMiddleware -> Route Protection
```

Key components:

- **OIDCConfiguration**: Handles JWT validation configuration
- **OAuthConfiguration**: Manages OAuth session validation
- **AuthenticationFactory**: Provides factory methods for creating middleware with common configurations
- **CurrentUser**: Stores authenticated user information in request storage

### Analysis of Extension Points

The current authentication system is well-structured for extension. Key considerations:

1. The `AuthenticationStrategy` enum is the central point for adding new authentication types
2. Middleware implements the Vapor `Middleware` protocol for seamless integration
3. Request storage pattern is already established for user context

## Slack Webhook Requirements

### Security Constraints

1. **Request Signature Verification**: All incoming webhooks must be verified using HMAC-SHA256 with Slack's signing secret
2. **Timestamp Validation**: Requests older than 5 minutes should be rejected to prevent replay attacks
3. **SSL/TLS**: All webhook endpoints must use HTTPS
4. **Rate Limiting**: Implement rate limiting to prevent abuse (Slack recommends 1 request per second per workspace)

### Webhook Payload Structure

Slack sends three main types of payloads:

1. **URL Verification**: Initial handshake to verify endpoint ownership
2. **Event Callbacks**: Asynchronous events from workspace activity
3. **Slash Commands**: Synchronous command invocations requiring immediate response

### Response Requirements

- **Timeout**: Must respond within 3 seconds for slash commands
- **Format**: Responses can be plain text or Block Kit formatted JSON
- **Visibility**: Can be ephemeral (visible only to user) or in_channel (visible to all)
- **Deferred Responses**: For long-running operations, acknowledge immediately and send response to response_url

## Existing Metrics Patterns in Dali

### Current Analytics Implementation

The `NewsletterAnalyticsService` demonstrates existing patterns for metrics collection:

1. **Event Tracking**: Records individual events with metadata
2. **Aggregation**: Uses SQL GROUP BY for summary statistics
3. **Rate Calculations**: Computes derived metrics (open rate, click rate)
4. **Database-Direct**: Uses PostgreSQL directly for complex queries

### Applicable Patterns for Team Metrics

1. **Service Layer Pattern**: Encapsulate metrics logic in dedicated services
2. **Async/Await**: All database operations use Swift concurrency
3. **Type Safety**: Strong typing for metrics responses using Codable structs
4. **Error Handling**: Proper error types for service-level failures

## Service Account Authentication Design

### Proposed Extension to Bouncer

#### 1. New Authentication Strategy

```swift
public enum AuthenticationStrategy: Sendable {
    case jwt
    case oauth
    case hybrid
    case serviceAccount  // New strategy for bot/service authentication
}
```

#### 2. Service Account Token Model

The service account token will be stored in the database with:

- **Token Hash**: SHA256 hash of the actual token (never store plaintext)
- **Service Type**: Enum identifying the service (slackBot, cicd, monitoring)
- **Expiration**: Optional expiration date for token rotation
- **Rate Limits**: Configurable rate limits per service type
- **Audit Fields**: Last used timestamp, creation date

#### 3. Middleware Implementation

```swift
ServiceAccountAuthenticationMiddleware:
1. Extract Bearer token from Authorization header
2. Hash token and lookup in database
3. Validate expiration and active status
4. Update last_used timestamp
5. Set service account context in request storage
6. Apply rate limiting based on service type
```

#### 4. Security Considerations

1. **Token Generation**: Use cryptographically secure random generation (32+ bytes)
2. **Token Rotation**: Support gradual rotation with overlapping validity periods
3. **Scope Limitation**: Service accounts have limited, predefined permissions
4. **Audit Logging**: All service account actions are logged
5. **Rate Limiting**: Prevent abuse through configurable rate limits

## Metrics Service Architecture

### Design Principles

1. **Caching Layer**: Implement Redis caching for frequently accessed metrics
2. **Async Collection**: Use background jobs for expensive aggregations
3. **Granularity Levels**: Support daily, weekly, monthly aggregations
4. **Real-time vs. Cached**: Balance between accuracy and performance

### Proposed Metrics Categories

#### User Metrics

- Total users by role
- Active users (various time windows)
- User growth trends
- Last login statistics
- Role distribution

#### Entity Metrics

- Total entities by type
- Entity creation trends
- Geographic distribution
- Relationship mappings

#### System Health Metrics

- Database connection pool status
- Memory usage
- CPU utilization
- Request latency percentiles
- Error rates

### Caching Strategy

```text
Request -> Cache Check -> Cache Hit? -> Return Cached
                        -> Cache Miss -> Compute -> Cache -> Return
```

- **TTL**: 5 minutes for user metrics, 15 minutes for entity metrics
- **Invalidation**: Event-based invalidation for critical updates
- **Warmup**: Pre-compute common metrics on schedule

## PitBoss Implementation Plan

### Package Structure

```text
Sources/PitBoss/
├── main.swift              # CLI entry point
├── SlackBot.swift          # Core bot logic
├── SlackModels.swift       # Request/Response models
├── SlackSignatureMiddleware.swift  # Request verification
├── Commands/
│   ├── MetricsCommand.swift
│   ├── HealthCommand.swift
│   └── HelpCommand.swift
└── Services/
    └── MetricsCollector.swift
```

### Deployment Architecture

```text
[Slack] -> [API Gateway] -> [PitBoss Container] -> [Database]
                                    |
                                [Redis Cache]
```

### Configuration Management

Environment variables:

- `SLACK_SIGNING_SECRET`: For request verification
- `SLACK_BOT_TOKEN`: For Slack API calls
- `SERVICE_ACCOUNT_TOKEN`: For internal API authentication
- `DATABASE_URL`: PostgreSQL connection string
- `REDIS_URL`: Redis cache connection

## Security Recommendations

### Defense in Depth

1. **Network Layer**: IP allowlisting for Slack's IP ranges
2. **Transport Layer**: TLS 1.3 minimum, certificate pinning
3. **Application Layer**: Request signature verification, rate limiting
4. **Data Layer**: Encryption at rest, field-level encryption for sensitive data

### Token Security

1. **Storage**: Never log or store tokens in plaintext
2. **Transmission**: Always use secure channels (HTTPS/TLS)
3. **Rotation**: Implement automatic rotation every 90 days
4. **Revocation**: Support immediate revocation with audit trail

### Monitoring & Alerting

1. **Failed Authentication**: Alert on repeated failures
2. **Rate Limit Violations**: Track and alert on abuse patterns
3. **Token Usage**: Monitor unusual usage patterns
4. **System Health**: Alert on degraded performance

## Performance Considerations

### Optimization Strategies

1. **Connection Pooling**: Reuse database connections
2. **Batch Queries**: Aggregate multiple metrics in single query
3. **Parallel Processing**: Use TaskGroup for concurrent operations
4. **Circuit Breaker**: Fail fast when dependencies are unavailable

### Scalability Plan

1. **Horizontal Scaling**: Stateless design allows multiple instances
2. **Load Balancing**: Distribute requests across instances
3. **Database Replicas**: Read from replicas for metrics queries
4. **Cache Clustering**: Redis cluster for high availability

## Risk Analysis

### Technical Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Token Compromise | High | Token hashing, rotation, monitoring |
| Rate Limit Abuse | Medium | Progressive rate limiting, IP blocking |
| Cache Poisoning | Low | Input validation, TTL limits |
| Database Overload | Medium | Query optimization, caching, replicas |

### Operational Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Service Downtime | High | Health checks, auto-restart, redundancy |
| Slow Response Times | Medium | Performance monitoring, caching |
| Configuration Drift | Low | Infrastructure as Code, GitOps |

## Implementation Timeline

### Phase 0: Research & Planning (Current)

- Document requirements and design
- Analyze existing patterns
- Design security architecture

### Phase 1: Authentication & Security

- Implement service account authentication
- Create database migrations
- Add security middleware

### Phase 2: Data Layer

- Create metrics services
- Implement caching layer
- Add database indexes

### Phase 3: Slack Integration

- Build PitBoss package
- Implement slash commands
- Add webhook handlers

### Phase 4: API Endpoints

- Extend Bazaar API
- Add OpenAPI specifications
- Configure CORS

### Phase 5: Testing & Documentation

- Write comprehensive tests
- Create deployment documentation
- Performance testing

## Conclusion

The PitBoss Slack bot can be successfully integrated with the existing Luxe architecture by:

1. Extending the Bouncer authentication system with service account support
2. Leveraging existing Dali patterns for metrics collection
3. Implementing secure webhook handling with signature verification
4. Using caching strategies to ensure performance
5. Following Swift best practices and the existing codebase conventions

The proposed design prioritizes security, performance, and maintainability while integrating seamlessly with the
existing Luxe platform architecture.

## Next Steps

1. Review and approve this design document
2. Create service account token database schema
3. Implement ServiceAccountAuthenticationMiddleware
4. Begin PitBoss package development
5. Set up Slack app configuration

## References

- [Slack API Documentation](https://api.slack.com/)
- [Vapor Security Best Practices](https://docs.vapor.codes/security/overview/)
- [Swift Concurrency Guide](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [OWASP API Security Top 10](https://owasp.org/www-project-api-security/)
