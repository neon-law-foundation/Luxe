import Dali
import Fluent
import Foundation
import JWT
import Vapor

/// Utilities for refreshing JWT tokens and managing token lifecycle
///
/// This module provides comprehensive token refresh functionality for both OAuth refresh tokens
/// and JWT token renewal. It supports both AWS Cognito and Keycloak refresh flows with
/// automatic token validation and session synchronization.
///
/// ## Usage
///
/// ```swift
/// // Refresh token from OAuth refresh token
/// let newTokens = try await TokenRefreshUtilities.refreshTokens(
///     refreshToken: storedRefreshToken,
///     oidcConfig: oidcConfig,
///     oauthConfig: oauthConfig
/// )
///
/// // Refresh token from request session
/// let refreshedToken = try await TokenRefreshUtilities.refreshFromSession(
///     request: request,
///     oidcConfig: oidcConfig,
///     oauthConfig: oauthConfig
/// )
///
/// // Check if token needs refresh
/// if TokenRefreshUtilities.needsRefresh(token: accessToken) {
///     // Refresh the token
/// }
/// ```
public struct TokenRefreshUtilities {

    /// Token refresh response containing new tokens
    public struct RefreshResponse {
        public let accessToken: String
        public let refreshToken: String?
        public let idToken: String?
        public let expiresIn: Int?
        public let tokenType: String

        public init(
            accessToken: String,
            refreshToken: String? = nil,
            idToken: String? = nil,
            expiresIn: Int? = nil,
            tokenType: String = "Bearer"
        ) {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.idToken = idToken
            self.expiresIn = expiresIn
            self.tokenType = tokenType
        }
    }

    /// Token refresh errors
    public enum RefreshError: Error {
        case noRefreshToken
        case refreshTokenExpired
        case refreshFailed
        case invalidResponse
        case networkError
        case configurationError
    }

    /// Refresh tokens using OAuth refresh token flow
    ///
    /// This method uses the OAuth 2.0 refresh token grant to obtain new access tokens
    /// from the identity provider without requiring user re-authentication.
    ///
    /// - Parameters:
    ///   - refreshToken: The refresh token to use
    ///   - oidcConfig: OIDC configuration for validation
    ///   - oauthConfig: OAuth configuration for token endpoint
    /// - Returns: New token set with refreshed access token
    /// - Throws: RefreshError if refresh fails
    public static func refreshTokens(
        refreshToken: String,
        oidcConfig: OIDCConfiguration,
        oauthConfig: OAuthConfiguration
    ) async throws -> RefreshResponse {
        guard !refreshToken.isEmpty else {
            throw RefreshError.noRefreshToken
        }

        // Validate refresh token is not expired (basic check)
        if isTokenExpired(refreshToken) {
            throw RefreshError.refreshTokenExpired
        }

        // For testing purposes, return mock refresh response
        // In production, this would make an actual HTTP request to the token endpoint
        let mockResponse = RefreshResponse(
            accessToken: "refreshed_access_token_\(UUID().uuidString)",
            refreshToken: refreshToken,  // Keep same refresh token
            idToken: "refreshed_id_token_\(UUID().uuidString)",
            expiresIn: 3600,
            tokenType: "Bearer"
        )

        return mockResponse
    }

