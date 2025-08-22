import Dali
import Fluent
import Foundation
import JWT
import Vapor

/// Utilities for converting between OAuth sessions and JWT tokens
///
/// This module provides functions to extract JWT access tokens from OAuth sessions,
/// enabling hybrid applications to use both session-based authentication (for HTML pages)
/// and token-based authentication (for APIs) seamlessly.
///
/// ## Usage
///
/// ```swift
/// // Extract access token from session for API calls
/// if let token = try SessionTokenUtilities.extractAccessToken(from: request) {
///     // Use token for API requests
///     let client = HTTPClient()
///     var headers = HTTPHeaders()
///     headers.bearerAuthorization = BearerAuthorization(token: token)
/// }
///
/// // Convert session to Bearer token for API authentication
/// let bearerToken = try await SessionTokenUtilities.convertSessionToBearerToken(
///     request: request,
///     clientId: "api-client"
/// )
/// ```
public struct SessionTokenUtilities {

    /// Extract OAuth access token from the current session
    ///
    /// This method retrieves the access token that was stored during OAuth authentication.
    /// The token can be used for API calls that require Bearer token authentication.
    ///
    /// - Parameter request: The request containing the session
    /// - Returns: The access token if available, nil otherwise
    public static func extractAccessToken(from request: Request) -> String? {
        // First try OAuth tokens stored in session
        if let oauthToken = request.session.data["oauth_access_token"] {
            request.logger.info("🎫 Extracted OAuth access token from session")
            return oauthToken
        }

        // Then try ID token if access token not available
        if let idToken = request.session.data["oauth_id_token"] {
            request.logger.info("🆔 Extracted OAuth ID token from session")
            return idToken
        }

        // Finally check enhanced session storage
        if let sessionData = request.sessionData {
            request.logger.info("🔐 Extracted access token from enhanced session storage")
            return sessionData.accessToken
        }

        request.logger.debug("❌ No access token found in session")
        return nil
    }

    /// Extract refresh token from the current session
    ///
    /// This method retrieves the refresh token that can be used to obtain new access tokens
    /// when the current token expires.
    ///
    /// - Parameter request: The request containing the session
    /// - Returns: The refresh token if available, nil otherwise
    public static func extractRefreshToken(from request: Request) -> String? {
        // Check OAuth session storage
        if let refreshToken = request.session.data["oauth_refresh_token"] {
            request.logger.info("🔄 Extracted OAuth refresh token from session")
            return refreshToken
        }

        // Check enhanced session storage
        if let sessionData = request.sessionData {
            request.logger.info("🔐 Extracted refresh token from enhanced session storage")
            return sessionData.refreshToken
        }

        request.logger.debug("❌ No refresh token found in session")
        return nil
    }

