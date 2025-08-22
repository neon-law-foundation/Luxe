import Bouncer
import Foundation
import TestUtilities
import Testing
import Vapor

@Suite("Token Refresh Utilities", .serialized)
struct TokenRefreshUtilitiesTests {

    @Test(
        "refreshTokens creates new access token from refresh token",
        .disabled(if: ProcessInfo.processInfo.environment["CI"] != nil, "OAuth token refresh tests disabled in CI")
    )
    func refreshTokensCreatesNewAccessToken() async throws {
        try await TestUtilities.withTimeout {
            // Given: Valid refresh token and configurations
            let futureExpiry = Date().timeIntervalSince1970 + 3600  // 1 hour from now
            let refreshToken = createMockJWT(exp: futureExpiry)
            let oidcConfig = OIDCConfiguration.create(from: .development)
            let oauthConfig = OAuthConfiguration.create(from: .development)

            // When: Refreshing tokens
            let response = try await TokenRefreshUtilities.refreshTokens(
                refreshToken: refreshToken,
                oidcConfig: oidcConfig,
                oauthConfig: oauthConfig
            )

            // Then: Should return new tokens
            #expect(response.accessToken.starts(with: "refreshed_access_token_"))
            #expect(response.refreshToken == refreshToken)  // Same refresh token should be returned
            #expect(response.idToken?.starts(with: "refreshed_id_token_") == true)
            #expect(response.expiresIn == 3600)
            #expect(response.tokenType == "Bearer")
        }
    }

