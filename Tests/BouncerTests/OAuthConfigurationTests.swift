import Bouncer
import Testing
import Vapor

@Suite("OAuth Configuration", .serialized)
struct OAuthConfigurationTests {
    @Test("creates OAuth configuration for development")
    func createsOAuthConfigForDevelopment() async throws {
        // Ensure we're in development mode
        setenv("ENV", "DEVELOPMENT", 1)
        defer { unsetenv("ENV") }

        let config = OAuthConfiguration.create(from: .development)

        // Verify Dex provider is configured
        #expect(config.provider is DexOAuthProvider)
        #expect(config.callbackURL == "http://localhost:8080/auth/dex/callback")
    }

    @Test("creates OAuth configuration for production")
    func createsOAuthConfigForProduction() async throws {
        // Set production environment
        setenv("ENV", "PRODUCTION", 1)
        setenv("COGNITO_CLIENT_ID", "test-client-id", 1)
        setenv("COGNITO_CLIENT_SECRET", "test-client-secret", 1)
        defer {
            unsetenv("ENV")
            unsetenv("COGNITO_CLIENT_ID")
            unsetenv("COGNITO_CLIENT_SECRET")
        }

        let config = OAuthConfiguration.create(from: .production)

        // Verify Cognito provider is configured
        #expect(config.provider is CognitoOAuthProvider)
        #expect(config.callbackURL == "https://api.sagebrush.services/auth/cognito/callback")
    }

    @Test("Cognito OAuth generates correct auth URL")
    func cognitoAuthURLGeneration() async throws {
        let provider = CognitoOAuthProvider(
            domain: "https://test.auth.us-west-2.amazoncognito.com",
            clientId: "test-client",
            clientSecret: "test-secret"
        )

        let authURL = provider.authorizationURL(
            state: "test-state",
            redirectURI: "https://example.com/callback"
        )

        #expect(authURL.contains("response_type=code"))
        #expect(authURL.contains("client_id=test-client"))
        #expect(authURL.contains("redirect_uri=https://example.com/callback"))
        #expect(authURL.contains("scope=openid%20email%20profile"))
        #expect(authURL.contains("state=test-state"))
    }

    @Test("Dex OAuth generates correct auth URL")
    func dexAuthURLGeneration() async throws {
        let provider = DexOAuthProvider(
            baseURL: "http://localhost:2222",
            clientId: "test-client",
            clientSecret: "test-secret"
        )

        let authURL = provider.authorizationURL(
            state: "test-state",
            redirectURI: "http://localhost:8080/callback"
        )

        #expect(authURL.contains("/dex/auth"))
        #expect(authURL.contains("response_type=code"))
        #expect(authURL.contains("client_id=test-client"))
        #expect(authURL.contains("redirect_uri=http://localhost:8080/callback"))
        #expect(authURL.contains("scope=openid%20email%20profile"))
        #expect(authURL.contains("state=test-state"))
    }

    @Test("Cognito provider extracts user info from token")
    func cognitoExtractsUserInfo() async throws {
        let provider = CognitoOAuthProvider(
            domain: "https://test.auth.us-west-2.amazoncognito.com",
            clientId: "test-client",
            clientSecret: "test-secret"
        )

        // Create a mock ID token
        let claims = """
            {"sub":"123456","email":"test@example.com","name":"Test User"}
            """
        let encodedClaims = claims.data(using: .utf8)!.base64EncodedString()
        let mockIdToken = "header.\(encodedClaims).signature"

        let tokenResponse = OAuthTokenResponse(
            access_token: "test-access-token",
            token_type: "Bearer",
            expires_in: 3600,
            id_token: mockIdToken,
            refresh_token: nil
        )

        let userInfo = try await provider.extractUserInfo(from: tokenResponse)

        #expect(userInfo.sub == "test@example.com")
        #expect(userInfo.email == "test@example.com")
        #expect(userInfo.name == "Test User")
    }

    @Test("Dex provider extracts user info from ID token")
    func dexExtractsUserInfo() async throws {
        let provider = DexOAuthProvider(
            baseURL: "http://localhost:2222",
            clientId: "test-client",
            clientSecret: "test-secret"
        )

        // Create a mock ID token (Dex uses ID token for user info)
        let claims = """
            {"sub":"123456","email":"test@example.com","name":"Test User","preferred_username":"testuser"}
            """
        let encodedClaims = claims.data(using: .utf8)!.base64EncodedString()
        let mockIdToken = "header.\(encodedClaims).signature"

        let tokenResponse = OAuthTokenResponse(
            access_token: "test-access-token",
            token_type: "Bearer",
            expires_in: 3600,
            id_token: mockIdToken,
            refresh_token: "test-refresh-token"
        )

        let userInfo = try await provider.extractUserInfo(from: tokenResponse)

        #expect(userInfo.sub == "test@example.com")
        #expect(userInfo.email == "test@example.com")
        #expect(userInfo.name == "Test User")
    }
}
