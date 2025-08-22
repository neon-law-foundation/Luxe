import Fluent
import FluentPostgresDriver
import Foundation

/// Service for tracking and analyzing newsletter engagement metrics
public struct NewsletterAnalyticsService {
    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    /// Track a newsletter event (sent, opened, clicked, unsubscribed)
    public func trackEvent(
        newsletterId: UUID,
        userId: UUID?,
        eventType: NewsletterEventType,
        eventData: [String: String]? = nil,
        ipAddress: String? = nil,
        userAgent: String? = nil
    ) async throws {
        guard let postgresDB = database as? PostgresDatabase else {
            throw NewsletterAnalyticsError.databaseError
        }

        let eventDataJson: String
        if let eventData = eventData {
            let jsonData = try JSONSerialization.data(withJSONObject: eventData, options: [])
            eventDataJson = String(data: jsonData, encoding: .utf8) ?? "{}"
        } else {
            eventDataJson = "{}"
        }

        _ = try await postgresDB.sql()
            .raw(
                """
                INSERT INTO marketing.newsletter_analytics 
                (newsletter_id, user_id, event_type, event_data, ip_address, user_agent)
                VALUES (\(bind: newsletterId), \(bind: userId), \(bind: eventType.rawValue), \(bind: eventDataJson)::jsonb, \(bind: ipAddress), \(bind: userAgent))
                """
            )
            .run()
    }

    /// Get analytics summary for a specific newsletter
    public func getNewsletterAnalytics(newsletterId: UUID) async throws -> NewsletterAnalyticsSummary {
        guard let postgresDB = database as? PostgresDatabase else {
            throw NewsletterAnalyticsError.databaseError
        }

        let result = try await postgresDB.sql()
            .raw(
                """
                SELECT 
                    event_type,
                    COUNT(*) as event_count,
                    COUNT(DISTINCT user_id) as unique_users
                FROM marketing.newsletter_analytics 
                WHERE newsletter_id = \(bind: newsletterId)
                GROUP BY event_type
                """
            )
            .all()

        var sentCount = 0
        var openedCount = 0
        var clickedCount = 0
        var unsubscribedCount = 0
        var uniqueOpens = 0
        var uniqueClicks = 0

        for row in result {
            guard let eventType = try row.decode(column: "event_type", as: String?.self),
                let count = try row.decode(column: "event_count", as: Int?.self),
                let uniqueUsers = try row.decode(column: "unique_users", as: Int?.self)
            else { continue }

            switch eventType {
            case "sent":
                sentCount = count
            case "opened":
                openedCount = count
                uniqueOpens = uniqueUsers
            case "clicked":
                clickedCount = count
                uniqueClicks = uniqueUsers
            case "unsubscribed":
                unsubscribedCount = count
            default:
                break
            }
        }

        let openRate = sentCount > 0 ? Double(openedCount) / Double(sentCount) : 0.0
        let clickRate = openedCount > 0 ? Double(clickedCount) / Double(openedCount) : 0.0
        let unsubscribeRate = sentCount > 0 ? Double(unsubscribedCount) / Double(sentCount) : 0.0

        return NewsletterAnalyticsSummary(
            newsletterId: newsletterId,
            sentCount: sentCount,
            openedCount: openedCount,
            clickedCount: clickedCount,
            unsubscribedCount: unsubscribedCount,
            uniqueOpens: uniqueOpens,
            uniqueClicks: uniqueClicks,
            openRate: openRate,
            clickRate: clickRate,
            unsubscribeRate: unsubscribeRate
        )
    }

    /// Get overall newsletter performance statistics
    public func getOverallAnalytics() async throws -> OverallNewsletterAnalytics {
        guard let postgresDB = database as? PostgresDatabase else {
            throw NewsletterAnalyticsError.databaseError
        }

        let result = try await postgresDB.sql()
            .raw(
                """
                SELECT 
                    n.name as newsletter_type,
                    COUNT(DISTINCT n.id) as newsletter_count,
                    COALESCE(SUM(CASE WHEN na.event_type = 'sent' THEN 1 ELSE 0 END), 0) as total_sent,
                    COALESCE(SUM(CASE WHEN na.event_type = 'opened' THEN 1 ELSE 0 END), 0) as total_opened,
                    COALESCE(SUM(CASE WHEN na.event_type = 'clicked' THEN 1 ELSE 0 END), 0) as total_clicked
                FROM marketing.newsletters n
                LEFT JOIN marketing.newsletter_analytics na ON n.id = na.newsletter_id
                WHERE n.sent_at IS NOT NULL
                GROUP BY n.name
                """
            )
            .all()

        var typeAnalytics: [String: NewsletterTypeAnalytics] = [:]

        for row in result {
            guard let newsletterType = try row.decode(column: "newsletter_type", as: String?.self),
                let newsletterCount = try row.decode(column: "newsletter_count", as: Int?.self),
                let totalSent = try row.decode(column: "total_sent", as: Int?.self),
                let totalOpened = try row.decode(column: "total_opened", as: Int?.self),
                let totalClicked = try row.decode(column: "total_clicked", as: Int?.self)
            else { continue }

            let openRate = totalSent > 0 ? Double(totalOpened) / Double(totalSent) : 0.0
            let clickRate = totalOpened > 0 ? Double(totalClicked) / Double(totalOpened) : 0.0

            typeAnalytics[newsletterType] = NewsletterTypeAnalytics(
                type: newsletterType,
                newsletterCount: newsletterCount,
                totalSent: totalSent,
                totalOpened: totalOpened,
                totalClicked: totalClicked,
                averageOpenRate: openRate,
                averageClickRate: clickRate
            )
        }

        return OverallNewsletterAnalytics(typeAnalytics: typeAnalytics)
    }

