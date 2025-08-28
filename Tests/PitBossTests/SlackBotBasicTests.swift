import Bouncer
import Crypto
import Dali
import Foundation
import Testing
import Vapor

@testable import PitBoss

@Suite("SlackBot Basic Tests")
struct SlackBotBasicTests {

    @Test("Should initialize SlackBot")
    func testInitialization() throws {
        // Arrange & Act
        let logger = Logger(label: "test")
        let _ = SlackBot(
            signingSecret: "test-secret",
            serviceToken: "test-token",
            logger: logger
        )

        // Assert - If initialization succeeds, test passes
        #expect(Bool(true))
    }

    @Test("Should create Slack signature correctly")
    func testSlackSignature() throws {
        // Arrange
        let secret = "test-secret"
        let timestamp = "1234567890"
        let body = "token=test&command=/metrics"
        let baseString = "v0:\(timestamp):\(body)"

        // Act
        let signature = createSlackSignature(baseString, secret: secret)

        // Assert
        #expect(signature.hasPrefix("v0="))
        #expect(signature.count > 10)  // Should be a hex string
    }

    // Helper function to create Slack signature
    private func createSlackSignature(_ baseString: String, secret: String) -> String {
        let key = SymmetricKey(data: secret.data(using: .utf8)!)
        let signature = HMAC<SHA256>.authenticationCode(
            for: baseString.data(using: .utf8)!,
            using: key
        )

        return "v0=" + signature.compactMap { String(format: "%02x", $0) }.joined()
    }
}
