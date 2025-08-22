#if os(macOS)
import Foundation

// MARK: - Enums matching the database schema

enum TicketPriority: String, CaseIterable, Codable {
    case low
    case medium
    case high
    case critical

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "blue"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

enum TicketStatus: String, CaseIterable, Codable {
    case open
    case pending
    case inProgress = "in_progress"
    case resolved
    case closed

    var displayName: String {
        switch self {
        case .open: return "Open"
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .resolved: return "Resolved"
        case .closed: return "Closed"
        }
    }
}

enum TicketSource: String, CaseIterable, Codable {
    case web
    case email
    case phone
    case chat

    var displayName: String {
        switch self {
        case .web: return "Web"
        case .email: return "Email"
        case .phone: return "Phone"
        case .chat: return "Chat"
        }
    }
}

enum MessageType: String, Codable {
    case comment
    case statusChange = "status_change"
    case assignmentChange = "assignment_change"
}

// MARK: - Filter Enums

enum TicketFilter: String, CaseIterable {
    case all = "All Tickets"
    case unassigned = "Unassigned"
    case myTickets = "My Tickets"
    case open = "Open"
    case pending = "Pending"
    case inProgress = "In Progress"
    case resolved = "Resolved"
    case closed = "Closed"
    case highPriority = "High Priority"

    var systemImageName: String {
        switch self {
        case .all: return "tray.2"
        case .unassigned: return "person.crop.circle.badge.questionmark"
        case .myTickets: return "person.circle"
        case .open: return "envelope.open"
        case .pending: return "clock"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .resolved: return "checkmark.circle"
        case .closed: return "archivebox"
        case .highPriority: return "exclamationmark.triangle"
        }
    }
}

enum TicketSortOrder: String, CaseIterable {
    case dateDescending = "Newest First"
    case dateAscending = "Oldest First"
    case priority = "Priority"
    case status = "Status"
}

// MARK: - View Models

struct TicketPreview: Identifiable {
    let id: UUID
    let ticketNumber: String
    let subject: String
    let snippet: String
    let requesterName: String
    let priority: TicketPriority
    let status: TicketStatus
    let updatedAt: Date
    var isUnread: Bool = false
    var hasAttachment: Bool = false
}

struct TicketDetail {
    let id: UUID
    let ticketNumber: String
    let subject: String
    let description: String
    let requester: String
    let requesterEmail: String?
    var assignee: String?
    var priority: TicketPriority
    var status: TicketStatus
    let source: TicketSource
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date
    var resolvedAt: Date?
    var closedAt: Date?
}

struct TicketConversation: Identifiable {
    let id: UUID
    let ticketId: UUID
    let authorName: String
    let content: String
    let contentType: String
    let isInternal: Bool
    let isSystemMessage: Bool
    let messageType: MessageType
    let createdAt: Date
}

struct TicketAttachment: Identifiable {
    let id: UUID
    let ticketId: UUID
    let conversationId: UUID?
    let filename: String
    let fileSize: Int64
    let mimeType: String
    let uploadedBy: String
    let uploadedAt: Date
}

// MARK: - Filter Model

struct TicketFilterCriteria {
    var status: [TicketStatus]
    var priority: [TicketPriority]
    var assignee: UUID?
    var tags: [String]
}
#endif