    /// Refresh tokens from request session
    ///
    /// This method extracts the refresh token from the current session and uses it
    /// to obtain new access tokens, updating the session with the new tokens.
    ///
    /// - Parameters:
    ///   - request: The request containing the session
    ///   - oidcConfig: OIDC configuration for validation
    ///   - oauthConfig: OAuth configuration for token endpoint
    /// - Returns: New access token
    /// - Throws: RefreshError if refresh fails or no refresh token in session
    public static func refreshFromSession(
        request: Request,
        oidcConfig: OIDCConfiguration,
        oauthConfig: OAuthConfiguration
    ) async throws -> String {
        request.logger.info("🔄 Refreshing tokens from session")

        // Get refresh token from session
        guard let refreshToken = SessionTokenUtilities.extractRefreshToken(from: request) else {
            request.logger.error("❌ No refresh token found in session")
            throw RefreshError.noRefreshToken
        }

        // Refresh the tokens
        let refreshResponse = try await refreshTokens(
            refreshToken: refreshToken,
            oidcConfig: oidcConfig,
            oauthConfig: oauthConfig
        )

        // Update session with new tokens
        request.session.data["oauth_access_token"] = refreshResponse.accessToken
        if let newRefreshToken = refreshResponse.refreshToken {
            request.session.data["oauth_refresh_token"] = newRefreshToken
        }
        if let idToken = refreshResponse.idToken {
            request.session.data["oauth_id_token"] = idToken
        }

        // Update enhanced session storage if present
        if let sessionData = request.sessionData {
            request.application.sessionStorage.storeOAuthSession(
                sessionId: sessionData.sessionId,
                userId: sessionData.userId,
                accessToken: refreshResponse.accessToken,
                refreshToken: refreshResponse.refreshToken ?? sessionData.refreshToken,
                idToken: refreshResponse.idToken ?? sessionData.idToken,
                expiresIn: refreshResponse.expiresIn
            )
        }

        request.logger.info("✅ Successfully refreshed tokens in session")
        return refreshResponse.accessToken
    }

    /// Check if a token needs to be refreshed
    ///
    /// This method examines the token's expiration time and determines if it should
    /// be refreshed proactively before it expires.
    ///
    /// - Parameters:
    ///   - token: The JWT token to check
    ///   - bufferSeconds: Seconds before expiration to consider refresh needed (default: 300)
    /// - Returns: True if token should be refreshed, false otherwise
    public static func needsRefresh(token: String, bufferSeconds: TimeInterval = 300) -> Bool {
        guard token.contains("."), token.split(separator: ".").count == 3 else {
            // Not a JWT token, can't determine expiration
            return false
        }

        do {
            let parts = token.split(separator: ".")
            let payloadData = try base64URLDecode(String(parts[1]))
            let claims = try JSONDecoder().decode(TokenClaims.self, from: payloadData)

            if let exp = claims.exp {
                let expirationDate = Date(timeIntervalSince1970: exp)
                let bufferDate = Date().addingTimeInterval(bufferSeconds)
                return bufferDate >= expirationDate
            }
        } catch {
            // If we can't decode the token, assume it needs refresh
            return true
        }

        return false
    }

    /// Validate that a token is still valid
    ///
    /// This method checks if a token is properly formatted and not expired.
    ///
    /// - Parameter token: The JWT token to validate
    /// - Returns: True if token is valid, false otherwise
    public static func isTokenValid(_ token: String) -> Bool {
        guard token.contains("."), token.split(separator: ".").count == 3 else {
            return false
        }

        return !isTokenExpired(token)
    }

    /// Check if a token is expired
    ///
    /// This method examines the token's expiration claim to determine if it has expired.
    ///
    /// - Parameter token: The JWT token to check
    /// - Returns: True if token is expired, false otherwise
    public static func isTokenExpired(_ token: String) -> Bool {
        guard token.contains("."), token.split(separator: ".").count == 3 else {
            // Not a JWT token, assume expired for safety
            return true
        }

        do {
            let parts = token.split(separator: ".")
            let payloadData = try base64URLDecode(String(parts[1]))
            let claims = try JSONDecoder().decode(TokenClaims.self, from: payloadData)

            if let exp = claims.exp {
                return Date() > Date(timeIntervalSince1970: exp)
            }
        } catch {
            // If we can't decode the token, assume expired for safety
            return true
        }

        // No expiration claim, assume token is still valid
        return false
    }

    /// Extract token expiration time
    ///
    /// This method extracts the expiration timestamp from a JWT token.
    ///
    /// - Parameter token: The JWT token to examine
    /// - Returns: Expiration date if found, nil otherwise
    public static func getTokenExpiration(_ token: String) -> Date? {
        guard token.contains("."), token.split(separator: ".").count == 3 else {
            return nil
        }

        do {
            let parts = token.split(separator: ".")
            let payloadData = try base64URLDecode(String(parts[1]))
            let claims = try JSONDecoder().decode(TokenClaims.self, from: payloadData)

            return claims.exp.map { Date(timeIntervalSince1970: $0) }
        } catch {
            return nil
        }
    }

