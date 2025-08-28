import Fluent
import Foundation
import Vapor

// MARK: - Metrics DTOs

/// User metrics aggregation data
public struct UserMetrics: Content, Sendable {
    public let totalUsers: Int
    public let activeUsers: Int
    public let usersByRole: [String: Int]
    public let newUsersThisWeek: Int
    public let newUsersThisMonth: Int

    public init(
        totalUsers: Int,
        activeUsers: Int,
        usersByRole: [String: Int],
        newUsersThisWeek: Int,
        newUsersThisMonth: Int
    ) {
        self.totalUsers = totalUsers
        self.activeUsers = activeUsers
        self.usersByRole = usersByRole
        self.newUsersThisWeek = newUsersThisWeek
        self.newUsersThisMonth = newUsersThisMonth
    }
}

/// Entity metrics aggregation data
public struct EntityMetrics: Content, Sendable {
    public let totalEntities: Int
    public let entitiesByType: [String: Int]
    public let newEntitiesThisWeek: Int
    public let newEntitiesThisMonth: Int

    public init(
        totalEntities: Int,
        entitiesByType: [String: Int],
        newEntitiesThisWeek: Int,
        newEntitiesThisMonth: Int
    ) {
        self.totalEntities = totalEntities
        self.entitiesByType = entitiesByType
        self.newEntitiesThisWeek = newEntitiesThisWeek
        self.newEntitiesThisMonth = newEntitiesThisMonth
    }
}

/// System health metrics
public struct SystemHealthMetrics: Content, Sendable {
    public let databaseConnections: Int
    public let memoryUsage: Double
    public let uptime: TimeInterval

    public init(databaseConnections: Int, memoryUsage: Double, uptime: TimeInterval) {
        self.databaseConnections = databaseConnections
        self.memoryUsage = memoryUsage
        self.uptime = uptime
    }
}

// MARK: - MetricsService Protocol

/// Protocol for collecting and aggregating system metrics
///
/// This service provides various metrics for monitoring and reporting purposes,
/// particularly for Slack bot integration and administrative dashboards.
public protocol MetricsService: Sendable {

    /// Get comprehensive user metrics including counts by role and recent registrations
    /// - Returns: UserMetrics containing user statistics
    /// - Throws: Database or calculation errors
    func getUserMetrics() async throws -> UserMetrics

    /// Get entity metrics including counts by type and recent creations
    /// - Returns: EntityMetrics containing entity statistics
    /// - Throws: Database or calculation errors
    func getEntityMetrics() async throws -> EntityMetrics

    /// Get basic system health information
    /// - Returns: SystemHealthMetrics containing system status
    /// - Throws: System query errors
    func getSystemHealth() async throws -> SystemHealthMetrics
}

// MARK: - Default Implementation

/// Default implementation of MetricsService using Fluent database queries
///
/// This implementation provides efficient database queries for collecting metrics
/// across the application.
public struct DefaultMetricsService: MetricsService {

    private let database: Database
    private let logger: Logger

    public init(database: Database, logger: Logger) {
        self.database = database
        self.logger = logger
    }

    public func getUserMetrics() async throws -> UserMetrics {
        logger.info("Computing user metrics from database")

        // Get total user count
        let totalUsers = try await User.query(on: database).count()

        // Get active users (created in last 30 days)
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let activeUsers = try await User.query(on: database)
            .filter(\.$createdAt >= thirtyDaysAgo)
            .count()

        // Get users by role
        let allUsers = try await User.query(on: database).all()
        let usersByRoleEnum = Dictionary(grouping: allUsers, by: \.role)
        let usersByRole = usersByRoleEnum.mapValues { $0.count }
            .reduce(into: [String: Int]()) { result, pair in
                result[pair.key.displayName] = pair.value
            }

        // Get new users this week and month
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let monthAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)

        let newUsersThisWeek = try await User.query(on: database)
            .filter(\.$createdAt >= weekAgo)
            .count()

        let newUsersThisMonth = try await User.query(on: database)
            .filter(\.$createdAt >= monthAgo)
            .count()

        return UserMetrics(
            totalUsers: totalUsers,
            activeUsers: activeUsers,
            usersByRole: usersByRole,
            newUsersThisWeek: newUsersThisWeek,
            newUsersThisMonth: newUsersThisMonth
        )
    }

    public func getEntityMetrics() async throws -> EntityMetrics {
        logger.info("Computing entity metrics from database")

        // Get total entity count
        let totalEntities = try await Entity.query(on: database).count()

        // Get entities by type
        let entitiesWithTypes = try await Entity.query(on: database)
            .with(\.$legalEntityType)
            .all()

        let entitiesByType = Dictionary(grouping: entitiesWithTypes) { entity in
            entity.legalEntityType.name
        }.mapValues { $0.count }

        // Get new entities this week and month
        let weekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let monthAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)

        let newEntitiesThisWeek = try await Entity.query(on: database)
            .filter(\.$createdAt >= weekAgo)
            .count()

        let newEntitiesThisMonth = try await Entity.query(on: database)
            .filter(\.$createdAt >= monthAgo)
            .count()

        return EntityMetrics(
            totalEntities: totalEntities,
            entitiesByType: entitiesByType,
            newEntitiesThisWeek: newEntitiesThisWeek,
            newEntitiesThisMonth: newEntitiesThisMonth
        )
    }

    public func getSystemHealth() async throws -> SystemHealthMetrics {
        logger.info("Computing system health metrics")

        // Basic system health - in a real implementation this would query actual metrics
        return SystemHealthMetrics(
            databaseConnections: 1,  // Would query actual connection pool size
            memoryUsage: 0.0,  // Would get actual memory usage percentage
            uptime: ProcessInfo.processInfo.systemUptime
        )
    }
}
