import Dali
import Fluent
import Foundation
import JWT
import Vapor

/// Unified authentication strategy for Bouncer middleware
///
/// This enum defines the available authentication strategies that consuming targets
/// can use to protect their routes. Each strategy corresponds to different middleware
/// configurations and authentication flows.
///
/// ## Usage
///
/// ```swift
/// // Create JWT-only API routes
/// let api = app.grouped("api").grouped(
///     AuthenticationStrategy.jwt.middleware(oidcConfig: oidcConfig)
/// )
///
/// // Create OAuth-only HTML routes
/// let html = app.grouped(
///     AuthenticationStrategy.oauth.middleware(oidcConfig: oidcConfig)
/// )
///
/// // Create hybrid routes that accept either
/// let mixed = app.grouped(
///     AuthenticationStrategy.hybrid.middleware(oidcConfig: oidcConfig)
/// )
/// ```
public enum AuthenticationStrategy: Sendable {
    /// JWT Bearer token authentication only (for APIs)
    ///
    /// This strategy validates OAuth 2.0 Bearer tokens using OIDC JWT validation.
    /// Suitable for stateless API endpoints that require programmatic access.
    case jwt

    /// OAuth session authentication only (for HTML pages)
    ///
    /// This strategy uses OAuth authorization code flow with session-based
    /// authentication. Suitable for browser-based HTML pages that need login flows.
    case oauth

    /// Hybrid authentication (accepts either JWT or OAuth)
    ///
    /// This strategy first attempts JWT Bearer token validation, then falls back
    /// to OAuth session validation. Suitable for endpoints that serve both APIs
    /// and HTML pages.
    case hybrid

    /// Service account authentication (for bots and automated services)
    ///
    /// This strategy validates service account tokens using hash-based validation.
    /// Suitable for API endpoints that need to authenticate bots or automated services
    /// without OAuth flows.
    case serviceAccount

    /// Create authentication middleware for this strategy
    ///
    /// - Parameters:
    ///   - oidcConfig: OIDC configuration for JWT validation
    ///   - oauthConfig: OAuth configuration for session validation (optional)
    /// - Returns: Configured authentication middleware
    public func middleware(
        oidcConfig: OIDCConfiguration,
        oauthConfig: OAuthConfiguration? = nil
    ) -> AuthenticationMiddleware {
        AuthenticationMiddleware(
            strategy: self,
            oidcConfig: oidcConfig,
            oauthConfig: oauthConfig
        )
    }

    /// Get description of the authentication strategy
    public var description: String {
        switch self {
        case .jwt:
            return "JWT Bearer token authentication for API endpoints"
        case .oauth:
            return "OAuth session authentication for HTML pages"
        case .hybrid:
            return "Hybrid authentication supporting both JWT and OAuth"
        case .serviceAccount:
            return "Service account token authentication for bots and automated services"
        }
    }

    /// Check if strategy supports JWT Bearer tokens
    public var supportsJWT: Bool {
        switch self {
        case .jwt, .hybrid:
            return true
        case .oauth, .serviceAccount:
            return false
        }
    }

    /// Check if strategy supports OAuth sessions
    public var supportsOAuth: Bool {
        switch self {
        case .oauth, .hybrid:
            return true
        case .jwt, .serviceAccount:
            return false
        }
    }

    /// Check if strategy supports service account authentication
    public var supportsServiceAccount: Bool {
        switch self {
        case .serviceAccount:
            return true
        case .jwt, .oauth, .hybrid:
            return false
        }
    }
}

/// Authentication middleware factory for easier configuration
///
/// This struct provides factory methods to create authentication middleware
/// with common configurations, reducing boilerplate for consuming targets.
public struct AuthenticationFactory {
    private let oidcConfig: OIDCConfiguration
    private let oauthConfig: OAuthConfiguration?

