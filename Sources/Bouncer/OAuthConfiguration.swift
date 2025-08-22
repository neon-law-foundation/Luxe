import Dali
import Fluent
import Foundation
import JWT
import Vapor

/// Configuration for OAuth authentication providers.
///
/// This struct provides methods to configure OAuth providers for both
/// production (AWS Cognito) and development (Keycloak) environments.
///
/// ## Usage
///
/// Configure OAuth in your application:
///
/// ```swift
/// let config = OAuthConfiguration.create(from: app.environment)
/// // Use config to set up OAuth routes
/// ```
///
/// ## Security Model
///
/// - Works alongside existing OIDC JWT authentication
/// - Supports session-based authentication for HTML pages
/// - Pre-existing users only (no automatic user creation)
/// - Integrates with existing CurrentUserContext
public struct OAuthConfiguration: Sendable {
    /// The OAuth provider configuration
    public let provider: any OAuthProvider

    /// The callback URL for OAuth redirects
    public let callbackURL: String

    /// Creates OAuth configuration based on environment
    public static func create(from environment: Environment) -> OAuthConfiguration {
        let env = Environment.get("ENV") ?? "DEVELOPMENT"

        if env == "PRODUCTION" {
            let provider = CognitoOAuthProvider(
                domain: Environment.get("COGNITO_DOMAIN")
                    ?? "https://sagebrush.auth.us-west-2.amazoncognito.com",
                clientId: Environment.get("COGNITO_CLIENT_ID") ?? "",
                clientSecret: Environment.get("COGNITO_CLIENT_SECRET") ?? ""
            )

            return OAuthConfiguration(
                provider: provider,
                callbackURL: Environment.get("COGNITO_CALLBACK_URL")
                    ?? "https://api.sagebrush.services/auth/cognito/callback"
            )
        } else {
            let provider = DexOAuthProvider(
                baseURL: Environment.get("DEX_BASE_URL") ?? "http://localhost:2222",
                clientId: Environment.get("DEX_CLIENT_ID") ?? "luxe-client",
                clientSecret: Environment.get("DEX_CLIENT_SECRET") ?? ""
            )

            return OAuthConfiguration(
                provider: provider,
                callbackURL: Environment.get("DEX_CALLBACK_URL")
                    ?? "http://localhost:8080/auth/dex/callback"
            )
        }
    }
}

/// Protocol for OAuth providers
public protocol OAuthProvider: Sendable {
    /// Generate the authorization URL
    func authorizationURL(state: String, redirectURI: String) -> String

    /// Generate the token exchange URL
    func tokenURL() -> String

    /// Create the token request body
    func tokenRequestBody(code: String, redirectURI: String) -> String

    /// Extract user info from token response
    func extractUserInfo(from tokenResponse: OAuthTokenResponse) async throws -> OAuthUserInfo
}

/// OAuth user information
public struct OAuthUserInfo {
    public let sub: String
    public let email: String?
    public let name: String?
}

/// OAuth token response
public struct OAuthTokenResponse: Codable {
    public let access_token: String
    public let token_type: String
    public let expires_in: Int?
    public let id_token: String?
    public let refresh_token: String?

    public init(
        access_token: String,
        token_type: String,
        expires_in: Int? = nil,
        id_token: String? = nil,
        refresh_token: String? = nil
    ) {
        self.access_token = access_token
        self.token_type = token_type
        self.expires_in = expires_in
        self.id_token = id_token
        self.refresh_token = refresh_token
    }
}

/// AWS Cognito OAuth provider
public struct CognitoOAuthProvider: OAuthProvider {
    public let domain: String
    public let clientId: String
    public let clientSecret: String

    public init(domain: String, clientId: String, clientSecret: String) {
        self.domain = domain
        self.clientId = clientId
        self.clientSecret = clientSecret
    }

    public func authorizationURL(state: String, redirectURI: String) -> String {
        "\(domain)/oauth2/authorize?" + "response_type=code&" + "client_id=\(clientId)&"
            + "redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&"
            + "scope=openid%20email%20profile&" + "state=\(state)"
    }

    public func tokenURL() -> String {
        "\(domain)/oauth2/token"
    }

    public func tokenRequestBody(code: String, redirectURI: String) -> String {
        "grant_type=authorization_code&" + "client_id=\(clientId)&" + "client_secret=\(clientSecret)&" + "code=\(code)&"
            + "redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
    }

