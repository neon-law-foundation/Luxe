import Foundation
import Vapor

/// Service for authentication operations
public struct AuthService: Sendable {

    /// Builds the OIDC authorization URL for login
    /// - Parameters:
    ///   - oidcConfig: The OIDC configuration
    ///   - redirectPath: The original path to redirect to after login
    /// - Returns: The authorization URL string
    public static func buildAuthorizationURL(oidcConfig: OIDCConfiguration, redirectPath: String) -> String {
        let issuerBase = oidcConfig.issuer
        let clientId = oidcConfig.clientId

        // Determine redirect URI and authorization endpoint based on environment
        let redirectUri: String
        let authEndpoint: String

        if Environment.get("ENV") == "PRODUCTION" {
            // Production uses Cognito
            redirectUri = "https://www.sagebrush.services/oauth2/idpresponse"
            authEndpoint = "https://sagebrush-auth.auth.us-west-2.amazoncognito.com/oauth2/authorize"
        } else {
            // Development uses Keycloak
            redirectUri = "http://localhost:8080/auth/callback"
            authEndpoint = "\(issuerBase)/protocol/openid-connect/auth"
        }

        // Build query parameters
        var components = URLComponents(string: authEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "state", value: redirectPath),
        ]

        return components.string ?? authEndpoint
    }

    /// Builds the logout URL for session termination
    /// - Parameter oidcConfig: The OIDC configuration
    /// - Returns: The logout URL string
    public static func buildLogoutURL(oidcConfig: OIDCConfiguration) -> String {
        // Construct logout URL (currently Keycloak-specific)
        let logoutURL = "\(oidcConfig.issuer)/protocol/openid-connect/logout"
        let postLogoutRedirectUri = "http://localhost:8080/"

        // Build logout URL with redirect
        var components = URLComponents(string: logoutURL)!
        components.queryItems = [
            URLQueryItem(name: "post_logout_redirect_uri", value: postLogoutRedirectUri),
            URLQueryItem(name: "client_id", value: oidcConfig.clientId),
        ]

        return components.string ?? "/"
    }

    /// Creates a logout cookie (expired) for clearing any existing session cookies
    /// - Returns: An expired HTTP cookie for clearing legacy session cookies
    public static func createLogoutCookie() -> HTTPCookies.Value {
        HTTPCookies.Value(
            string: "",
            expires: Date(timeIntervalSince1970: 0),
            path: "/",
            isHTTPOnly: true,
            sameSite: .lax
        )
    }

    /// Validates authentication configuration
    /// - Parameter oidcConfig: The OIDC configuration to validate
    /// - Throws: ValidationError if configuration is invalid
    public static func validateConfiguration(_ oidcConfig: OIDCConfiguration) throws {
        guard !oidcConfig.issuer.isEmpty else {
            throw ValidationError("OIDC issuer cannot be empty")
        }

        guard !oidcConfig.clientId.isEmpty else {
            throw ValidationError("OIDC client ID cannot be empty")
        }

        // Additional validation for production
        if Environment.get("ENV") == "PRODUCTION" {
            guard Environment.get("COGNITO_CLIENT_SECRET") != nil else {
                throw ValidationError("COGNITO_CLIENT_SECRET is required for production")
            }
        }
    }

    /// Determines the redirect path after successful authentication
    /// - Parameter state: The state parameter from OAuth callback
    /// - Returns: The validated redirect path
    public static func determineRedirectPath(from state: String?) -> String {
        guard let state = state, !state.isEmpty else {
            return "/app/me"
        }

        // Validate that the redirect path is safe (starts with /)
        guard state.hasPrefix("/") else {
            return "/app/me"
        }

        return state
    }

    /// Extracts and validates OAuth callback parameters
    /// - Parameter request: The incoming OAuth callback request
    /// - Returns: Tuple containing the authorization code and original path
    /// - Throws: ValidationError if required parameters are missing
    public static func extractCallbackParameters(from request: Request) throws -> (code: String, originalPath: String?)
    {
        guard let code = try? request.query.get(String.self, at: "code") else {
            throw ValidationError("Missing authorization code in OAuth callback")
        }

        let originalPath = try? request.query.get(String.self, at: "state")
        return (code: code, originalPath: originalPath)
    }

    /// Exchanges authorization code for tokens
    /// - Parameters:
    ///   - code: The authorization code from OAuth callback
    ///   - clientId: The OIDC client ID
    ///   - redirectUri: The redirect URI used in authorization
    ///   - tokenEndpoint: The token endpoint URL
    ///   - client: The HTTP client for making requests
    /// - Returns: Token response containing access and ID tokens
    /// - Throws: ValidationError if token exchange fails
    public static func exchangeCodeForTokens(
        code: String,
        clientId: String,
        redirectUri: String,
        tokenEndpoint: String,
        client: Client
    ) async throws -> TokenResponse {
        // Make the request to the token endpoint
        let response: ClientResponse

        if Environment.get("ENV") == "PRODUCTION" {
            // Cognito requires client credentials authentication
            let clientSecret = Environment.get("COGNITO_CLIENT_SECRET") ?? ""
            let credentials = "\(clientId):\(clientSecret)".data(using: .utf8)!.base64EncodedString()

            let tokenRequest = TokenRequest(
                grantType: "authorization_code",
                code: code,
                redirectUri: redirectUri,
                clientId: clientId
            )

            response = try await client.post(URI(string: tokenEndpoint)) { clientReq in
                clientReq.headers.add(name: .authorization, value: "Basic \(credentials)")
                clientReq.headers.add(name: .contentType, value: "application/x-www-form-urlencoded")
                try clientReq.content.encode(tokenRequest, as: .urlEncodedForm)
            }
        } else {
            // Keycloak (development) - no client secret required
            let tokenRequest = TokenRequest(
                grantType: "authorization_code",
                code: code,
                redirectUri: redirectUri,
                clientId: clientId
            )

            response = try await client.post(URI(string: tokenEndpoint)) { clientReq in
                try clientReq.content.encode(tokenRequest, as: .urlEncodedForm)
            }
        }

        if response.status != .ok {
            var body = "No body"
            if var responseBody = response.body {
                let readableBytes = responseBody.readableBytes
                let bodyData = responseBody.readData(length: readableBytes) ?? Data()
                body = String(data: bodyData, encoding: .utf8) ?? "No body"
            }
            throw ValidationError("Token exchange failed - Status: \(response.status), Body: \(body)")
        }

        // Decode the response
        return try response.content.decode(TokenResponse.self)
    }

    /// Decodes the username from a JWT ID token
    /// - Parameter token: The JWT ID token string
    /// - Returns: The extracted username
    /// - Throws: ValidationError if token decoding fails
    public static func decodeUsernameFromToken(_ token: String) throws -> String {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else {
            throw ValidationError("Invalid JWT format - expected 3 parts, got \(parts.count)")
        }

        // Decode the payload (second part)
        let payloadData = parts[1]
        var payload = String(payloadData)

        // Add padding if needed (JWT base64 doesn't use padding)
        while payload.count % 4 != 0 {
            payload += "="
        }

        guard let decodedData = Data(base64Encoded: payload) else {
            throw ValidationError("Failed to decode JWT payload from base64")
        }

        let jsonDecoder = JSONDecoder()
        let claims: JWTClaims
        do {
            claims = try jsonDecoder.decode(JWTClaims.self, from: decodedData)
        } catch {
            throw ValidationError("Failed to decode JWT claims: \(error)")
        }

        // For Cognito, the username might be in different fields
        if let email = claims.email, !email.isEmpty {
            return email
        } else if let preferredUsername = claims.preferredUsername, !preferredUsername.isEmpty {
            return preferredUsername
        } else if let cognitoUsername = claims.cognitoUsername, !cognitoUsername.isEmpty {
            return cognitoUsername
        } else {
            return claims.sub
        }
    }

}

// MARK: - Data Models

/// JWT Claims structure for token decoding
public struct JWTClaims: Codable {
    public let sub: String
    public let preferredUsername: String?
    public let email: String?
    public let cognitoUsername: String?

    private enum CodingKeys: String, CodingKey {
        case sub
        case preferredUsername = "preferred_username"
        case email
        case cognitoUsername = "cognito:username"
    }
}

/// Token request structure for OAuth token exchange
public struct TokenRequest: Content {
    public let grantType: String
    public let code: String
    public let redirectUri: String
    public let clientId: String

    public init(grantType: String, code: String, redirectUri: String, clientId: String) {
        self.grantType = grantType
        self.code = code
        self.redirectUri = redirectUri
        self.clientId = clientId
    }

    private enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case code
        case redirectUri = "redirect_uri"
        case clientId = "client_id"
    }
}

/// Token response structure from OAuth token exchange
public struct TokenResponse: Content {
    public let accessToken: String
    public let idToken: String
    public let refreshToken: String?
    public let tokenType: String
    public let expiresIn: Int

    public init(accessToken: String, idToken: String, refreshToken: String?, tokenType: String, expiresIn: Int) {
        self.accessToken = accessToken
        self.idToken = idToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
    }

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}
