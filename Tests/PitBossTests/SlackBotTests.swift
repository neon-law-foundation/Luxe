import Bouncer
import Crypto
import Dali
import Foundation
import TestUtilities
import Testing
import Vapor
import VaporTesting

@testable import PitBoss

@Suite("SlackBot Tests")
struct SlackBotTests {

    @Test("Should handle URL verification challenge")
    func testURLVerification() async throws {
        // Arrange
        let app = try await Application.make(.testing)
        defer {
            Task {
                try await app.asyncShutdown()
            }
        }

        let slackBot = SlackBot(
            signingSecret: "test-secret",
            serviceToken: "test-token",
            logger: app.logger
        )

        try slackBot.configure(app)

        let challenge = "test-challenge-12345"
        let payload = """
            {
                "type": "url_verification",
                "challenge": "\(challenge)",
                "token": "test-token"
            }
            """

        // Create signature for the request
        let timestamp = "\(Int(Date().timeIntervalSince1970))"
        let signatureBase = "v0:\(timestamp):\(payload)"
        let signature = createSlackSignature(signatureBase, secret: "test-secret")

        // Act & Assert
        try await app.test(
            .POST,
            "/slack/webhook",
            headers: [
                "X-Slack-Signature": signature,
                "X-Slack-Request-Timestamp": timestamp,
                "Content-Type": "application/json",
            ],
            body: ByteBuffer(string: payload)
        ) { res in
            #expect(res.status == .ok)
            #expect(res.body.string == challenge)
        }
    }

    @Test("Should reject invalid signatures")
    func testInvalidSignature() async throws {
        // Arrange
        let app = try await Application.make(.testing)
        defer {
            Task {
                try await app.asyncShutdown()
            }
        }

        let slackBot = SlackBot(
            signingSecret: "test-secret",
            serviceToken: "test-token",
            logger: app.logger
        )

        try slackBot.configure(app)

        let payload = """
            {
                "type": "event_callback",
                "token": "test-token"
            }
            """

        let timestamp = "\(Int(Date().timeIntervalSince1970))"

        // Act & Assert
        try await app.test(
            .POST,
            "/slack/webhook",
            headers: [
                "X-Slack-Signature": "v0=invalid-signature",
                "X-Slack-Request-Timestamp": timestamp,
                "Content-Type": "application/json",
            ],
            body: ByteBuffer(string: payload)
        ) { res in
            #expect(res.status == .unauthorized)
        }
    }

    @Test("Should handle metrics slash command")
    func testMetricsCommand() async throws {
        try await TestUtilities.withApp { app, db in
            let slackBot = SlackBot(
                signingSecret: "test-secret",
                serviceToken: "test-token",
                logger: app.logger
            )

            try slackBot.configure(app)

            let commandData = [
                "token": "test-token",
                "team_id": "T123456",
                "team_domain": "test-team",
                "channel_id": "C123456",
                "channel_name": "general",
                "user_id": "U123456",
                "user_name": "testuser",
                "command": "/metrics",
                "text": "",
                "response_url": "https://hooks.slack.com/commands/test",
            ].map { "\($0.key)=\($0.value)" }.joined(separator: "&")

            let timestamp = "\(Int(Date().timeIntervalSince1970))"
            let signatureBase = "v0:\(timestamp):\(commandData)"
            let signature = createSlackSignature(signatureBase, secret: "test-secret")

            // Act & Assert
            try await app.test(
                .POST,
                "/slack/slash-command",
                headers: [
                    "X-Slack-Signature": signature,
                    "X-Slack-Request-Timestamp": timestamp,
                    "Content-Type": "application/x-www-form-urlencoded",
                ],
                body: ByteBuffer(string: commandData)
            ) { res in
                #expect(res.status == .ok)

                let response = try res.content.decode(SlackCommandResponse.self)
                #expect(response.responseType == .inChannel)
                #expect(response.text.contains("Team Metrics"))
            }
        }
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
