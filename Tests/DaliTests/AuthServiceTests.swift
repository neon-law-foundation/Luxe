import Fluent
import FluentPostgresDriver
import Logging
import PostgresNIO
import TestUtilities
import Testing
import Vapor

@testable import Dali
@testable import Palette

@Suite("Auth Service Tests", .serialized)
struct AuthServiceTests {

    @Test(
        "AuthService can build authorization URL for development",
        .disabled("URL state parameter encoding issue - needs investigation")
    )
    func authServiceCanBuildAuthorizationURLForDevelopment() async throws {
        // Create test OIDC configuration
        let oidcConfig = OIDCConfiguration(
            issuer: "http://localhost:8081/realms/SagebrushServices",
            clientId: "sagebrush-web",
            audienceId: "sagebrush-web"
        )

        let redirectPath = "/test/path"

        // Test development URL building (ENV != PRODUCTION)
        let authURL = AuthService.buildAuthorizationURL(oidcConfig: oidcConfig, redirectPath: redirectPath)

        #expect(authURL.contains("http://localhost:8081/realms/SagebrushServices/protocol/openid-connect/auth"))
        #expect(authURL.contains("client_id=sagebrush-web"))
        #expect(authURL.contains("redirect_uri=http://localhost:8080/auth/callback"))
        #expect(authURL.contains("response_type=code"))
        #expect(authURL.contains("scope=openid%20email%20profile"))
        #expect(authURL.contains("state=%2Ftest%2Fpath"))
    }

    @Test("AuthService can build logout URL")
    func authServiceCanBuildLogoutURL() async throws {
        let oidcConfig = OIDCConfiguration(
            issuer: "http://localhost:8081/realms/SagebrushServices",
            clientId: "sagebrush-web",
            audienceId: "sagebrush-web"
        )

        let logoutURL = AuthService.buildLogoutURL(oidcConfig: oidcConfig)

        #expect(logoutURL.contains("http://localhost:8081/realms/SagebrushServices/protocol/openid-connect/logout"))
        #expect(logoutURL.contains("client_id=sagebrush-web"))
        #expect(logoutURL.contains("post_logout_redirect_uri=http://localhost:8080/"))
    }

    @Test("AuthService can create logout cookie")
    func authServiceCanCreateLogoutCookie() async throws {
        let logoutCookie = AuthService.createLogoutCookie()

        #expect(logoutCookie.string == "")
        #expect(logoutCookie.path == "/")
        #expect(logoutCookie.isHTTPOnly == true)
        #expect(logoutCookie.sameSite == .lax)
        #expect(logoutCookie.expires != nil)
        #expect(logoutCookie.expires! < Date())  // Should be expired
    }

    @Test("AuthService validates OIDC configuration")
    func authServiceValidatesOIDCConfiguration() async throws {
        // Test valid configuration
        let validConfig = OIDCConfiguration(
            issuer: "http://localhost:8081/realms/SagebrushServices",
            clientId: "sagebrush-web",
            audienceId: "sagebrush-web"
        )

        // Should not throw
        try AuthService.validateConfiguration(validConfig)

        // Test invalid configuration - empty issuer
        let invalidIssuerConfig = OIDCConfiguration(
            issuer: "",
            clientId: "sagebrush-web",
            audienceId: "sagebrush-web"
        )

        do {
            try AuthService.validateConfiguration(invalidIssuerConfig)
            #expect(Bool(false), "Should throw ValidationError for empty issuer")
        } catch let error as ValidationError {
            #expect(error.message.contains("OIDC issuer cannot be empty"))
        }

        // Test invalid configuration - empty client ID
        let invalidClientIdConfig = OIDCConfiguration(
            issuer: "http://localhost:8081/realms/SagebrushServices",
            clientId: "",
            audienceId: "sagebrush-web"
        )

        do {
            try AuthService.validateConfiguration(invalidClientIdConfig)
            #expect(Bool(false), "Should throw ValidationError for empty client ID")
        } catch let error as ValidationError {
            #expect(error.message.contains("OIDC client ID cannot be empty"))
        }
    }

    @Test("AuthService determines redirect path correctly")
    func authServiceDeterminesRedirectPathCorrectly() async throws {
        // Test with valid path
        let validPath = AuthService.determineRedirectPath(from: "/valid/path")
        #expect(validPath == "/valid/path")

        // Test with nil state
        let nilPath = AuthService.determineRedirectPath(from: nil)
        #expect(nilPath == "/app/me")

        // Test with empty state
        let emptyPath = AuthService.determineRedirectPath(from: "")
        #expect(emptyPath == "/app/me")

        // Test with invalid path (doesn't start with /)
        let invalidPath = AuthService.determineRedirectPath(from: "invalid/path")
        #expect(invalidPath == "/app/me")

        // Test with potentially malicious path
        let maliciousPath = AuthService.determineRedirectPath(from: "http://evil.com/path")
        #expect(maliciousPath == "/app/me")
    }

