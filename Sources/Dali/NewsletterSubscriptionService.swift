import Fluent
import FluentPostgresDriver
import Foundation

/// Service for managing newsletter subscriptions
public struct NewsletterSubscriptionService {
    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    /// Get all newsletter subscribers with their subscription preferences
    public func getAllSubscribers() async throws -> [SubscriberInfo] {
        guard let postgresDB = database as? PostgresDatabase else {
            throw NewsletterSubscriptionError.databaseError
        }

        let result = try await postgresDB.sql()
            .raw(
                """
                SELECT
                    id,
                    email,
                    name,
                    subscribed_newsletters->>'sci_tech' as sci_tech,
                    subscribed_newsletters->>'sagebrush' as sagebrush,
                    subscribed_newsletters->>'neon_law' as neon_law,
                    created_at
                FROM auth.users
                WHERE subscribed_newsletters IS NOT NULL
                ORDER BY created_at DESC
                """
            )
            .all()

        return try result.compactMap { row in
            guard let id = try row.decode(column: "id", as: UUID?.self),
                let email = try row.decode(column: "email", as: String?.self)
            else {
                return nil
            }

            let name = try row.decode(column: "name", as: String?.self)
            let sciTech = try row.decode(column: "sci_tech", as: String?.self) == "true"
            let sagebrush = try row.decode(column: "sagebrush", as: String?.self) == "true"
            let neonLaw = try row.decode(column: "neon_law", as: String?.self) == "true"
            let createdAt = try row.decode(column: "created_at", as: Date?.self)

            return SubscriberInfo(
                id: id,
                email: email,
                name: name,
                isSubscribedToSciTech: sciTech,
                isSubscribedToSagebrush: sagebrush,
                isSubscribedToNeonLaw: neonLaw,
                createdAt: createdAt
            )
        }
    }

    /// Get subscribers for a specific newsletter type
    public func getSubscribers(for type: Newsletter.NewsletterName) async throws -> [SubscriberInfo] {
        let allSubscribers = try await getAllSubscribers()

        return allSubscribers.filter { subscriber in
            switch type {
            case .nvSciTech:
                return subscriber.isSubscribedToSciTech
            case .sagebrush:
                return subscriber.isSubscribedToSagebrush
            case .neonLaw:
                return subscriber.isSubscribedToNeonLaw
            }
        }
    }

    /// Update subscription preferences for a user
    public func updateSubscriptions(
        userId: UUID,
        sciTech: Bool? = nil,
        sagebrush: Bool? = nil,
        neonLaw: Bool? = nil
    ) async throws {
        guard let postgresDB = database as? PostgresDatabase else {
            throw NewsletterSubscriptionError.databaseError
        }

        // Get current subscriptions
        let currentResult = try await postgresDB.sql()
            .raw("SELECT subscribed_newsletters FROM auth.users WHERE id = \(bind: userId)")
            .first()

        guard let currentRow = currentResult else {
            throw NewsletterSubscriptionError.userNotFound
        }

        // Parse current subscriptions or create empty object
        var subscriptions: [String: Bool] = [:]

        if let currentSubscriptionsData = try currentRow.decode(column: "subscribed_newsletters", as: Data?.self) {
            subscriptions = try JSONDecoder().decode([String: Bool].self, from: currentSubscriptionsData)
        }

        // Update requested subscriptions
        if let sciTech = sciTech {
            subscriptions["sci_tech"] = sciTech
        }
        if let sagebrush = sagebrush {
            subscriptions["sagebrush"] = sagebrush
        }
        if let neonLaw = neonLaw {
            subscriptions["neon_law"] = neonLaw
        }

        // Encode and update
        let updatedData = try JSONEncoder().encode(subscriptions)
        let jsonString = String(data: updatedData, encoding: .utf8) ?? "{}"

        _ = try await postgresDB.sql()
            .raw("UPDATE auth.users SET subscribed_newsletters = \(bind: jsonString) WHERE id = \(bind: userId)")
            .run()
    }

    /// Remove all subscriptions for a user
    public func removeAllSubscriptions(userId: UUID) async throws {
        try await updateSubscriptions(
            userId: userId,
            sciTech: false,
            sagebrush: false,
            neonLaw: false
        )
    }

    /// Export subscribers to CSV format
    public func exportSubscribersCSV(type: Newsletter.NewsletterName? = nil) async throws -> String {
        let subscribers: [SubscriberInfo]

        if let type = type {
            subscribers = try await getSubscribers(for: type)
        } else {
            subscribers = try await getAllSubscribers()
        }

        var csv = "Email,Name,Sci Tech,Sagebrush,Neon Law,Joined Date\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        for subscriber in subscribers {
            let name = subscriber.name?.replacingOccurrences(of: ",", with: ";") ?? ""
            let joinedDate = subscriber.createdAt.map(dateFormatter.string) ?? ""
            let sciTech = subscriber.isSubscribedToSciTech ? "Yes" : "No"
            let sagebrush = subscriber.isSubscribedToSagebrush ? "Yes" : "No"
            let neonLaw = subscriber.isSubscribedToNeonLaw ? "Yes" : "No"

            csv += "\(subscriber.email),\(name),\(sciTech),\(sagebrush),\(neonLaw),\(joinedDate)\n"
        }