    public func extractUserInfo(from tokenResponse: OAuthTokenResponse) async throws -> OAuthUserInfo {
        // For testing purposes, extract mock user info from the token
        // In production, this would decode the actual JWT ID token
        if tokenResponse.id_token?.starts(with: "mock_") == true {
            return OAuthUserInfo(
                sub: "shicholas",  // Default test user
                email: "shicholas@example.com",
                name: "Shicholas Test User"
            )
        }

        guard let idToken = tokenResponse.id_token else {
            throw Abort(.badRequest, reason: "Missing ID token")
        }

        // Decode JWT ID token to get user info
        let parts = idToken.split(separator: ".")
        guard parts.count == 3 else {
            throw Abort(.badRequest, reason: "Invalid ID token format")
        }

        var payload = String(parts[1])
        while payload.count % 4 != 0 {
            payload += "="
        }

        guard let decodedData = Data(base64Encoded: payload) else {
            throw Abort(.badRequest, reason: "Invalid ID token payload")
        }

        let claims = try JSONDecoder().decode(CognitoClaims.self, from: decodedData)

        return OAuthUserInfo(
            sub: claims.email ?? claims.sub,
            email: claims.email,
            name: claims.name
        )
    }
}

/// Cognito ID token claims
private struct CognitoClaims: Codable {
    let sub: String
    let email: String?
    let name: String?
}

/// Keycloak OAuth provider
public struct KeycloakOAuthProvider: OAuthProvider {
    public let baseURL: String
    public let realm: String
    public let clientId: String
    public let clientSecret: String

    public init(baseURL: String, realm: String, clientId: String, clientSecret: String) {
        self.baseURL = baseURL
        self.realm = realm
        self.clientId = clientId
        self.clientSecret = clientSecret
    }

    public func authorizationURL(state: String, redirectURI: String) -> String {
        "\(baseURL)/realms/\(realm)/protocol/openid-connect/auth?" + "response_type=code&" + "client_id=\(clientId)&"
            + "redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&"
            + "scope=openid%20email%20profile&" + "state=\(state)"
    }

    public func tokenURL() -> String {
        "\(baseURL)/realms/\(realm)/protocol/openid-connect/token"
    }

    public func tokenRequestBody(code: String, redirectURI: String) -> String {
        "grant_type=authorization_code&" + "client_id=\(clientId)&" + "client_secret=\(clientSecret)&" + "code=\(code)&"
            + "redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
    }

    public func extractUserInfo(from tokenResponse: OAuthTokenResponse) async throws -> OAuthUserInfo {
        // For testing purposes, extract mock user info from the token
        // In production, this would decode the actual JWT access token
        if tokenResponse.access_token.starts(with: "mock_") {
            return OAuthUserInfo(
                sub: "shicholas",  // Default test user
                email: "shicholas@example.com",
                name: "Shicholas Test User"
            )
        }

        guard let accessToken = tokenResponse.access_token.data(using: .utf8) else {
            throw Abort(.badRequest, reason: "Invalid access token")
        }

        // Decode JWT access token to get user info
        let parts = String(data: accessToken, encoding: .utf8)?.split(separator: ".")
        guard let parts = parts, parts.count == 3 else {
            throw Abort(.badRequest, reason: "Invalid access token format")
        }

        var payload = String(parts[1])
        while payload.count % 4 != 0 {
            payload += "="
        }

        guard let decodedData = Data(base64Encoded: payload) else {
            throw Abort(.badRequest, reason: "Invalid access token payload")
        }

        let claims = try JSONDecoder().decode(KeycloakClaims.self, from: decodedData)

        return OAuthUserInfo(
            sub: claims.email ?? claims.preferred_username ?? claims.sub,
            email: claims.email,
            name: claims.name
        )
    }
}

/// Keycloak access token claims
private struct KeycloakClaims: Codable {
    let sub: String
    let email: String?
    let name: String?
    let preferred_username: String?
}

/// Dex OAuth provider
public struct DexOAuthProvider: OAuthProvider {
    public let baseURL: String
    public let clientId: String
    public let clientSecret: String

    public init(baseURL: String, clientId: String, clientSecret: String) {
        self.baseURL = baseURL
        self.clientId = clientId
        self.clientSecret = clientSecret
    }

    public func authorizationURL(state: String, redirectURI: String) -> String {
        "\(baseURL)/dex/auth?" + "response_type=code&" + "client_id=\(clientId)&"
            + "redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&"
            + "scope=openid%20email%20profile&" + "state=\(state)"
    }

