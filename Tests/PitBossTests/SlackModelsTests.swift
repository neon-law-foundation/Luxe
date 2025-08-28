import Foundation
import Testing

@testable import PitBoss

@Suite("SlackModels Tests")
struct SlackModelsTests {

    @Test("Should decode webhook payload")
    func testDecodeWebhookPayload() throws {
        // Arrange
        let json = """
            {
                "type": "url_verification",
                "challenge": "test-challenge",
                "token": "test-token",
                "team_id": "T123456"
            }
            """

        // Act
        let payload = try JSONDecoder().decode(
            SlackWebhookPayload.self,
            from: json.data(using: .utf8)!
        )

        // Assert
        #expect(payload.type == "url_verification")
        #expect(payload.challenge == "test-challenge")
        #expect(payload.token == "test-token")
        #expect(payload.teamId == "T123456")
    }

    @Test("Should decode slash command")
    func testDecodeSlashCommand() throws {
        // Arrange
        let formData = [
            "token": "test-token",
            "team_id": "T123456",
            "team_domain": "test-team",
            "channel_id": "C123456",
            "channel_name": "general",
            "user_id": "U123456",
            "user_name": "testuser",
            "command": "/metrics",
            "text": "help",
            "response_url": "https://hooks.slack.com/commands/test",
            "trigger_id": "12345.67890",
        ]

        // Convert to JSON for testing
        let jsonData = try JSONSerialization.data(withJSONObject: formData)

        // Act
        let command = try JSONDecoder().decode(
            SlackSlashCommand.self,
            from: jsonData
        )

        // Assert
        #expect(command.token == "test-token")
        #expect(command.teamId == "T123456")
        #expect(command.command == "/metrics")
        #expect(command.text == "help")
        #expect(command.userId == "U123456")
    }

    @Test("Should encode command response")
    func testEncodeCommandResponse() throws {
        // Arrange
        let response = SlackCommandResponse(
            responseType: .inChannel,
            text: "Test response",
            blocks: [
                SlackBlock(
                    type: "section",
                    text: SlackText(type: "mrkdwn", text: "Hello *world*")
                )
            ]
        )

        // Act
        let data = try JSONEncoder().encode(response)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Assert
        #expect(json?["response_type"] as? String == "in_channel")
        #expect(json?["text"] as? String == "Test response")
        #expect((json?["blocks"] as? [[String: Any]])?.count == 1)
    }

    @Test("Should handle event callbacks")
    func testEventCallback() throws {
        // Arrange
        let json = """
            {
                "type": "event_callback",
                "token": "test-token",
                "team_id": "T123456",
                "event": {
                    "type": "app_mention",
                    "user": "U123456",
                    "text": "<@U789012> hello",
                    "channel": "C123456",
                    "ts": "1234567890.123456",
                    "event_ts": "1234567890.123456"
                }
            }
            """

        // Act
        let payload = try JSONDecoder().decode(
            SlackWebhookPayload.self,
            from: json.data(using: .utf8)!
        )

        // Assert
        #expect(payload.type == "event_callback")
        #expect(payload.event?.type == "app_mention")
        #expect(payload.event?.user == "U123456")
        #expect(payload.event?.text?.contains("hello") == true)
    }

    @Test("Should create block kit messages")
    func testBlockKitMessages() throws {
        // Arrange & Act
        let blocks = [
            SlackBlock(
                type: "header",
                text: SlackText(type: "plain_text", text: "Dashboard")
            ),
            SlackBlock(
                type: "divider",
                text: nil
            ),
            SlackBlock(
                type: "section",
                text: SlackText(
                    type: "mrkdwn",
                    text: "*Metrics*\\n• Users: 100\\n• Active: 80"
                )
            ),
        ]

        // Assert
        #expect(blocks.count == 3)
        #expect(blocks[0].type == "header")
        #expect(blocks[1].type == "divider")
        #expect(blocks[2].type == "section")

        // Verify encoding
        let data = try JSONEncoder().encode(blocks)
        #expect(data.count > 0)
    }

    @Test("Should handle interactive payloads")
    func testInteractivePayload() throws {
        // Arrange
        let json = """
            {
                "type": "block_actions",
                "token": "test-token",
                "action_ts": "1234567890.123456",
                "team": {
                    "id": "T123456",
                    "domain": "test-team"
                },
                "user": {
                    "id": "U123456",
                    "name": "Test User"
                },
                "channel": {
                    "id": "C123456",
                    "name": "general"
                },
                "response_url": "https://hooks.slack.com/actions/test",
                "actions": [{
                    "type": "button",
                    "action_id": "approve_button",
                    "value": "approve",
                    "action_ts": "1234567890.123456"
                }]
            }
            """

        // Act
        let payload = try JSONDecoder().decode(
            SlackInteractivePayload.self,
            from: json.data(using: .utf8)!
        )

        // Assert
        #expect(payload.type == "block_actions")
        #expect(payload.team.id == "T123456")
        #expect(payload.user.id == "U123456")
        #expect(payload.actions?.first?.actionId == "approve_button")
    }
}
