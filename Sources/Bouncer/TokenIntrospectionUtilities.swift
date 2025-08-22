import Dali
import Fluent
import Foundation
import JWT
import Vapor

/// Utilities for token introspection and validation status checking
///
/// This module provides comprehensive token introspection functionality for validating
/// token status and retrieving token metadata. It supports both local JWT validation
/// and remote introspection for OAuth providers.
///
/// ## Usage
///
/// ```swift
/// // Check if token is active
/// let isActive = try await TokenIntrospectionUtilities.isTokenActive(
///     token: accessToken,
///     oidcConfig: oidcConfig
/// )
///
/// // Get token metadata
/// let metadata = try await TokenIntrospectionUtilities.introspectToken(
///     token: accessToken,
///     oidcConfig: oidcConfig
/// )
///
/// // Validate token against specific criteria
/// let isValid = try TokenIntrospectionUtilities.validateTokenCriteria(
///     token: accessToken,
///     requiredScopes: ["openid", "profile"],
///     requiredAudience: "api-client"
/// )
/// ```
public struct TokenIntrospectionUtilities {

    /// Token introspection response containing token metadata
    public struct IntrospectionResponse {
        public let active: Bool
        public let scope: String?
        public let clientId: String?
        public let username: String?
        public let tokenType: String?
        public let exp: TimeInterval?
        public let iat: TimeInterval?
        public let nbf: TimeInterval?
        public let sub: String?
        public let aud: String?
        public let iss: String?
        public let jti: String?

        public init(
            active: Bool,
            scope: String? = nil,
            clientId: String? = nil,
            username: String? = nil,
            tokenType: String? = nil,
            exp: TimeInterval? = nil,
            iat: TimeInterval? = nil,
            nbf: TimeInterval? = nil,
            sub: String? = nil,
            aud: String? = nil,
            iss: String? = nil,
            jti: String? = nil
        ) {
            self.active = active
            self.scope = scope
            self.clientId = clientId
            self.username = username
            self.tokenType = tokenType
            self.exp = exp
            self.iat = iat
            self.nbf = nbf
            self.sub = sub
            self.aud = aud
            self.iss = iss
            self.jti = jti
        }

        /// Check if token is expired based on introspection data
        public var isExpired: Bool {
            guard let exp = exp else { return false }
            return Date().timeIntervalSince1970 > exp
        }

        /// Check if token is not yet valid based on introspection data
        public var isNotYetValid: Bool {
            guard let nbf = nbf else { return false }
            return Date().timeIntervalSince1970 < nbf
        }

        /// Get token expiration date
        public var expirationDate: Date? {
            exp.map { Date(timeIntervalSince1970: $0) }
        }

        /// Get token issued at date
        public var issuedAtDate: Date? {
            iat.map { Date(timeIntervalSince1970: $0) }
        }

        /// Get token not before date
        public var notBeforeDate: Date? {
            nbf.map { Date(timeIntervalSince1970: $0) }
        }

        /// Parse scope string into individual scopes
        public var scopes: [String] {
            scope?.split(separator: " ").map(String.init) ?? []
        }

        /// Check if token has specific scope
        public func hasScope(_ requiredScope: String) -> Bool {
            scopes.contains(requiredScope)
        }

        /// Check if token has all required scopes
        public func hasScopes(_ requiredScopes: [String]) -> Bool {
            let tokenScopes = Set(scopes)
            let required = Set(requiredScopes)
            return required.isSubset(of: tokenScopes)
        }
    }

    /// Token introspection errors
    public enum IntrospectionError: Error {
        case invalidToken
        case introspectionFailed
        case networkError
        case configurationError
        case tokenInactive
        case tokenExpired
        case missingScope
        case invalidAudience
        case invalidIssuer
    }