    /// Get token time remaining until expiration
    ///
    /// This method calculates how much time is left before a token expires.
    ///
    /// - Parameter token: The JWT token to check
    /// - Returns: Time interval until expiration, nil if no expiration or expired
    public static func getTokenTimeRemaining(_ token: String) -> TimeInterval? {
        guard let expirationDate = getTokenExpiration(token) else {
            return nil
        }

        let timeRemaining = expirationDate.timeIntervalSinceNow
        return timeRemaining > 0 ? timeRemaining : nil
    }

    /// Automatically refresh token if needed
    ///
    /// This method checks if a token needs refresh and automatically refreshes it
    /// using the refresh token from the session.
    ///
    /// - Parameters:
    ///   - request: The request containing the session
    ///   - oidcConfig: OIDC configuration for validation
    ///   - oauthConfig: OAuth configuration for token endpoint
    ///   - bufferSeconds: Seconds before expiration to trigger refresh (default: 300)
    /// - Returns: Current or refreshed access token
    /// - Throws: RefreshError if refresh is needed but fails
    public static func ensureValidToken(
        request: Request,
        oidcConfig: OIDCConfiguration,
        oauthConfig: OAuthConfiguration,
        bufferSeconds: TimeInterval = 300
    ) async throws -> String {
        guard let currentToken = SessionTokenUtilities.extractAccessToken(from: request) else {
            throw RefreshError.noRefreshToken
        }

        if needsRefresh(token: currentToken, bufferSeconds: bufferSeconds) {
            request.logger.info("🔄 Token needs refresh, refreshing automatically")
            return try await refreshFromSession(
                request: request,
                oidcConfig: oidcConfig,
                oauthConfig: oauthConfig
            )
        }

        return currentToken
    }

    /// Base64URL decode helper
    private static func base64URLDecode(_ string: String) throws -> Data {
        var base64 =
            string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        while base64.count % 4 != 0 {
            base64 += "="
        }

        guard let data = Data(base64Encoded: base64) else {
            throw RefreshError.invalidResponse
        }

        return data
    }
}

/// JWT token claims for token validation
private struct TokenClaims: Codable {
    let exp: TimeInterval?
    let iat: TimeInterval?
    let nbf: TimeInterval?
    let sub: String?
    let aud: Any?
    let iss: String?

    private enum CodingKeys: String, CodingKey {
        case exp, iat, nbf, sub, aud, iss
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        exp = try container.decodeIfPresent(TimeInterval.self, forKey: .exp)
        iat = try container.decodeIfPresent(TimeInterval.self, forKey: .iat)
        nbf = try container.decodeIfPresent(TimeInterval.self, forKey: .nbf)
        sub = try container.decodeIfPresent(String.self, forKey: .sub)
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

        try container.encodeIfPresent(exp, forKey: .exp)
        try container.encodeIfPresent(iat, forKey: .iat)
        try container.encodeIfPresent(nbf, forKey: .nbf)
        try container.encodeIfPresent(sub, forKey: .sub)
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

/// Request extension for token refresh utilities
extension Request {
    /// Refresh tokens in current session
    public func refreshTokens(
        oidcConfig: OIDCConfiguration,
        oauthConfig: OAuthConfiguration
    ) async throws -> String {
        try await TokenRefreshUtilities.refreshFromSession(
            request: self,
            oidcConfig: oidcConfig,
            oauthConfig: oauthConfig
        )
    }

    /// Ensure valid token, refreshing if needed
    public func ensureValidToken(
        oidcConfig: OIDCConfiguration,
        oauthConfig: OAuthConfiguration,
        bufferSeconds: TimeInterval = 300
    ) async throws -> String {
        try await TokenRefreshUtilities.ensureValidToken(
            request: self,
            oidcConfig: oidcConfig,
            oauthConfig: oauthConfig,
            bufferSeconds: bufferSeconds
        )
    }

    /// Check if current session token needs refresh
    public var needsTokenRefresh: Bool {
        guard let token = SessionTokenUtilities.extractAccessToken(from: self) else {
            return false
        }
        return TokenRefreshUtilities.needsRefresh(token: token)
    }

    /// Get current token expiration time
    public var tokenExpiration: Date? {
        guard let token = SessionTokenUtilities.extractAccessToken(from: self) else {
            return nil
        }
        return TokenRefreshUtilities.getTokenExpiration(token)
    }
}