    /// Get recent analytics events for admin dashboard
    public func getRecentEvents(limit: Int = 50) async throws -> [NewsletterAnalyticsEvent] {
        guard let postgresDB = database as? PostgresDatabase else {
            throw NewsletterAnalyticsError.databaseError
        }

        let result = try await postgresDB.sql()
            .raw(
                """
                SELECT 
                    na.id,
                    na.newsletter_id,
                    na.user_id,
                    na.event_type,
                    na.event_data,
                    na.created_at,
                    n.subject_line,
                    n.name as newsletter_type
                FROM marketing.newsletter_analytics na
                JOIN marketing.newsletters n ON na.newsletter_id = n.id
                ORDER BY na.created_at DESC
                LIMIT \(bind: limit)
                """
            )
            .all()

        return try result.compactMap { row in
            guard let id = try row.decode(column: "id", as: UUID?.self),
                let newsletterId = try row.decode(column: "newsletter_id", as: UUID?.self),
                let eventTypeString = try row.decode(column: "event_type", as: String?.self),
                let eventType = NewsletterEventType(rawValue: eventTypeString),
                let createdAt = try row.decode(column: "created_at", as: Date?.self),
                let subjectLine = try row.decode(column: "subject_line", as: String?.self),
                let newsletterType = try row.decode(column: "newsletter_type", as: String?.self)
            else { return nil }

            let userId = try row.decode(column: "user_id", as: UUID?.self)
            let eventDataString = try row.decode(column: "event_data", as: String?.self)

            var eventData: [String: String] = [:]
            if let eventDataString = eventDataString,
                let jsonData = eventDataString.data(using: .utf8)
            {
                eventData = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: String] ?? [:]
            }

            return NewsletterAnalyticsEvent(
                id: id,
                newsletterId: newsletterId,
                userId: userId,
                eventType: eventType,
                eventData: eventData,
                createdAt: createdAt,
                subjectLine: subjectLine,
                newsletterType: newsletterType
            )
        }
    }
}

// MARK: - Supporting Types

public enum NewsletterEventType: String, CaseIterable, Sendable {
    case sent = "sent"
    case opened = "opened"
    case clicked = "clicked"
    case unsubscribed = "unsubscribed"
}

public struct NewsletterAnalyticsSummary: Sendable {
    public let newsletterId: UUID
    public let sentCount: Int
    public let openedCount: Int
    public let clickedCount: Int
    public let unsubscribedCount: Int
    public let uniqueOpens: Int
    public let uniqueClicks: Int
    public let openRate: Double
    public let clickRate: Double
    public let unsubscribeRate: Double

    public init(
        newsletterId: UUID,
        sentCount: Int,
        openedCount: Int,
        clickedCount: Int,
        unsubscribedCount: Int,
        uniqueOpens: Int,
        uniqueClicks: Int,
        openRate: Double,
        clickRate: Double,
        unsubscribeRate: Double
    ) {
        self.newsletterId = newsletterId
        self.sentCount = sentCount
        self.openedCount = openedCount
        self.clickedCount = clickedCount
        self.unsubscribedCount = unsubscribedCount
        self.uniqueOpens = uniqueOpens
        self.uniqueClicks = uniqueClicks
        self.openRate = openRate
        self.clickRate = clickRate
        self.unsubscribeRate = unsubscribeRate
    }
}

public struct NewsletterTypeAnalytics: Sendable {
    public let type: String
    public let newsletterCount: Int
    public let totalSent: Int
    public let totalOpened: Int
    public let totalClicked: Int
    public let averageOpenRate: Double
    public let averageClickRate: Double

    public init(
        type: String,
        newsletterCount: Int,
        totalSent: Int,
        totalOpened: Int,
        totalClicked: Int,
        averageOpenRate: Double,
        averageClickRate: Double
    ) {
        self.type = type
        self.newsletterCount = newsletterCount
        self.totalSent = totalSent
        self.totalOpened = totalOpened
        self.totalClicked = totalClicked
        self.averageOpenRate = averageOpenRate
        self.averageClickRate = averageClickRate
    }
}

public struct OverallNewsletterAnalytics: Sendable {
    public let typeAnalytics: [String: NewsletterTypeAnalytics]

    public init(typeAnalytics: [String: NewsletterTypeAnalytics]) {
        self.typeAnalytics = typeAnalytics
    }
}

public struct NewsletterAnalyticsEvent: Sendable {
    public let id: UUID
    public let newsletterId: UUID
    public let userId: UUID?
    public let eventType: NewsletterEventType
    public let eventData: [String: String]
    public let createdAt: Date
    public let subjectLine: String
    public let newsletterType: String

    public init(
        id: UUID,
        newsletterId: UUID,
        userId: UUID?,
        eventType: NewsletterEventType,
        eventData: [String: String],
        createdAt: Date,
        subjectLine: String,
        newsletterType: String
    ) {
        self.id = id
        self.newsletterId = newsletterId
        self.userId = userId
        self.eventType = eventType
        self.eventData = eventData
        self.createdAt = createdAt
        self.subjectLine = subjectLine
        self.newsletterType = newsletterType
    }
}

public enum NewsletterAnalyticsError: Error, LocalizedError {
    case databaseError
    case invalidEventData
    case newsletterNotFound

    public var errorDescription: String? {
        switch self {
        case .databaseError:
            return "Database error occurred"
        case .invalidEventData:
            return "Invalid event data"
        case .newsletterNotFound:
            return "Newsletter not found"
        }
    }
}