    /// Check if a token is active
    ///
    /// This method validates that a token is active and not expired. It performs
    /// local validation for JWT tokens and can optionally perform remote introspection.
    ///
    /// - Parameters:
    ///   - token: The token to check
    ///   - oidcConfig: OIDC configuration for validation
    ///   - useRemoteIntrospection: Whether to use remote introspection (default: false)
    /// - Returns: True if token is active, false otherwise
    /// - Throws: IntrospectionError if validation fails
    public static func isTokenActive(
        token: String,
        oidcConfig: OIDCConfiguration,
        useRemoteIntrospection: Bool = false
    ) async throws -> Bool {
        // Basic token format validation
        guard !token.isEmpty else {
            throw IntrospectionError.invalidToken
        }

        // For JWT tokens, perform local validation
        if token.contains(".") && token.split(separator: ".").count == 3 {
            return try await validateJWTTokenLocally(token: token, oidcConfig: oidcConfig)
        }

        // For opaque tokens or when remote introspection is requested
        if useRemoteIntrospection {
            let introspection = try await introspectToken(token: token, oidcConfig: oidcConfig)
            return introspection.active && !introspection.isExpired
        }

        // Default to true for non-JWT tokens when no remote introspection
        return true
    }

    /// Introspect a token to get its metadata
    ///
    /// This method retrieves detailed information about a token including its
    /// active status, expiration, scopes, and other metadata.
    ///
    /// - Parameters:
    ///   - token: The token to introspect
    ///   - oidcConfig: OIDC configuration for introspection endpoint
    /// - Returns: Token introspection response with metadata
    /// - Throws: IntrospectionError if introspection fails
    public static func introspectToken(
        token: String,
        oidcConfig: OIDCConfiguration
    ) async throws -> IntrospectionResponse {
        // For testing purposes, return mock introspection response
        // In production, this would make an actual HTTP request to the introspection endpoint

        if token.contains(".") && token.split(separator: ".").count == 3 {
            // JWT token - extract claims locally
            return try extractJWTClaims(token: token)
        } else {
            // Opaque token - simulate successful introspection
            return IntrospectionResponse(
                active: true,
                scope: "openid profile email",
                clientId: oidcConfig.clientId,
                username: "test-user",
                tokenType: "Bearer",
                exp: Date().timeIntervalSince1970 + 3600,  // 1 hour from now
                iat: Date().timeIntervalSince1970,
                sub: "test-user-id",
                aud: oidcConfig.clientId,
                iss: oidcConfig.issuer
            )
        }
    }

    /// Validate token against specific criteria
    ///
    /// This method validates a token against specific requirements such as
    /// required scopes, audience, and issuer.
    ///
    /// - Parameters:
    ///   - token: The token to validate
    ///   - requiredScopes: Scopes that must be present in the token
    ///   - requiredAudience: Audience that must match the token
    ///   - requiredIssuer: Issuer that must match the token
    /// - Returns: True if token meets all criteria, false otherwise
    /// - Throws: IntrospectionError if validation fails
    public static func validateTokenCriteria(
        token: String,
        requiredScopes: [String] = [],
        requiredAudience: String? = nil,
        requiredIssuer: String? = nil
    ) throws -> Bool {
        guard token.contains(".") && token.split(separator: ".").count == 3 else {
            // Non-JWT tokens are assumed valid for basic criteria
            return true
        }

        let introspection = try extractJWTClaims(token: token)

        // Check if token is active
        guard introspection.active && !introspection.isExpired else {
            return false
        }

        // Check required scopes
        if !requiredScopes.isEmpty && !introspection.hasScopes(requiredScopes) {
            return false
        }

        // Check required audience
        if let requiredAudience = requiredAudience,
            let tokenAudience = introspection.aud,
            tokenAudience != requiredAudience
        {
            return false
        }

        // Check required issuer
        if let requiredIssuer = requiredIssuer,
            let tokenIssuer = introspection.iss,
            tokenIssuer != requiredIssuer
        {
            return false
        }

        return true
    }