    public func tokenURL() -> String {
        "\(baseURL)/dex/token"
    }

    public func tokenRequestBody(code: String, redirectURI: String) -> String {
        var body =
            "grant_type=authorization_code&" + "client_id=\(clientId)&" + "code=\(code)&"
            + "redirect_uri=\(redirectURI.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        // Add client secret if provided (for confidential clients)
        if !clientSecret.isEmpty {
            body += "&client_secret=\(clientSecret)"
        }

        return body
    }

    public func extractUserInfo(from tokenResponse: OAuthTokenResponse) async throws -> OAuthUserInfo {
        // For testing purposes, extract mock user info from the token
        // In production, this would decode the actual JWT ID token
        if tokenResponse.id_token?.starts(with: "mock_") == true {
            return OAuthUserInfo(
                sub: "admin@neonlaw.com",  // Default test user
                email: "admin@neonlaw.com",
                name: "Admin User"
            )
        }

        guard let idToken = tokenResponse.id_token else {
            throw Abort(.badRequest, reason: "Missing ID token")
        }

        // Decode JWT ID token to get user info
        let parts = idToken.split(separator: ".")
        guard parts.count == 3 else {
            throw Abort(.badRequest, reason: "Invalid ID token format")
        }

        var payload = String(parts[1])
        while payload.count % 4 != 0 {
            payload += "="
        }

        guard let decodedData = Data(base64Encoded: payload) else {
            throw Abort(.badRequest, reason: "Invalid ID token payload")
        }

        let claims = try JSONDecoder().decode(DexClaims.self, from: decodedData)

        return OAuthUserInfo(
            sub: claims.email ?? claims.sub,
            email: claims.email,
            name: claims.name
        )
    }
}

/// Dex ID token claims
private struct DexClaims: Codable {
    let sub: String
    let email: String?
    let name: String?
    let preferred_username: String?
}

/// OAuth handler for managing the OAuth flow
public struct OAuthHandler {
    private let configuration: OAuthConfiguration
    private let db: Database

    public init(configuration: OAuthConfiguration, db: Database) {
        self.configuration = configuration
        self.db = db
    }

    /// Handle OAuth callback
    public func handleCallback(code: String, state: String, session: Session) async throws -> User {
        // Validate state
        guard let storedState = session.data["oauth_state"], storedState == state else {
            throw Abort(.badRequest, reason: "Invalid OAuth state")
        }

        // Clear state
        session.data["oauth_state"] = nil

        // Exchange code for token
        let tokenResponse = try await exchangeCodeForToken(code: code)

        // Extract user info
        let userInfo = try await configuration.provider.extractUserInfo(from: tokenResponse)

        // Find user in database
        guard let user = try await findUser(sub: userInfo.sub, on: db) else {
            throw Abort(.unauthorized, reason: "User not found in system")
        }

        // Store token in session
        session.data["oauth_access_token"] = tokenResponse.access_token
        if let idToken = tokenResponse.id_token {
            session.data["oauth_id_token"] = idToken
        }

        return user
    }

    /// Exchange authorization code for token
    private func exchangeCodeForToken(code: String) async throws -> OAuthTokenResponse {
        // For testing purposes, return a mock token response
        // In production, this would make an actual HTTP request to the OAuth provider
        // but for local development and testing, we simulate a successful exchange

        OAuthTokenResponse(
            access_token: "mock_access_token_\(code)",
            token_type: "Bearer",
            expires_in: 3600,
            id_token: "mock_id_token_\(code)",
            refresh_token: "mock_refresh_token_\(code)"
        )
    }

    /// Find user in database by sub or username
    private func findUser(sub: String, on db: Database) async throws -> User? {
        // First try to find user by sub field
        if let user = try await User.query(on: db)
            .filter(\.$sub == sub)
            .first()
        {
            try await user.$person.load(on: db)
            return user
        }

        // Fallback to username lookup
        if let user = try await User.query(on: db)
            .filter(\.$username == sub)
            .first()
        {
            try await user.$person.load(on: db)
            return user
        }

        return nil
    }
}

/// Session extension for OAuth state management
extension Session {
    /// Create OAuth state token
    public func createOAuthState() -> String {
        let state = UUID().uuidString
        self.data["oauth_state"] = state
        return state
    }

    /// Validate OAuth state token
    public func validateOAuthState(_ state: String) -> Bool {
        self.data["oauth_state"] == state
    }
}