    /// Initialize authentication factory
    ///
    /// - Parameters:
    ///   - oidcConfig: OIDC configuration for JWT validation
    ///   - oauthConfig: OAuth configuration for session validation (optional)
    public init(oidcConfig: OIDCConfiguration, oauthConfig: OAuthConfiguration? = nil) {
        self.oidcConfig = oidcConfig
        self.oauthConfig = oauthConfig
    }

    /// Create JWT-only authentication middleware
    ///
    /// Suitable for API endpoints that only accept Bearer tokens.
    public var jwtOnly: AuthenticationMiddleware {
        AuthenticationStrategy.jwt.middleware(
            oidcConfig: oidcConfig,
            oauthConfig: oauthConfig
        )
    }

    /// Create OAuth-only authentication middleware
    ///
    /// Suitable for HTML pages that use browser-based login flows.
    public var oauthOnly: AuthenticationMiddleware {
        AuthenticationStrategy.oauth.middleware(
            oidcConfig: oidcConfig,
            oauthConfig: oauthConfig
        )
    }

    /// Create hybrid authentication middleware
    ///
    /// Suitable for endpoints that need to serve both APIs and HTML pages.
    public var hybrid: AuthenticationMiddleware {
        AuthenticationStrategy.hybrid.middleware(
            oidcConfig: oidcConfig,
            oauthConfig: oauthConfig
        )
    }

    /// Create service account authentication middleware
    ///
    /// Suitable for API endpoints that authenticate bots and automated services.
    public var serviceAccount: AuthenticationMiddleware {
        AuthenticationStrategy.serviceAccount.middleware(
            oidcConfig: oidcConfig,
            oauthConfig: oauthConfig
        )
    }
}

/// Application extension for easier authentication configuration
extension Application {
    /// Create authentication factory for this application
    ///
    /// This factory can be used to create different authentication middleware
    /// configurations throughout the application.
    ///
    /// - Parameters:
    ///   - oidcConfig: OIDC configuration (optional, uses default from environment)
    ///   - oauthConfig: OAuth configuration (optional, uses default from environment)
    /// - Returns: Authentication factory for creating middleware
    public func authenticationFactory(
        oidcConfig: OIDCConfiguration? = nil,
        oauthConfig: OAuthConfiguration? = nil
    ) -> AuthenticationFactory {
        let finalOIDCConfig = oidcConfig ?? OIDCConfiguration.create(from: self.environment)
        let finalOAuthConfig = oauthConfig ?? OAuthConfiguration.create(from: self.environment)

        return AuthenticationFactory(
            oidcConfig: finalOIDCConfig,
            oauthConfig: finalOAuthConfig
        )
    }
}

/// Route builder extensions for authentication strategies
extension RoutesBuilder {
    /// Apply JWT authentication to route group
    ///
    /// - Parameter factory: Authentication factory to use
    /// - Returns: Route group with JWT authentication
    public func jwtAuthenticated(using factory: AuthenticationFactory) -> RoutesBuilder {
        self.grouped(factory.jwtOnly)
    }

    /// Apply OAuth authentication to route group
    ///
    /// - Parameter factory: Authentication factory to use
    /// - Returns: Route group with OAuth authentication
    public func oauthAuthenticated(using factory: AuthenticationFactory) -> RoutesBuilder {
        self.grouped(factory.oauthOnly)
    }

    /// Apply hybrid authentication to route group
    ///
    /// - Parameter factory: Authentication factory to use
    /// - Returns: Route group with hybrid authentication
    public func hybridAuthenticated(using factory: AuthenticationFactory) -> RoutesBuilder {
        self.grouped(factory.hybrid)
    }

    /// Apply service account authentication to route group
    ///
    /// - Parameter factory: Authentication factory to use
    /// - Returns: Route group with service account authentication
    public func serviceAccountAuthenticated(using factory: AuthenticationFactory) -> RoutesBuilder {
        self.grouped(factory.serviceAccount)
    }
}