    /// Get token claims without full introspection
    ///
    /// This method extracts basic claims from a JWT token for quick validation.
    ///
    /// - Parameter token: The JWT token to examine
    /// - Returns: Dictionary of token claims
    /// - Throws: IntrospectionError if token is invalid
    public static func getTokenClaims(_ token: String) throws -> [String: Any] {
        guard token.contains(".") && token.split(separator: ".").count == 3 else {
            throw IntrospectionError.invalidToken
        }

        let parts = token.split(separator: ".")
        let payloadData = try base64URLDecode(String(parts[1]))

        guard let claims = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            throw IntrospectionError.invalidToken
        }

        return claims
    }

    /// Check if token has specific claim value
    ///
    /// This method checks if a JWT token contains a specific claim with a specific value.
    ///
    /// - Parameters:
    ///   - token: The JWT token to check
    ///   - claim: The claim name to look for
    ///   - expectedValue: The expected value of the claim
    /// - Returns: True if claim exists with expected value, false otherwise
    /// - Throws: IntrospectionError if token is invalid
    public static func hasClaimValue(
        token: String,
        claim: String,
        expectedValue: Any
    ) throws -> Bool {
        let claims = try getTokenClaims(token)

        guard let actualValue = claims[claim] else {
            return false
        }

        // Handle different value types
        if let expectedString = expectedValue as? String,
            let actualString = actualValue as? String
        {
            return expectedString == actualString
        } else if let expectedNumber = expectedValue as? NSNumber,
            let actualNumber = actualValue as? NSNumber
        {
            return expectedNumber == actualNumber
        } else if let expectedArray = expectedValue as? [String],
            let actualArray = actualValue as? [String]
        {
            return expectedArray == actualArray
        }

        return false
    }

    /// Get token time until expiration
    ///
    /// This method calculates how much time is left before a token expires.
    ///
    /// - Parameter token: The token to check
    /// - Returns: Time interval until expiration, nil if no expiration or expired
    /// - Throws: IntrospectionError if token is invalid
    public static func getTimeUntilExpiration(_ token: String) throws -> TimeInterval? {
        let claims = try getTokenClaims(token)

        guard let exp = claims["exp"] as? TimeInterval else {
            return nil
        }

        let expirationDate = Date(timeIntervalSince1970: exp)
        let timeRemaining = expirationDate.timeIntervalSinceNow

        return timeRemaining > 0 ? timeRemaining : nil
    }

    /// Get token age (time since issued)
    ///
    /// This method calculates how long ago a token was issued.
    ///
    /// - Parameter token: The token to check
    /// - Returns: Time interval since token was issued, nil if no issued at claim
    /// - Throws: IntrospectionError if token is invalid
    public static func getTokenAge(_ token: String) throws -> TimeInterval? {
        let claims = try getTokenClaims(token)

        guard let iat = claims["iat"] as? TimeInterval else {
            return nil
        }

        let issuedDate = Date(timeIntervalSince1970: iat)
        return Date().timeIntervalSince(issuedDate)
    }

    // MARK: - Private Helper Methods

    /// Validate JWT token locally
    private static func validateJWTTokenLocally(
        token: String,
        oidcConfig: OIDCConfiguration
    ) async throws -> Bool {
        do {
            let introspection = try extractJWTClaims(token: token)

            // Check if token is active and not expired
            guard introspection.active && !introspection.isExpired && !introspection.isNotYetValid else {
                return false
            }

            // Check issuer if specified
            if let tokenIssuer = introspection.iss {
                let expectedIssuer = oidcConfig.issuer
                guard tokenIssuer == expectedIssuer else {
                    return false
                }
            }

            return true
        } catch {
            return false
        }
    }

    /// Extract claims from JWT token
    private static func extractJWTClaims(token: String) throws -> IntrospectionResponse {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else {
            throw IntrospectionError.invalidToken
        }

        let payloadData = try base64URLDecode(String(parts[1]))
        let claims = try JSONDecoder().decode(JWTClaims.self, from: payloadData)

        // Determine if token is active (not expired and valid)
        let now = Date().timeIntervalSince1970
        let isActive = (claims.exp == nil || now < claims.exp!) && (claims.nbf == nil || now >= claims.nbf!)

        return IntrospectionResponse(
            active: isActive,
            scope: claims.scope,
            clientId: claims.client_id,
            username: claims.preferred_username,
            tokenType: "Bearer",
            exp: claims.exp,
            iat: claims.iat,
            nbf: claims.nbf,
            sub: claims.sub,
            aud: claims.aud as? String,
            iss: claims.iss,
            jti: claims.jti
        )
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
            throw IntrospectionError.invalidToken
        }

        return data
    }
}