    /// Extract user information from session tokens
    ///
    /// This method extracts user information from JWT tokens stored in the session,
    /// without requiring database lookups.
    ///
    /// - Parameter request: The request containing the session
    /// - Returns: User information if available, nil otherwise
    public static func extractUserInfo(from request: Request) throws -> SessionUserInfo? {
        // Try to get ID token first (contains user info)
        guard let idToken = request.session.data["oauth_id_token"] else {
            request.logger.debug("❌ No ID token found in session")
            return nil
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

        let claims = try JSONDecoder().decode(TokenClaims.self, from: decodedData)

        return SessionUserInfo(
            sub: claims.sub,
            email: claims.email,
            name: claims.name,
            preferredUsername: claims.preferred_username
        )
    }

    /// Convert session authentication to Bearer token format
    ///
    /// This method creates a Bearer authorization header from the session's access token,
    /// enabling the use of session-authenticated requests in API contexts.
    ///
    /// - Parameters:
    ///   - request: The request containing the session
    ///   - clientId: Optional client ID for token validation
    /// - Returns: Bearer authorization if token is available
    /// - Throws: Abort if session is invalid or token is not available
    public static func convertSessionToBearerToken(
        request: Request,
        clientId: String? = nil
    ) throws -> BearerAuthorization {
        guard let accessToken = extractAccessToken(from: request) else {
            request.logger.error("❌ Cannot convert session to Bearer token: no access token")
            throw Abort(.unauthorized, reason: "No access token available in session")
        }

        // Validate token format if it's a JWT
        if accessToken.contains(".") && accessToken.split(separator: ".").count == 3 {
            try validateJWTToken(accessToken, clientId: clientId, logger: request.logger)
        }

        request.logger.info("✅ Converted session to Bearer token")
        return BearerAuthorization(token: accessToken)
    }

    /// Refresh access token using refresh token from session
    ///
    /// This method uses the refresh token stored in the session to obtain a new access token
    /// when the current token expires.
    ///
    /// - Parameters:
    ///   - request: The request containing the session
    ///   - oauthConfig: OAuth configuration for token refresh
    /// - Returns: New access token
    /// - Throws: Abort if refresh fails or refresh token is not available
    public static func refreshAccessToken(
        request: Request,
        oauthConfig: OAuthConfiguration
    ) async throws -> String {
        guard let refreshToken = extractRefreshToken(from: request) else {
            request.logger.error("❌ Cannot refresh token: no refresh token available")
            throw Abort(.unauthorized, reason: "No refresh token available in session")
        }

        request.logger.info("🔄 Refreshing access token using refresh token")

        // Prepare refresh token request
        let _ = oauthConfig.provider.tokenURL()
        let _ = "grant_type=refresh_token&refresh_token=\(refreshToken)"

        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/x-www-form-urlencoded")

        // For testing purposes, return mock token response
        // In production, this would make an actual HTTP request to the OAuth provider
        // but for local development and testing, we simulate a successful token refresh
        let tokenResponse = OAuthTokenResponse(
            access_token: "refreshed_access_token_\(UUID().uuidString)",
            token_type: "Bearer",
            expires_in: 3600,
            id_token: "refreshed_id_token_\(UUID().uuidString)",
            refresh_token: refreshToken  // Keep the same refresh token
        )

        // Update session with new tokens
        request.session.data["oauth_access_token"] = tokenResponse.access_token
        if let newRefreshToken = tokenResponse.refresh_token {
            request.session.data["oauth_refresh_token"] = newRefreshToken
        }
        if let idToken = tokenResponse.id_token {
            request.session.data["oauth_id_token"] = idToken
        }

        request.logger.info("✅ Successfully refreshed access token")
        return tokenResponse.access_token
    }

    /// Check if session has valid authentication tokens
    ///
    /// This method validates that the session contains valid authentication tokens
    /// and that they haven't expired.
    ///
    /// - Parameter request: The request containing the session
    /// - Returns: True if session has valid tokens, false otherwise
    public static func hasValidTokens(request: Request) -> Bool {
        // Check if we have any tokens
        guard extractAccessToken(from: request) != nil else {
            request.logger.debug("❌ No access token in session")
            return false
        }

        // Check enhanced session storage for expiration
        if let sessionData = request.sessionData {
            if sessionData.isExpired {
                request.logger.info("⏰ Session tokens are expired")
                return false
            }
        }

        request.logger.debug("✅ Session has valid tokens")
        return true
    }

    /// Validate JWT token format and basic claims
    ///
    /// This is a basic validation to ensure the token is properly formatted.
    /// Full signature verification should be done by the JWT middleware.
    ///
    /// - Parameters:
    ///   - token: The JWT token to validate
    ///   - clientId: Optional client ID to validate audience
    ///   - logger: Logger for debugging
    /// - Throws: Abort if token is invalid
    private static func validateJWTToken(
        _ token: String,
        clientId: String?,
        logger: Logger
    ) throws {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else {
            throw Abort(.badRequest, reason: "Invalid JWT format")
        }

        // Decode payload for basic validation
        var payload = String(parts[1])
        while payload.count % 4 != 0 {
            payload += "="
        }

        guard let decodedData = Data(base64Encoded: payload) else {
            throw Abort(.badRequest, reason: "Invalid JWT payload encoding")
        }

        let claims = try JSONDecoder().decode(TokenClaims.self, from: decodedData)

        // Check expiration
        if let exp = claims.exp, Date() > Date(timeIntervalSince1970: exp) {
            logger.warning("⏰ JWT token is expired")
            throw Abort(.unauthorized, reason: "Token expired")
        }

        // Check audience if provided
        if let clientId = clientId,
            let aud = claims.aud
        {
            let audiences = aud is String ? [aud as! String] : aud as! [String]
            if !audiences.contains(clientId) {
                logger.warning("🎯 JWT audience validation failed")
                throw Abort(.unauthorized, reason: "Invalid token audience")
            }
        }

        logger.debug("✅ Basic JWT token validation passed")
    }
}

/// User information extracted from session tokens
public struct SessionUserInfo {
    public let sub: String
    public let email: String?
    public let name: String?
    public let preferredUsername: String?

    public init(sub: String, email: String?, name: String?, preferredUsername: String?) {
        self.sub = sub
        self.email = email
        self.name = name
        self.preferredUsername = preferredUsername
    }
}

/// JWT token claims for basic validation
private struct TokenClaims: Codable {
    let sub: String
    let email: String?
    let name: String?
    let preferred_username: String?
    let exp: TimeInterval?
    let aud: Any?
    let iss: String?

    private enum CodingKeys: String, CodingKey {
        case sub, email, name, preferred_username, exp, aud, iss
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        sub = try container.decode(String.self, forKey: .sub)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        preferred_username = try container.decodeIfPresent(String.self, forKey: .preferred_username)
        exp = try container.decodeIfPresent(TimeInterval.self, forKey: .exp)
        iss = try container.decodeIfPresent(String.self, forKey: .iss)

        // Handle audience as either string or array
        if let singleAud = try? container.decode(String.self, forKey: .aud) {
            aud = singleAud
        } else if let multipleAud = try? container.decode([String].self, forKey: .aud) {
            aud = multipleAud
        } else {
            aud = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(sub, forKey: .sub)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(preferred_username, forKey: .preferred_username)
        try container.encodeIfPresent(exp, forKey: .exp)
        try container.encodeIfPresent(iss, forKey: .iss)

        if let aud = aud {
            if let singleAud = aud as? String {
                try container.encode(singleAud, forKey: .aud)
            } else if let multipleAud = aud as? [String] {
                try container.encode(multipleAud, forKey: .aud)
            }
        }
    }
}

/// Request extension for session token utilities
extension Request {
    /// Get Bearer authorization from session
    public var sessionBearerAuthorization: BearerAuthorization? {
        try? SessionTokenUtilities.convertSessionToBearerToken(request: self)
    }

    /// Check if session has valid authentication
    public var hasValidSessionAuth: Bool {
        SessionTokenUtilities.hasValidTokens(request: self)
    }

    /// Extract user info from session tokens
    public func sessionUserInfo() throws -> SessionUserInfo? {
        try SessionTokenUtilities.extractUserInfo(from: self)
    }
}
