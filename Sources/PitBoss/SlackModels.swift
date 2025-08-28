import Vapor

// MARK: - Webhook Models

public struct SlackWebhookPayload: Content, Sendable {
    public let token: String?
    public let teamId: String?
    public let type: String
    public let challenge: String?
    public let event: SlackEvent?

    public enum CodingKeys: String, CodingKey {
        case token, type, challenge, event
        case teamId = "team_id"
    }
}

public struct SlackEvent: Content, Sendable {
    public let type: String
    public let user: String?
    public let text: String?
    public let channel: String?
    public let ts: String?
    public let eventTs: String?
    public let channelType: String?

    public enum CodingKeys: String, CodingKey {
        case type, user, text, channel, ts
        case eventTs = "event_ts"
        case channelType = "channel_type"
    }
}

// MARK: - Slash Command Models

public struct SlackSlashCommand: Content, Sendable {
    public let token: String
    public let teamId: String
    public let teamDomain: String
    public let channelId: String
    public let channelName: String
    public let userId: String
    public let userName: String
    public let command: String
    public let text: String
    public let responseUrl: String
    public let triggerId: String?
    public let apiAppId: String?

    public enum CodingKeys: String, CodingKey {
        case token, command, text
        case teamId = "team_id"
        case teamDomain = "team_domain"
        case channelId = "channel_id"
        case channelName = "channel_name"
        case userId = "user_id"
        case userName = "user_name"
        case responseUrl = "response_url"
        case triggerId = "trigger_id"
        case apiAppId = "api_app_id"
    }
}

// MARK: - Response Models

public struct SlackCommandResponse: Content, Sendable {
    public let responseType: ResponseType
    public let text: String
    public let blocks: [SlackBlock]?
    public let attachments: [SlackAttachment]?
    public let threadTs: String?
    public let replaceOriginal: Bool?
    public let deleteOriginal: Bool?

    public enum ResponseType: String, Codable, Sendable {
        case inChannel = "in_channel"
        case ephemeral = "ephemeral"
    }

    public enum CodingKeys: String, CodingKey {
        case text, blocks, attachments
        case responseType = "response_type"
        case threadTs = "thread_ts"
        case replaceOriginal = "replace_original"
        case deleteOriginal = "delete_original"
    }

    public init(
        responseType: ResponseType,
        text: String,
        blocks: [SlackBlock]? = nil,
        attachments: [SlackAttachment]? = nil,
        threadTs: String? = nil,
        replaceOriginal: Bool? = nil,
        deleteOriginal: Bool? = nil
    ) {
        self.responseType = responseType
        self.text = text
        self.blocks = blocks
        self.attachments = attachments
        self.threadTs = threadTs
        self.replaceOriginal = replaceOriginal
        self.deleteOriginal = deleteOriginal
    }
}

// MARK: - Block Kit Models

public struct SlackBlock: Content, Sendable {
    public let type: String
    public let text: SlackText?
    public let blockId: String?
    public let fields: [SlackText]?
    public let accessory: SlackAccessory?
    public let elements: [SlackElement]?

    public enum CodingKeys: String, CodingKey {
        case type, text, fields, accessory, elements
        case blockId = "block_id"
    }

    public init(
        type: String,
        text: SlackText?,
        blockId: String? = nil,
        fields: [SlackText]? = nil,
        accessory: SlackAccessory? = nil,
        elements: [SlackElement]? = nil
    ) {
        self.type = type
        self.text = text
        self.blockId = blockId
        self.fields = fields
        self.accessory = accessory
        self.elements = elements
    }
}

public struct SlackText: Content, Sendable {
    public let type: String
    public let text: String
    public let emoji: Bool?
    public let verbatim: Bool?

    public init(
        type: String,
        text: String,
        emoji: Bool? = nil,
        verbatim: Bool? = nil
    ) {
        self.type = type
        self.text = text
        self.emoji = emoji
        self.verbatim = verbatim
    }
}

public struct SlackAccessory: Content, Sendable {
    public let type: String
    public let text: SlackText?
    public let value: String?
    public let url: String?
    public let actionId: String?
    public let style: String?