    @Test(
        "refreshTokens throws error for empty refresh token",
        .disabled(if: ProcessInfo.processInfo.environment["CI"] != nil, "OAuth token refresh tests disabled in CI")
    )
    func refreshTokensThrowsErrorForEmptyRefreshToken() async throws {
        try await TestUtilities.withTimeout {
            // Given: Empty refresh token
            let refreshToken = ""
            let oidcConfig = OIDCConfiguration.create(from: .development)
            let oauthConfig = OAuthConfiguration.create(from: .development)

            // When/Then: Should throw error
            await #expect(throws: TokenRefreshUtilities.RefreshError.noRefreshToken) {
                try await TokenRefreshUtilities.refreshTokens(
                    refreshToken: refreshToken,
                    oidcConfig: oidcConfig,
                    oauthConfig: oauthConfig
                )
            }
        }
    }

    @Test("needsRefresh returns true for expired token")
    func needsRefreshReturnsTrueForExpiredToken() {
        // Given: Token with past expiration
        let expiredTime = Date().timeIntervalSince1970 - 3600  // 1 hour ago
        let expiredToken = createMockJWT(exp: expiredTime)

        // When: Checking if refresh needed
        let needsRefresh = TokenRefreshUtilities.needsRefresh(token: expiredToken)

        // Then: Should need refresh
        #expect(needsRefresh == true)
    }

    @Test("needsRefresh returns true for token expiring soon")
    func needsRefreshReturnsTrueForTokenExpiringSoon() {
        // Given: Token expiring in 2 minutes (less than default 5 minute buffer)
        let soonExpiry = Date().timeIntervalSince1970 + 120  // 2 minutes from now
        let expiringToken = createMockJWT(exp: soonExpiry)

        // When: Checking if refresh needed
        let needsRefresh = TokenRefreshUtilities.needsRefresh(token: expiringToken)

        // Then: Should need refresh
        #expect(needsRefresh == true)
    }

    @Test("needsRefresh returns false for fresh token")
    func needsRefreshReturnsFalseForFreshToken() {
        // Given: Token expiring in 1 hour (well beyond 5 minute buffer)
        let futureExpiry = Date().timeIntervalSince1970 + 3600  // 1 hour from now
        let freshToken = createMockJWT(exp: futureExpiry)

        // When: Checking if refresh needed
        let needsRefresh = TokenRefreshUtilities.needsRefresh(token: freshToken)

        // Then: Should not need refresh
        #expect(needsRefresh == false)
    }

    @Test("needsRefresh returns false for non-JWT token")
    func needsRefreshReturnsFalseForNonJWTToken() {
        // Given: Non-JWT token
        let nonJwtToken = "not-a-jwt-token"

        // When: Checking if refresh needed
        let needsRefresh = TokenRefreshUtilities.needsRefresh(token: nonJwtToken)

        // Then: Should not need refresh (can't determine)
        #expect(needsRefresh == false)
    }

    @Test("isTokenValid returns true for valid token")
    func isTokenValidReturnsTrueForValidToken() {
        // Given: Valid token expiring in future
        let futureExpiry = Date().timeIntervalSince1970 + 3600
        let validToken = createMockJWT(exp: futureExpiry)

        // When: Checking if token is valid
        let isValid = TokenRefreshUtilities.isTokenValid(validToken)

        // Then: Should be valid
        #expect(isValid == true)
    }

    @Test("isTokenValid returns false for expired token")
    func isTokenValidReturnsFalseForExpiredToken() {
        // Given: Expired token
        let pastExpiry = Date().timeIntervalSince1970 - 3600
        let expiredToken = createMockJWT(exp: pastExpiry)

        // When: Checking if token is valid
        let isValid = TokenRefreshUtilities.isTokenValid(expiredToken)

        // Then: Should be invalid
        #expect(isValid == false)
    }

    @Test("isTokenValid returns false for malformed token")
    func isTokenValidReturnsFalseForMalformedToken() {
        // Given: Malformed token
        let malformedToken = "not.a.valid.jwt"

        // When: Checking if token is valid
        let isValid = TokenRefreshUtilities.isTokenValid(malformedToken)

        // Then: Should be invalid
        #expect(isValid == false)
    }

    @Test("getTokenExpiration returns correct expiration date")
    func getTokenExpirationReturnsCorrectExpirationDate() {
        // Given: Token with specific expiration
        let expirationTime = Date().timeIntervalSince1970 + 3600
        let token = createMockJWT(exp: expirationTime)

        // When: Getting token expiration
        let expiration = TokenRefreshUtilities.getTokenExpiration(token)

        // Then: Should return correct expiration
        #expect(expiration != nil)
        #expect(abs(expiration!.timeIntervalSince1970 - expirationTime) < 1.0)
    }

    @Test("getTokenExpiration returns nil for non-JWT token")
    func getTokenExpirationReturnsNilForNonJWTToken() {
        // Given: Non-JWT token
        let nonJwtToken = "not-a-jwt"

        // When: Getting token expiration
        let expiration = TokenRefreshUtilities.getTokenExpiration(nonJwtToken)

        // Then: Should return nil
        #expect(expiration == nil)
    }

    @Test("getTokenTimeRemaining returns correct time for valid token")
    func getTokenTimeRemainingReturnsCorrectTimeForValidToken() {
        // Given: Token expiring in 30 minutes
        let thirtyMinutesFromNow = Date().timeIntervalSince1970 + 1800
        let token = createMockJWT(exp: thirtyMinutesFromNow)

        // When: Getting time remaining
        let timeRemaining = TokenRefreshUtilities.getTokenTimeRemaining(token)

        // Then: Should return approximately 30 minutes
        #expect(timeRemaining != nil)
        #expect(timeRemaining! > 1790)  // Allow some variance
        #expect(timeRemaining! < 1810)
    }

    @Test("getTokenTimeRemaining returns nil for expired token")
    func getTokenTimeRemainingReturnsNilForExpiredToken() {
        // Given: Expired token
        let pastExpiry = Date().timeIntervalSince1970 - 3600
        let expiredToken = createMockJWT(exp: pastExpiry)

        // When: Getting time remaining
        let timeRemaining = TokenRefreshUtilities.getTokenTimeRemaining(expiredToken)

        // Then: Should return nil
        #expect(timeRemaining == nil)
    }

    @Test("RefreshResponse initializes with correct values")
    func refreshResponseInitializesWithCorrectValues() {
        // Given: Response parameters
        let accessToken = "test_access_token"
        let refreshToken = "test_refresh_token"
        let idToken = "test_id_token"
        let expiresIn = 3600
        let tokenType = "Bearer"

        // When: Creating refresh response
        let response = TokenRefreshUtilities.RefreshResponse(
            accessToken: accessToken,
            refreshToken: refreshToken,
            idToken: idToken,
            expiresIn: expiresIn,
            tokenType: tokenType
        )

        // Then: Should have correct values
        #expect(response.accessToken == accessToken)
        #expect(response.refreshToken == refreshToken)
        #expect(response.idToken == idToken)
        #expect(response.expiresIn == expiresIn)
        #expect(response.tokenType == tokenType)
    }

    @Test("RefreshResponse initializes with defaults")
    func refreshResponseInitializesWithDefaults() {
        // Given: Minimal parameters
        let accessToken = "test_access_token"

        // When: Creating refresh response with defaults
        let response = TokenRefreshUtilities.RefreshResponse(accessToken: accessToken)

        // Then: Should have default values
        #expect(response.accessToken == accessToken)
        #expect(response.refreshToken == nil)
        #expect(response.idToken == nil)
        #expect(response.expiresIn == nil)
        #expect(response.tokenType == "Bearer")
    }

    // MARK: - Helper Methods

    /// Create a mock JWT token with specified expiration
    private func createMockJWT(exp: TimeInterval) -> String {
        let header: [String: Any] = ["typ": "JWT", "alg": "RS256"]
        let payload: [String: Any] = ["exp": exp, "sub": "test-user"]

        let headerData = try! JSONSerialization.data(withJSONObject: header)
        let payloadData = try! JSONSerialization.data(withJSONObject: payload)

        let encodedHeader = headerData.base64URLEncodedString()
        let encodedPayload = payloadData.base64URLEncodedString()
        let signature = "mock-signature"

        return "\(encodedHeader).\(encodedPayload).\(signature)"
    }
}

/// Extension to support base64URL encoding for tests
extension Data {
    func base64URLEncodedString() -> String {
        let base64 = self.base64EncodedString()
        return
            base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