        return csv
    }

    /// Get subscription statistics
    public func getSubscriptionStats() async throws -> SubscriptionStats {
        let allSubscribers = try await getAllSubscribers()

        let sciTechCount = allSubscribers.filter(\.isSubscribedToSciTech).count
        let sagebrushCount = allSubscribers.filter(\.isSubscribedToSagebrush).count
        let neonLawCount = allSubscribers.filter(\.isSubscribedToNeonLaw).count

        return SubscriptionStats(
            totalSubscribers: allSubscribers.count,
            sciTechSubscribers: sciTechCount,
            sagebrushSubscribers: sagebrushCount,
            neonLawSubscribers: neonLawCount
        )
    }

    /// Get subscription preferences for a specific user
    public func getUserSubscriptionPreferences(userId: UUID) async throws -> UserSubscriptionPreferences {
        guard let postgresDB = database as? PostgresDatabase else {
            throw NewsletterSubscriptionError.databaseError
        }

        let result = try await postgresDB.sql()
            .raw(
                """
                SELECT
                    subscribed_newsletters->>'sci_tech' as sci_tech,
                    subscribed_newsletters->>'sagebrush' as sagebrush,
                    subscribed_newsletters->>'neon_law' as neon_law
                FROM auth.users
                WHERE id = \(bind: userId)
                """
            )
            .first()

        guard let row = result else {
            throw NewsletterSubscriptionError.userNotFound
        }

        let sciTech = try row.decode(column: "sci_tech", as: String?.self) == "true"
        let sagebrush = try row.decode(column: "sagebrush", as: String?.self) == "true"
        let neonLaw = try row.decode(column: "neon_law", as: String?.self) == "true"

        return UserSubscriptionPreferences(
            userId: userId,
            isSubscribedToSciTech: sciTech,
            isSubscribedToSagebrush: sagebrush,
            isSubscribedToNeonLaw: neonLaw
        )
    }
}

// MARK: - Supporting Types

public struct SubscriberInfo: Sendable, Identifiable {
    public let id: UUID
    public let email: String
    public let name: String?
    public let isSubscribedToSciTech: Bool
    public let isSubscribedToSagebrush: Bool
    public let isSubscribedToNeonLaw: Bool
    public let createdAt: Date?

    public init(
        id: UUID,
        email: String,
        name: String?,
        isSubscribedToSciTech: Bool,
        isSubscribedToSagebrush: Bool,
        isSubscribedToNeonLaw: Bool,
        createdAt: Date?
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.isSubscribedToSciTech = isSubscribedToSciTech
        self.isSubscribedToSagebrush = isSubscribedToSagebrush
        self.isSubscribedToNeonLaw = isSubscribedToNeonLaw
        self.createdAt = createdAt
    }
}

public struct SubscriptionStats: Sendable {
    public let totalSubscribers: Int
    public let sciTechSubscribers: Int
    public let sagebrushSubscribers: Int
    public let neonLawSubscribers: Int

    public init(
        totalSubscribers: Int,
        sciTechSubscribers: Int,
        sagebrushSubscribers: Int,
        neonLawSubscribers: Int
    ) {
        self.totalSubscribers = totalSubscribers
        self.sciTechSubscribers = sciTechSubscribers
        self.sagebrushSubscribers = sagebrushSubscribers
        self.neonLawSubscribers = neonLawSubscribers
    }
}

public struct UserSubscriptionPreferences: Sendable {
    public let userId: UUID
    public let isSubscribedToSciTech: Bool
    public let isSubscribedToSagebrush: Bool
    public let isSubscribedToNeonLaw: Bool

    public init(
        userId: UUID,
        isSubscribedToSciTech: Bool,
        isSubscribedToSagebrush: Bool,
        isSubscribedToNeonLaw: Bool
    ) {
        self.userId = userId
        self.isSubscribedToSciTech = isSubscribedToSciTech
        self.isSubscribedToSagebrush = isSubscribedToSagebrush
        self.isSubscribedToNeonLaw = isSubscribedToNeonLaw
    }
}

public enum NewsletterSubscriptionError: Error, LocalizedError {
    case databaseError
    case userNotFound
    case invalidSubscriptionData

    public var errorDescription: String? {
        switch self {
        case .databaseError:
            return "Database error occurred"
        case .userNotFound:
            return "User not found"
        case .invalidSubscriptionData:
            return "Invalid subscription data"
        }
    }
}
