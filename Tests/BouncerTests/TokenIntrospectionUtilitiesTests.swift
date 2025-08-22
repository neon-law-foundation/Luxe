import Bouncer
import Foundation
import TestUtilities
import Testing
import Vapor

@Suite("Token Introspection Utilities", .serialized)
struct TokenIntrospectionUtilitiesTests {

    @Test(
        "isTokenActive returns true for valid JWT token",
        .disabled(
            if: ProcessInfo.processInfo.environment["CI"] != nil,
            "OAuth token introspection tests disabled in CI"
        )
    )
    func isTokenActiveReturnsTrueForValidJWTToken() async throws {
        try await TestUtilities.withTimeout {
            // Given: Valid JWT token and OIDC configuration
            let futureExpiry = Date().timeIntervalSince1970 + 3600  // 1 hour from now
            let oidcConfig = OIDCConfiguration.create(from: .development)
            let validToken = createMockJWT(
                exp: futureExpiry,
                iss: oidcConfig.issuer
            )

            // When: Checking if token is active
            let isActive = try await TokenIntrospectionUtilities.isTokenActive(
                token: validToken,
                oidcConfig: oidcConfig
            )

            // Then: Should be active
            #expect(isActive == true)
        }
    }

    @Test(
        "isTokenActive returns false for expired JWT token",
        .disabled(
            if: ProcessInfo.processInfo.environment["CI"] != nil,
            "OAuth token introspection tests disabled in CI"
        )
    )
    func isTokenActiveReturnsFalseForExpiredJWTToken() async throws {
        try await TestUtilities.withTimeout {
            // Given: Expired JWT token
            let pastExpiry = Date().timeIntervalSince1970 - 3600  // 1 hour ago
            let expiredToken = createMockJWT(
                exp: pastExpiry,
                iss: "http://localhost:2222/realms/luxe"
            )
            let oidcConfig = OIDCConfiguration.create(from: .development)

            // When: Checking if token is active
            let isActive = try await TokenIntrospectionUtilities.isTokenActive(
                token: expiredToken,
                oidcConfig: oidcConfig
            )

            // Then: Should not be active
            #expect(isActive == false)
        }
    }