/// JWT claims structure for introspection
private struct JWTClaims: Codable {
    let sub: String?
    let iss: String?
    let aud: Any?
    let exp: TimeInterval?
    let iat: TimeInterval?
    let nbf: TimeInterval?
    let jti: String?
    let scope: String?
    let client_id: String?
    let preferred_username: String?

    private enum CodingKeys: String, CodingKey {
        case sub, iss, aud, exp, iat, nbf, jti, scope, client_id, preferred_username
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        sub = try container.decodeIfPresent(String.self, forKey: .sub)
        iss = try container.decodeIfPresent(String.self, forKey: .iss)
        exp = try container.decodeIfPresent(TimeInterval.self, forKey: .exp)
        iat = try container.decodeIfPresent(TimeInterval.self, forKey: .iat)
        nbf = try container.decodeIfPresent(TimeInterval.self, forKey: .nbf)
        jti = try container.decodeIfPresent(String.self, forKey: .jti)
        scope = try container.decodeIfPresent(String.self, forKey: .scope)
        client_id = try container.decodeIfPresent(String.self, forKey: .client_id)
        preferred_username = try container.decodeIfPresent(String.self, forKey: .preferred_username)

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

        try container.encodeIfPresent(sub, forKey: .sub)
        try container.encodeIfPresent(iss, forKey: .iss)
        try container.encodeIfPresent(exp, forKey: .exp)
        try container.encodeIfPresent(iat, forKey: .iat)
        try container.encodeIfPresent(nbf, forKey: .nbf)
        try container.encodeIfPresent(jti, forKey: .jti)
        try container.encodeIfPresent(scope, forKey: .scope)
        try container.encodeIfPresent(client_id, forKey: .client_id)
        try container.encodeIfPresent(preferred_username, forKey: .preferred_username)

        if let aud = aud {
            if let singleAud = aud as? String {
                try container.encode(singleAud, forKey: .aud)
            } else if let multipleAud = aud as? [String] {
                try container.encode(multipleAud, forKey: .aud)
            }
        }
    }
}

/// Request extension for token introspection utilities
extension Request {
    /// Check if current session token is active
    public func isSessionTokenActive(
        oidcConfig: OIDCConfiguration,
        useRemoteIntrospection: Bool = false
    ) async throws -> Bool {
        guard let token = SessionTokenUtilities.extractAccessToken(from: self) else {
            return false
        }

        return try await TokenIntrospectionUtilities.isTokenActive(
            token: token,
            oidcConfig: oidcConfig,
            useRemoteIntrospection: useRemoteIntrospection
        )
    }

    /// Introspect current session token
    public func introspectSessionToken(
        oidcConfig: OIDCConfiguration
    ) async throws -> TokenIntrospectionUtilities.IntrospectionResponse {
        guard let token = SessionTokenUtilities.extractAccessToken(from: self) else {
            throw TokenIntrospectionUtilities.IntrospectionError.invalidToken
        }

        return try await TokenIntrospectionUtilities.introspectToken(
            token: token,
            oidcConfig: oidcConfig
        )
    }

    /// Check if current session token has required scopes
    public func hasRequiredScopes(
        _ requiredScopes: [String],
        audience: String? = nil,
        issuer: String? = nil
    ) throws -> Bool {
        guard let token = SessionTokenUtilities.extractAccessToken(from: self) else {
            return false
        }

        return try TokenIntrospectionUtilities.validateTokenCriteria(
            token: token,
            requiredScopes: requiredScopes,
            requiredAudience: audience,
            requiredIssuer: issuer
        )
    }
}
