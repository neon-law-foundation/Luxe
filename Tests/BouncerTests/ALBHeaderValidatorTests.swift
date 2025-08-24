import Dali
import Foundation
import Logging
import TestUtilities
import Testing
import Vapor

@testable import Bouncer

@Suite("ALBHeaderValidator Tests")
struct ALBHeaderValidatorTests {

    private func createTestLogger() -> Logger {
        var logger = Logger(label: "test.alb.validator")
        logger.logLevel = .trace
        return logger
    }

    private func createValidJWT() -> String {
        // Create a simple JWT structure for testing
        let header = """
            {"alg":"RS256","kid":"test-key-id"}
            """

        let payload = """
            {
                "sub": "test-cognito-sub-123",
                "email": "testuser@example.com",
                "name": "Test User",
                "preferred_username": "testuser",
                "cognito:groups": ["staff", "customer"],
                "iss": "https://cognito-idp.us-west-2.amazonaws.com/us-west-2_TestPool",
                "aud": "test-audience",
                "exp": \(Int(Date().addingTimeInterval(3600).timeIntervalSince1970))
            }
            """

        let signature = "test-signature"

        let headerB64 = Data(header.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
        let payloadB64 = Data(payload.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
        let signatureB64 = Data(signature.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")

        return "\(headerB64).\(payloadB64).\(signatureB64)"
    }

    private func createExpiredJWT() -> String {
        // Create an expired JWT for testing
        let header = """
            {"alg":"RS256","kid":"test-key-id"}
            """

        let payload = """
            {
                "sub": "expired-cognito-sub",
                "email": "expired@example.com",
                "name": "Expired User",
                "preferred_username": "expired",
                "cognito:groups": ["customer"],
                "iss": "https://cognito-idp.us-west-2.amazonaws.com/us-west-2_TestPool",
                "aud": "test-audience",
                "exp": \(Int(Date().addingTimeInterval(-3600).timeIntervalSince1970))
            }
            """

        let signature = "test-signature"

        let headerB64 = Data(header.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
        let payloadB64 = Data(payload.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
        let signatureB64 = Data(signature.utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")

        return "\(headerB64).\(payloadB64).\(signatureB64)"
    }

    @Test("Should create validator with required parameters")
    func testValidatorCreation() async throws {
        let logger = createTestLogger()
        let _ = ALBHeaderValidator(logger: logger, requireAllHeaders: false)

        // Test passes if validator is created without issues
        #expect(Bool(true))
    }

    @Test("Should create validator requiring all headers")
    func testValidatorCreationRequireAll() async throws {
        let logger = createTestLogger()
        let _ = ALBHeaderValidator(logger: logger, requireAllHeaders: true)

        // Test passes if validator is created without issues
        #expect(Bool(true))
    }

    @Test("Should validate successfully with all required headers")
    func testValidationSuccessWithAllHeaders() async throws {
        try await TestUtilities.withApp { app, database in
            let logger = createTestLogger()
            let validator = ALBHeaderValidator(logger: logger, requireAllHeaders: false)

            let validJWT = createValidJWT()

            let request = Request(
                application: app,
                method: .GET,
                url: URI(string: "/test"),
                on: app.eventLoopGroup.next()
            )

            request.headers.add(name: "x-amzn-oidc-data", value: validJWT)
            request.headers.add(name: "x-amzn-oidc-accesstoken", value: "access-token-123")
            request.headers.add(name: "x-amzn-oidc-identity", value: "testuser@example.com")

            let result = validator.validate(request: request)

            #expect(result.isValid == true)
            #expect(result.errors.isEmpty)
            #expect(result.extractedData != nil)
            #expect(result.extractedData?.cognitoSub == "test-cognito-sub-123")
            #expect(result.extractedData?.email == "testuser@example.com")
            #expect(result.extractedData?.username == "testuser@example.com")
            #expect(result.extractedData?.cognitoGroups.contains("staff") == true)
        }
    }

    @Test("Should validate with warnings for missing optional headers")
    func testValidationWithOptionalHeadersWarnings() async throws {
        try await TestUtilities.withApp { app, database in
            let logger = createTestLogger()
            let validator = ALBHeaderValidator(logger: logger, requireAllHeaders: false)

            let validJWT = createValidJWT()

            let request = Request(
                application: app,
                method: .GET,
                url: URI(string: "/test"),
                on: app.eventLoopGroup.next()
            )

            // Only include the required OIDC data header
            request.headers.add(name: "x-amzn-oidc-data", value: validJWT)

            let result = validator.validate(request: request)

            #expect(result.isValid == true)
            #expect(result.errors.isEmpty)
            #expect(result.warnings.count >= 2)  // Missing accesstoken and identity headers
            #expect(result.extractedData != nil)
        }
    }

    @Test("Should fail validation when requiring all headers and some are missing")
    func testValidationFailsWhenRequiringAllHeaders() async throws {
        try await TestUtilities.withApp { app, database in
            let logger = createTestLogger()
            let validator = ALBHeaderValidator(logger: logger, requireAllHeaders: true)

            let validJWT = createValidJWT()

            let request = Request(
                application: app,
                method: .GET,
                url: URI(string: "/test"),
                on: app.eventLoopGroup.next()
            )

            // Only include the OIDC data header
            request.headers.add(name: "x-amzn-oidc-data", value: validJWT)

            let result = validator.validate(request: request)

            #expect(result.isValid == false)
            #expect(result.errors.count >= 2)  // Missing required headers
            #expect(result.hasErrors == true)
        }
    }

    @Test("Should fail validation with missing OIDC data header")
    func testValidationFailsMissingOIDCData() async throws {
        try await TestUtilities.withApp { app, database in
            let logger = createTestLogger()
            let validator = ALBHeaderValidator(logger: logger, requireAllHeaders: false)

            let request = Request(
                application: app,
                method: .GET,
                url: URI(string: "/test"),
                on: app.eventLoopGroup.next()
            )

            // No OIDC headers at all

            let result = validator.validate(request: request)

            #expect(result.isValid == false)
            #expect(result.errors.contains { $0.contains("x-amzn-oidc-data") })
            #expect(result.extractedData == nil)
        }
    }

    @Test("Should fail validation with empty OIDC data")
    func testValidationFailsEmptyOIDCData() async throws {
        try await TestUtilities.withApp { app, database in
            let logger = createTestLogger()
            let validator = ALBHeaderValidator(logger: logger, requireAllHeaders: false)

            let request = Request(
                application: app,
                method: .GET,
                url: URI(string: "/test"),
                on: app.eventLoopGroup.next()
            )

            request.headers.add(name: "x-amzn-oidc-data", value: "")

            let result = validator.validate(request: request)

            #expect(result.isValid == false)
            #expect(result.errors.contains { $0.contains("empty") })
            #expect(result.extractedData == nil)
        }
    }

    @Test("Should fail validation with malformed JWT")
    func testValidationFailsMalformedJWT() async throws {
        try await TestUtilities.withApp { app, database in
            let logger = createTestLogger()
            let validator = ALBHeaderValidator(logger: logger, requireAllHeaders: false)

            let request = Request(
                application: app,
                method: .GET,
                url: URI(string: "/test"),
                on: app.eventLoopGroup.next()
            )

            request.headers.add(name: "x-amzn-oidc-data", value: "not.a.valid.jwt.format")

            let result = validator.validate(request: request)

            #expect(result.isValid == false)
            #expect(result.errors.contains { $0.contains("JWT") || $0.contains("decode") })
            #expect(result.extractedData == nil)
        }
    }

    @Test("Should fail validation with expired JWT")
    func testValidationFailsExpiredJWT() async throws {
        try await TestUtilities.withApp { app, database in
            let logger = createTestLogger()
            let validator = ALBHeaderValidator(logger: logger, requireAllHeaders: false)

            let expiredJWT = createExpiredJWT()

            let request = Request(
                application: app,
                method: .GET,
                url: URI(string: "/test"),
                on: app.eventLoopGroup.next()
            )

            request.headers.add(name: "x-amzn-oidc-data", value: expiredJWT)

            let result = validator.validate(request: request)

            #expect(result.isValid == false)
            #expect(result.errors.contains { $0.contains("expired") })
        }
    }

    @Test("Should extract cognito groups from JWT")
    func testCognitoGroupsExtraction() async throws {
        try await TestUtilities.withApp { app, database in
            let logger = createTestLogger()
            let validator = ALBHeaderValidator(logger: logger, requireAllHeaders: false)

            let validJWT = createValidJWT()

            let request = Request(
                application: app,
                method: .GET,
                url: URI(string: "/test"),
                on: app.eventLoopGroup.next()
            )

            request.headers.add(name: "x-amzn-oidc-data", value: validJWT)

            let result = validator.validate(request: request)

            #expect(result.isValid == true)
            #expect(result.extractedData?.cognitoGroups.contains("staff") == true)
            #expect(result.extractedData?.cognitoGroups.contains("customer") == true)
            #expect(result.extractedData?.cognitoGroups.count == 2)
        }
    }

    @Test("Should handle base64 URL decoding properly")
    func testBase64URLDecoding() async throws {
        // Test the Data extension for base64URL decoding
        let testString = "Hello World! This is a test string with special characters: +/="
        let originalData = Data(testString.utf8)

        // Convert to base64URL format
        let base64Standard = originalData.base64EncodedString()
        let base64URL =
            base64Standard
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        // Test decoding
        guard let decodedData = Data(base64URLEncodedString: base64URL) else {
            throw Bouncer.ValidationError("Failed to decode base64URL string")
        }

        let decodedString = String(data: decodedData, encoding: .utf8)

        #expect(decodedString == testString)
    }
}