    @Test(
        "isTokenActive throws error for empty token",
        .disabled(
            if: ProcessInfo.processInfo.environment["CI"] != nil,
            "OAuth token introspection tests disabled in CI"
        )
    )
    func isTokenActiveThrowsErrorForEmptyToken() async throws {
        try await TestUtilities.withTimeout {
            // Given: Empty token
            let emptyToken = ""
            let oidcConfig = OIDCConfiguration.create(from: .development)

            // When/Then: Should throw error
            await #expect(throws: TokenIntrospectionUtilities.IntrospectionError.invalidToken) {
                try await TokenIntrospectionUtilities.isTokenActive(
                    token: emptyToken,
                    oidcConfig: oidcConfig
                )
            }
        }
    }

    @Test(
        "isTokenActive returns true for opaque token without remote introspection",
        .disabled(
            if: ProcessInfo.processInfo.environment["CI"] != nil,
            "OAuth token introspection tests disabled in CI"
        )
    )
    func isTokenActiveReturnsTrueForOpaqueTokenWithoutRemoteIntrospection() async throws {
        try await TestUtilities.withTimeout {
            // Given: Opaque token (non-JWT)
            let opaqueToken = "opaque-access-token-12345"
            let oidcConfig = OIDCConfiguration.create(from: .development)

            // When: Checking if token is active (no remote introspection)
            let isActive = try await TokenIntrospectionUtilities.isTokenActive(
                token: opaqueToken,
                oidcConfig: oidcConfig,
                useRemoteIntrospection: false
            )

            // Then: Should be active (default behavior for opaque tokens)
            #expect(isActive == true)
        }
    }

    @Test(
        "introspectToken returns metadata for JWT token",
        .disabled(
            if: ProcessInfo.processInfo.environment["CI"] != nil,
            "OAuth token introspection tests disabled in CI"
        )
    )
    func introspectTokenReturnsMetadataForJWTToken() async throws {
        try await TestUtilities.withTimeout {
            // Given: JWT token with specific claims
            let expiry = Date().timeIntervalSince1970 + 3600
            let issued = Date().timeIntervalSince1970
            let token = createMockJWT(
                exp: expiry,
                iat: issued,
                sub: "test-user-123",
                iss: "http://localhost:2222/realms/luxe",
                scope: "openid profile email"
            )
            let oidcConfig = OIDCConfiguration.create(from: .development)

            // When: Introspecting token
            let introspection = try await TokenIntrospectionUtilities.introspectToken(
                token: token,
                oidcConfig: oidcConfig
            )

            // Then: Should return correct metadata
            #expect(introspection.active == true)
            #expect(introspection.sub == "test-user-123")
            #expect(introspection.iss == "http://localhost:2222/realms/luxe")
            #expect(introspection.scope == "openid profile email")
            #expect(introspection.exp == expiry)
            #expect(introspection.iat == issued)
            #expect(introspection.scopes == ["openid", "profile", "email"])
        }
    }

    @Test(
        "introspectToken returns metadata for opaque token",
        .disabled(
            if: ProcessInfo.processInfo.environment["CI"] != nil,
            "OAuth token introspection tests disabled in CI"
        )
    )
    func introspectTokenReturnsMetadataForOpaqueToken() async throws {
        try await TestUtilities.withTimeout {
            // Given: Opaque token
            let opaqueToken = "opaque-token-abcd1234"
            let oidcConfig = OIDCConfiguration.create(from: .development)

            // When: Introspecting token
            let introspection = try await TokenIntrospectionUtilities.introspectToken(
                token: opaqueToken,
                oidcConfig: oidcConfig
            )

            // Then: Should return mock metadata
            #expect(introspection.active == true)
            #expect(introspection.scope == "openid profile email")
            #expect(introspection.clientId == oidcConfig.clientId)
            #expect(introspection.username == "test-user")
            #expect(introspection.tokenType == "Bearer")
            #expect(introspection.iss == oidcConfig.issuer)
        }
    }

    @Test("validateTokenCriteria returns true for token with required scopes")
    func validateTokenCriteriaReturnsTrueForTokenWithRequiredScopes() throws {
        // Given: Token with specific scopes
        let futureExpiry = Date().timeIntervalSince1970 + 3600
        let token = createMockJWT(
            exp: futureExpiry,
            scope: "openid profile email admin"
        )

        // When: Validating token criteria
        let isValid = try TokenIntrospectionUtilities.validateTokenCriteria(
            token: token,
            requiredScopes: ["openid", "profile"]
        )

        // Then: Should be valid
        #expect(isValid == true)
    }

    @Test("validateTokenCriteria returns false for token missing required scopes")
    func validateTokenCriteriaReturnsFalseForTokenMissingRequiredScopes() throws {
        // Given: Token with limited scopes
        let futureExpiry = Date().timeIntervalSince1970 + 3600
        let token = createMockJWT(
            exp: futureExpiry,
            scope: "openid profile"
        )

        // When: Validating token criteria with missing scope
        let isValid = try TokenIntrospectionUtilities.validateTokenCriteria(
            token: token,
            requiredScopes: ["openid", "profile", "admin"]
        )

        // Then: Should not be valid
        #expect(isValid == false)
    }

    @Test("validateTokenCriteria returns true for token with correct audience")
    func validateTokenCriteriaReturnsTrueForTokenWithCorrectAudience() throws {
        // Given: Token with specific audience
        let futureExpiry = Date().timeIntervalSince1970 + 3600
        let token = createMockJWT(
            exp: futureExpiry,
            aud: "api-client"
        )

        // When: Validating token criteria
        let isValid = try TokenIntrospectionUtilities.validateTokenCriteria(
            token: token,
            requiredAudience: "api-client"
        )

        // Then: Should be valid
        #expect(isValid == true)
    }

    @Test("validateTokenCriteria returns false for token with wrong audience")
    func validateTokenCriteriaReturnsFalseForTokenWithWrongAudience() throws {
        // Given: Token with different audience
        let futureExpiry = Date().timeIntervalSince1970 + 3600
        let token = createMockJWT(
            exp: futureExpiry,
            aud: "wrong-client"
        )

        // When: Validating token criteria
        let isValid = try TokenIntrospectionUtilities.validateTokenCriteria(
            token: token,
            requiredAudience: "api-client"
        )

        // Then: Should not be valid
        #expect(isValid == false)
    }

    @Test("validateTokenCriteria returns false for expired token")
    func validateTokenCriteriaReturnsFalseForExpiredToken() throws {
        // Given: Expired token
        let pastExpiry = Date().timeIntervalSince1970 - 3600
        let token = createMockJWT(exp: pastExpiry)

        // When: Validating token criteria
        let isValid = try TokenIntrospectionUtilities.validateTokenCriteria(token: token)

        // Then: Should not be valid
        #expect(isValid == false)
    }

    @Test("getTokenClaims returns claims dictionary for JWT token")
    func getTokenClaimsReturnsClaimsDictionaryForJWTToken() throws {
        // Given: JWT token with specific claims
        let expiry = Date().timeIntervalSince1970 + 3600
        let token = createMockJWT(
            exp: expiry,
            sub: "user-123",
            iss: "test-issuer"
        )

        // When: Getting token claims
        let claims = try TokenIntrospectionUtilities.getTokenClaims(token)

        // Then: Should return correct claims
        #expect(claims["sub"] as? String == "user-123")
        #expect(claims["iss"] as? String == "test-issuer")
        // Allow for floating-point precision differences
        let claimsExpiry = claims["exp"] as? TimeInterval ?? 0
        #expect(abs(claimsExpiry - expiry) < 0.001)
    }

    @Test("getTokenClaims throws error for malformed token")
    func getTokenClaimsThrowsErrorForMalformedToken() throws {
        // Given: Malformed token
        let malformedToken = "not.a.valid.jwt.token"

        // When/Then: Should throw error
        #expect(throws: TokenIntrospectionUtilities.IntrospectionError.invalidToken) {
            try TokenIntrospectionUtilities.getTokenClaims(malformedToken)
        }
    }

    @Test("hasClaimValue returns true for matching claim")
    func hasClaimValueReturnsTrueForMatchingClaim() throws {
        // Given: Token with specific claim
        let token = createMockJWT(sub: "test-user")

        // When: Checking claim value
        let hasCorrectSub = try TokenIntrospectionUtilities.hasClaimValue(
            token: token,
            claim: "sub",
            expectedValue: "test-user"
        )

        // Then: Should match
        #expect(hasCorrectSub == true)
    }

    @Test("hasClaimValue returns false for non-matching claim")
    func hasClaimValueReturnsFalseForNonMatchingClaim() throws {
        // Given: Token with specific claim
        let token = createMockJWT(sub: "test-user")

        // When: Checking different claim value
        let hasWrongSub = try TokenIntrospectionUtilities.hasClaimValue(
            token: token,
            claim: "sub",
            expectedValue: "different-user"
        )

        // Then: Should not match
        #expect(hasWrongSub == false)
    }

    @Test("getTimeUntilExpiration returns correct time for valid token")
    func getTimeUntilExpirationReturnsCorrectTimeForValidToken() throws {
        // Given: Token expiring in 30 minutes
        let thirtyMinutesFromNow = Date().timeIntervalSince1970 + 1800
        let token = createMockJWT(exp: thirtyMinutesFromNow)

        // When: Getting time until expiration
        let timeRemaining = try TokenIntrospectionUtilities.getTimeUntilExpiration(token)

        // Then: Should return approximately 30 minutes
        #expect(timeRemaining != nil)
        #expect(timeRemaining! > 1790)  // Allow some variance
        #expect(timeRemaining! < 1810)
    }

    @Test("getTimeUntilExpiration returns nil for expired token")
    func getTimeUntilExpirationReturnsNilForExpiredToken() throws {
        // Given: Expired token
        let pastExpiry = Date().timeIntervalSince1970 - 3600
        let token = createMockJWT(exp: pastExpiry)

        // When: Getting time until expiration
        let timeRemaining = try TokenIntrospectionUtilities.getTimeUntilExpiration(token)

        // Then: Should return nil
        #expect(timeRemaining == nil)
    }

    @Test("getTokenAge returns correct age for token")
    func getTokenAgeReturnsCorrectAgeForToken() throws {
        // Given: Token issued 10 minutes ago
        let tenMinutesAgo = Date().timeIntervalSince1970 - 600
        let token = createMockJWT(iat: tenMinutesAgo)

        // When: Getting token age
        let age = try TokenIntrospectionUtilities.getTokenAge(token)

        // Then: Should return approximately 10 minutes
        #expect(age != nil)
        #expect(age! > 590)  // Allow some variance
        #expect(age! < 610)
    }

    @Test("IntrospectionResponse hasScope returns true for existing scope")
    func introspectionResponseHasScopeReturnsTrueForExistingScope() {
        // Given: Introspection response with scopes
        let response = TokenIntrospectionUtilities.IntrospectionResponse(
            active: true,
            scope: "openid profile email admin"
        )

        // When: Checking for existing scope
        let hasProfile = response.hasScope("profile")
        let hasAdmin = response.hasScope("admin")

        // Then: Should return true
        #expect(hasProfile == true)
        #expect(hasAdmin == true)
    }

    @Test("IntrospectionResponse hasScope returns false for non-existing scope")
    func introspectionResponseHasScopeReturnsFalseForNonExistingScope() {
        // Given: Introspection response with limited scopes
        let response = TokenIntrospectionUtilities.IntrospectionResponse(
            active: true,
            scope: "openid profile"
        )

        // When: Checking for non-existing scope
        let hasAdmin = response.hasScope("admin")

        // Then: Should return false
        #expect(hasAdmin == false)
    }

    @Test("IntrospectionResponse hasScopes returns true for all existing scopes")
    func introspectionResponseHasScopesReturnsTrueForAllExistingScopes() {
        // Given: Introspection response with scopes
        let response = TokenIntrospectionUtilities.IntrospectionResponse(
            active: true,
            scope: "openid profile email admin"
        )

        // When: Checking for multiple existing scopes
        let hasRequiredScopes = response.hasScopes(["openid", "profile", "email"])

        // Then: Should return true
        #expect(hasRequiredScopes == true)
    }

    @Test("IntrospectionResponse hasScopes returns false for missing scopes")
    func introspectionResponseHasScopesReturnsFalseForMissingScopes() {
        // Given: Introspection response with limited scopes
        let response = TokenIntrospectionUtilities.IntrospectionResponse(
            active: true,
            scope: "openid profile"
        )

        // When: Checking for scopes including missing ones
        let hasRequiredScopes = response.hasScopes(["openid", "profile", "admin"])

        // Then: Should return false
        #expect(hasRequiredScopes == false)
    }

    @Test("IntrospectionResponse isExpired returns true for expired token")
    func introspectionResponseIsExpiredReturnsTrueForExpiredToken() {
        // Given: Introspection response with past expiration
        let pastExpiry = Date().timeIntervalSince1970 - 3600
        let response = TokenIntrospectionUtilities.IntrospectionResponse(
            active: true,
            exp: pastExpiry
        )

        // When: Checking if expired
        let isExpired = response.isExpired

        // Then: Should be expired
        #expect(isExpired == true)
    }

    @Test("IntrospectionResponse isExpired returns false for valid token")
    func introspectionResponseIsExpiredReturnsFalseForValidToken() {
        // Given: Introspection response with future expiration
        let futureExpiry = Date().timeIntervalSince1970 + 3600
        let response = TokenIntrospectionUtilities.IntrospectionResponse(
            active: true,
            exp: futureExpiry
        )

        // When: Checking if expired
        let isExpired = response.isExpired

        // Then: Should not be expired
        #expect(isExpired == false)
    }

    // MARK: - Helper Methods

    /// Create a mock JWT token with specified claims
    private func createMockJWT(
        exp: TimeInterval? = nil,
        iat: TimeInterval? = nil,
        nbf: TimeInterval? = nil,
        sub: String? = nil,
        iss: String? = nil,
        aud: String? = nil,
        scope: String? = nil,
        client_id: String? = nil
    ) -> String {
        let header: [String: Any] = ["typ": "JWT", "alg": "RS256"]

        var payload: [String: Any] = [:]
        if let exp = exp { payload["exp"] = exp }
        if let iat = iat { payload["iat"] = iat }
        if let nbf = nbf { payload["nbf"] = nbf }
        if let sub = sub { payload["sub"] = sub }
        if let iss = iss { payload["iss"] = iss }
        if let aud = aud { payload["aud"] = aud }
        if let scope = scope { payload["scope"] = scope }
        if let client_id = client_id { payload["client_id"] = client_id }

        let headerData = try! JSONSerialization.data(withJSONObject: header)
        let payloadData = try! JSONSerialization.data(withJSONObject: payload)

        let encodedHeader = headerData.base64URLEncodedString()
        let encodedPayload = payloadData.base64URLEncodedString()
        let signature = "mock-signature"

        return "\(encodedHeader).\(encodedPayload).\(signature)"
    }
}