    public enum CodingKeys: String, CodingKey {
        case type, text, value, url, style
        case actionId = "action_id"
    }
}

public struct SlackElement: Content, Sendable {
    public let type: String
    public let text: SlackText?
    public let actionId: String?
    public let value: String?
    public let url: String?
    public let style: String?

    public enum CodingKeys: String, CodingKey {
        case type, text, value, url, style
        case actionId = "action_id"
    }
}

// MARK: - Attachment Models

public struct SlackAttachment: Content, Sendable {
    public let color: String?
    public let fallback: String?
    public let title: String?
    public let titleLink: String?
    public let text: String?
    public let pretext: String?
    public let fields: [SlackAttachmentField]?
    public let footer: String?
    public let footerIcon: String?
    public let ts: Int?

    public enum CodingKeys: String, CodingKey {
        case color, fallback, title, text, pretext, fields, footer, ts
        case titleLink = "title_link"
        case footerIcon = "footer_icon"
    }
}

public struct SlackAttachmentField: Content, Sendable {
    public let title: String
    public let value: String
    public let short: Bool?

    public init(title: String, value: String, short: Bool? = nil) {
        self.title = title
        self.value = value
        self.short = short
    }
}

// MARK: - Interactive Components Models

public struct SlackInteractivePayload: Content, Sendable {
    public let type: String
    public let token: String
    public let actionTs: String
    public let messageTs: String?
    public let attachmentId: String?
    public let callbackId: String?
    public let team: SlackTeam
    public let user: SlackUser
    public let channel: SlackChannel
    public let originalMessage: SlackMessage?
    public let responseUrl: String
    public let triggerId: String?
    public let actions: [SlackAction]?

    public enum CodingKeys: String, CodingKey {
        case type, token, team, user, channel, actions
        case actionTs = "action_ts"
        case messageTs = "message_ts"
        case attachmentId = "attachment_id"
        case callbackId = "callback_id"
        case originalMessage = "original_message"
        case responseUrl = "response_url"
        case triggerId = "trigger_id"
    }
}

public struct SlackTeam: Content, Sendable {
    public let id: String
    public let domain: String
}

public struct SlackUser: Content, Sendable {
    public let id: String
    public let name: String
    public let username: String?
}

public struct SlackChannel: Content, Sendable {
    public let id: String
    public let name: String
}

public struct SlackMessage: Content, Sendable {
    public let type: String
    public let user: String?
    public let text: String
    public let ts: String
    public let blocks: [SlackBlock]?
    public let attachments: [SlackAttachment]?
}

public struct SlackAction: Content, Sendable {
    public let type: String
    public let actionId: String
    public let blockId: String?
    public let text: SlackText?
    public let value: String?
    public let actionTs: String

    public enum CodingKeys: String, CodingKey {
        case type, text, value
        case actionId = "action_id"
        case blockId = "block_id"
        case actionTs = "action_ts"
    }
}

// MARK: - OAuth Models

public struct SlackOAuthResponse: Content, Sendable {
    public let ok: Bool
    public let accessToken: String?
    public let tokenType: String?
    public let scope: String?
    public let botUserId: String?
    public let appId: String?
    public let team: SlackTeamInfo?
    public let error: String?

    public enum CodingKeys: String, CodingKey {
        case ok, scope, error, team
        case accessToken = "access_token"
        case tokenType = "token_type"
        case botUserId = "bot_user_id"
        case appId = "app_id"
    }
}

public struct SlackTeamInfo: Content, Sendable {
    public let id: String
    public let name: String
}

// MARK: - Error Response

public struct SlackErrorResponse: Content, Sendable, Error {
    public let ok: Bool
    public let error: String
    public let responseMetadata: SlackResponseMetadata?

    public enum CodingKeys: String, CodingKey {
        case ok, error
        case responseMetadata = "response_metadata"
    }
}

public struct SlackResponseMetadata: Content, Sendable {
    public let messages: [String]?
    public let warnings: [String]?
}
