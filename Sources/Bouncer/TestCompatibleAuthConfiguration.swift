import Dali
import Foundation
import Vapor

// Note: Some dependencies are available only when running within Bazaar context
// This is handled by conditional compilation and runtime checks

/// Configuration for test-compatible authentication that respects transaction boundaries
///
/// This system provides a unified way to configure authentication middleware that works
/// both in production (with database queries) and in tests (with mock users that don't
/// require database access, thus respecting transaction isolation).
///
/// ## Usage
///
/// ### Production Configuration
/// ```swift
/// let authConfig = TestCompatibleAuthConfiguration(
///     strategy: .production(oidcConfig: oidcConfig)
/// )
/// try authConfig.configureAuthentication(app)
/// ```
///
/// ### Test Configuration
/// ```swift
/// let authConfig = TestCompatibleAuthConfiguration(
///     strategy: .test
/// )
/// try authConfig.configureAuthentication(app)
/// ```
///
/// ## Transaction Isolation Benefits
///
/// When using `.test` strategy:
/// - Authentication middleware creates mock users in-memory
/// - No database queries performed during authentication
/// - Test data within transactions remains isolated
/// - HTTP tests can authenticate without database conflicts
public struct TestCompatibleAuthConfiguration {

    /// Authentication strategy determining which middleware to use
    public enum Strategy {
        /// Production strategy using database-backed authentication
        case production(oidcConfig: OIDCConfiguration)

        /// Test strategy using in-memory mock authentication
        case test

        /// Automatic selection based on environment
        case automatic(oidcConfig: OIDCConfiguration)
    }

    /// The authentication strategy to use
    public let strategy: Strategy

    /// Creates a new test-compatible authentication configuration
    ///
    /// - Parameter strategy: The authentication strategy to use
    public init(strategy: Strategy) {
        self.strategy = strategy
    }

    /// Configures authentication middleware based on the selected strategy
    ///
    /// This method sets up the appropriate middleware stack and configures routes
    /// with the correct authentication middleware based on the strategy.
    ///
    /// - Parameter app: The Vapor application to configure
    /// - Throws: Configuration errors if setup fails
    public func configureAuthentication(_ app: Application) throws {
        let selectedStrategy = resolveStrategy(for: app.environment)

        switch selectedStrategy {
        case .production(let oidcConfig):
            try configureProductionAuthentication(app, oidcConfig: oidcConfig)
        case .test:
            try configureTestAuthentication(app)
        case .automatic:
            fatalError("Automatic strategy should have been resolved")
        }
    }

    /// Creates a test authentication middleware for protected routes
    ///
    /// This method returns TestAuthMiddleware that can be used for protected routes
    /// in test environments, bypassing database queries.
    ///
    /// - Returns: TestAuthMiddleware instance
    public func createTestAuthMiddleware() -> TestAuthMiddleware {
        TestAuthMiddleware()
    }

    // MARK: - Private Implementation

    /// Resolves automatic strategy based on environment
    private func resolveStrategy(for environment: Environment) -> Strategy {
        switch strategy {
        case .automatic(let oidcConfig):
            if environment == .testing {
                return .test
            } else {
                return .production(oidcConfig: oidcConfig)
            }
        default:
            return strategy
        }
    }

    /// Configures production authentication with database-backed middleware
    private func configureProductionAuthentication(_ app: Application, oidcConfig: OIDCConfiguration) throws {
        app.logger.info("Configuring production authentication with database queries")

        // Store OIDC configuration for route group creation
        app.storage[OIDCConfigurationKey.self] = oidcConfig

        // Add PostgreSQL role middleware for database role switching
        app.middleware.use(PostgresRoleMiddleware())

        app.logger.info("Production authentication configured successfully")
    }

    /// Configures test authentication with transaction-safe mock middleware
    private func configureTestAuthentication(_ app: Application) throws {
        app.logger.info("Configuring test authentication with transaction isolation support")

        // Test authentication doesn't need session middleware or Postgres role middleware
        // as it creates mock users directly without database queries

        app.logger.info("Test authentication configured successfully - no database dependencies")
    }
}

/// Storage key for OIDC configuration in production mode
private struct OIDCConfigurationKey: StorageKey {
    typealias Value = OIDCConfiguration
}

/// Extension to retrieve OIDC configuration from storage
extension Application {
    /// Gets the stored OIDC configuration (available only in production mode)
    var oidcConfiguration: OIDCConfiguration? {
        get { storage[OIDCConfigurationKey.self] }
        set { storage[OIDCConfigurationKey.self] = newValue }
    }
}
