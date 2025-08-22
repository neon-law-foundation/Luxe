import Bouncer
import Dali
import Testing
import Vapor

@Suite("Authentication Middleware", .serialized)
struct AuthenticationMiddlewareTests {
    @Test("JWT strategy configuration")
    func jwtStrategyConfiguration() async throws {
        // Ensure development environment
        setenv("ENV", "DEVELOPMENT", 1)
        defer { unsetenv("ENV") }

        // Test JWT strategy creation
        let oidcConfig = OIDCConfiguration.create(from: .development)
        let authMiddleware = AuthenticationMiddleware(strategy: .jwt, oidcConfig: oidcConfig)

        #expect(authMiddleware.strategy == .jwt)
        #expect(
            authMiddleware.oidcConfig.issuer == "http://localhost:2222/dex"
                || authMiddleware.oidcConfig.issuer == "http://0.0.0.0:2222/dex"
        )
    }

    @Test("OAuth strategy configuration")
    func oauthStrategyConfiguration() async throws {
        // Ensure development environment
        setenv("ENV", "DEVELOPMENT", 1)
        defer { unsetenv("ENV") }

        // Test OAuth strategy creation
        let oidcConfig = OIDCConfiguration.create(from: .development)
        let oauthConfig = OAuthConfiguration.create(from: .development)
        let authMiddleware = AuthenticationMiddleware(
            strategy: .oauth,
            oidcConfig: oidcConfig,
            oauthConfig: oauthConfig
        )

        #expect(authMiddleware.strategy == .oauth)
        #expect(authMiddleware.oauthConfig?.callbackURL == "http://localhost:8080/auth/dex/callback")
    }

    @Test("hybrid strategy configuration")
    func hybridStrategyConfiguration() async throws {
        // Ensure development environment
        setenv("ENV", "DEVELOPMENT", 1)
        defer { unsetenv("ENV") }

        // Test hybrid strategy creation
        let oidcConfig = OIDCConfiguration.create(from: .development)
        let authMiddleware = AuthenticationMiddleware(strategy: .hybrid, oidcConfig: oidcConfig)

        #expect(authMiddleware.strategy == .hybrid)
        #expect(authMiddleware.oidcConfig.clientId == "luxe-client")
    }

    @Test("production configuration uses Cognito")
    func productionConfigurationUsesCognito() async throws {
        // Set production environment
        setenv("ENV", "PRODUCTION", 1)
        setenv("COGNITO_CLIENT_ID", "test-client-id", 1)
        setenv("COGNITO_CLIENT_SECRET", "test-client-secret", 1)
        defer {
            unsetenv("ENV")
            unsetenv("COGNITO_CLIENT_ID")
            unsetenv("COGNITO_CLIENT_SECRET")
        }

        // Verify ENV is set to PRODUCTION
        #expect(Environment.get("ENV") == "PRODUCTION")

        let oidcConfig = OIDCConfiguration.create(from: .production)
        let oauthConfig = OAuthConfiguration.create(from: .production)

        #expect(oidcConfig.issuer.contains("cognito"))
        #expect(oauthConfig.callbackURL.contains("api.sagebrush.services"))
    }
}