    @Test("AuthService can decode JWT username from token")
    func authServiceCanDecodeJWTUsernameFromToken() async throws {
        // Create a simple JWT token for testing
        // Format: header.payload.signature (we'll skip signature validation for testing)
        let header = """
            {"alg":"HS256","typ":"JWT"}
            """.data(using: .utf8)!.base64EncodedString()

        let payload = """
            {
                "sub": "test-user-123",
                "email": "test@example.com",
                "preferred_username": "testuser"
            }
            """.data(using: .utf8)!.base64EncodedString()

        let signature = "fake-signature"
        let testToken = "\(header).\(payload).\(signature)"

        let username = try AuthService.decodeUsernameFromToken(testToken)

        // Should use email first
        #expect(username == "test@example.com")
    }

    @Test("AuthService JWT decoding prefers email over preferred_username")
    func authServiceJWTDecodingPrefersEmailOverPreferredUsername() async throws {
        let header = """
            {"alg":"HS256","typ":"JWT"}
            """.data(using: .utf8)!.base64EncodedString()

        let payload = """
            {
                "sub": "test-user-123",
                "preferred_username": "testuser",
                "email": ""
            }
            """.data(using: .utf8)!.base64EncodedString()

        let signature = "fake-signature"
        let testToken = "\(header).\(payload).\(signature)"

        let username = try AuthService.decodeUsernameFromToken(testToken)

        // Should use preferred_username when email is empty
        #expect(username == "testuser")
    }

    @Test("AuthService JWT decoding falls back to sub")
    func authServiceJWTDecodingFallsBackToSub() async throws {
        let header = """
            {"alg":"HS256","typ":"JWT"}
            """.data(using: .utf8)!.base64EncodedString()

        let payload = """
            {
                "sub": "test-user-123"
            }
            """.data(using: .utf8)!.base64EncodedString()

        let signature = "fake-signature"
        let testToken = "\(header).\(payload).\(signature)"

        let username = try AuthService.decodeUsernameFromToken(testToken)

        // Should use sub when no other fields available
        #expect(username == "test-user-123")
    }

    @Test("AuthService JWT decoding handles invalid tokens")
    func authServiceJWTDecodingHandlesInvalidTokens() async throws {
        // Test with malformed token (wrong number of parts)
        do {
            _ = try AuthService.decodeUsernameFromToken("invalid.token")
            #expect(Bool(false), "Should throw ValidationError for malformed token")
        } catch let error as ValidationError {
            #expect(error.message.contains("Invalid JWT format"))
        }

        // Test with invalid base64 payload
        do {
            _ = try AuthService.decodeUsernameFromToken("header.invalid-base64.signature")
            #expect(Bool(false), "Should throw ValidationError for invalid base64")
        } catch let error as ValidationError {
            #expect(error.message.contains("Failed to decode JWT payload"))
        }
    }

    @Test("AuthService can extract callback parameters from request")
    func authServiceCanExtractCallbackParametersFromRequest() async throws {
        try await TestUtilities.withApp { app, database in
            // Create a mock request with query parameters
            let uri = URI(string: "/auth/callback?code=test-auth-code&state=/original/path")
            var headers = HTTPHeaders()
            headers.add(name: .contentType, value: "application/x-www-form-urlencoded")

            let request = Request(
                application: app,
                method: .GET,
                url: uri,
                headers: headers,
                on: app.eventLoopGroup.next()
            )

            let (code, originalPath) = try AuthService.extractCallbackParameters(from: request)

            #expect(code == "test-auth-code")
            #expect(originalPath == "/original/path")
        }
    }

    @Test("AuthService handles missing callback parameters gracefully")
    func authServiceHandlesMissingCallbackParametersGracefully() async throws {
        try await TestUtilities.withApp { app, database in
            // Create a mock request without required parameters
            let uri = URI(string: "/auth/callback")
            let request = Request(
                application: app,
                method: .GET,
                url: uri,
                on: app.eventLoopGroup.next()
            )

            do {
                _ = try AuthService.extractCallbackParameters(from: request)
                #expect(Bool(false), "Should throw ValidationError for missing code parameter")
            } catch let error as ValidationError {
                #expect(error.message.contains("Missing authorization code"))
            }
        }
    }
}
