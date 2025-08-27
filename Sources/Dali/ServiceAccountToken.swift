import Fluent
import Foundation
import Vapor

/// Service type enumeration for categorizing service accounts
public enum ServiceType: String, Codable, CaseIterable, Sendable {
    case slackBot = "slack_bot"
    case cicd = "ci_cd"
    case monitoring = "monitoring"

    public var displayName: String {
        switch self {
        case .slackBot: return "Slack Bot"
        case .cicd: return "CI/CD"
        case .monitoring: return "Monitoring"
        }
    }
}

/// Model representing authentication tokens for service accounts and bots
///
/// This model stores hashed tokens for authenticating automated services without OAuth flows.
/// Tokens are stored as SHA256 hashes for security and support expiration dates.
///
/// ## Usage
///
/// ```swift
/// let token = ServiceAccountToken(
///     name: "slack-pitboss-bot",
///     tokenHash: "sha256-hash-of-token",
///     serviceType: .slackBot
/// )
/// try await token.save(on: db)
/// ```
public final class ServiceAccountToken: Model, Content, @unchecked Sendable {
    public static let schema = "service_account_tokens"
    public static let space = "auth"

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "name")
    public var name: String

    @Field(key: "token_hash")
    public var tokenHash: String

    @Field(key: "service_type")
    public var serviceType: ServiceType

    @OptionalField(key: "expires_at")
    public var expiresAt: Date?

    @Field(key: "is_active")
    public var isActive: Bool

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @OptionalField(key: "last_used_at")
    public var lastUsedAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        name: String,
        tokenHash: String,
        serviceType: ServiceType,
        expiresAt: Date? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.tokenHash = tokenHash
        self.serviceType = serviceType
        self.expiresAt = expiresAt
        self.isActive = isActive
    }

    public func validate() throws {
        guard !name.isEmpty else {
            throw ValidationError("Service account name cannot be empty")
        }

        guard name.count >= 3 else {
            throw ValidationError("Service account name must be at least 3 characters long")
        }

        guard name.count <= 255 else {
            throw ValidationError("Service account name cannot be longer than 255 characters")
        }

        guard !tokenHash.isEmpty else {
            throw ValidationError("Token hash cannot be empty")
        }

        guard tokenHash.count == 64 else {
            throw ValidationError("Token hash must be exactly 64 characters (SHA256)")
        }

        // Validate service type
        guard ServiceType.allCases.contains(serviceType) else {
            throw ValidationError("Invalid service type")
        }

        // Validate expiration date if provided
        if let expiresAt = expiresAt {
            guard expiresAt > Date() else {
                throw ValidationError("Expiration date must be in the future")
            }
        }
    }

    // MARK: - Token validation helpers

    /// Check if the token is currently valid (active and not expired)
    public func isValid() -> Bool {
        guard isActive else { return false }

        if let expiresAt = expiresAt {
            return expiresAt > Date()
        }

        return true
    }

    /// Check if the token has expired
    public func isExpired() -> Bool {
        guard let expiresAt = expiresAt else { return false }
        return expiresAt <= Date()
    }

    /// Update the last used timestamp
    public func updateLastUsed() {
        lastUsedAt = Date()
    }

    /// Deactivate the token
    public func deactivate() {
        isActive = false
    }

    /// Reactivate the token (if not expired)
    public func reactivate() throws {
        if isExpired() {
            throw ValidationError("Cannot reactivate expired token")
        }
        isActive = true
    }

    // MARK: - Service type helpers

    /// Check if this token is for Slack bot services
    public func isSlackBot() -> Bool {
        serviceType == .slackBot
    }

    /// Check if this token is for CI/CD services
    public func isCICD() -> Bool {
        serviceType == .cicd
    }

    /// Check if this token is for monitoring services
    public func isMonitoring() -> Bool {
        serviceType == .monitoring
    }

    // MARK: - Query helpers

    /// Find active tokens by service type
    public static func findActiveTokens(
        for serviceType: ServiceType,
        on database: Database
    ) async throws -> [ServiceAccountToken] {
        try await ServiceAccountToken.query(on: database)
            .filter(\.$serviceType == serviceType)
            .filter(\.$isActive == true)
            .all()
    }

    /// Find token by hash
    public static func findByTokenHash(
        _ tokenHash: String,
        on database: Database
    ) async throws -> ServiceAccountToken? {
        try await ServiceAccountToken.query(on: database)
            .filter(\.$tokenHash == tokenHash)
            .filter(\.$isActive == true)
            .first()
    }

    /// Find unexpired tokens
    public static func findUnexpiredTokens(
        on database: Database
    ) async throws -> [ServiceAccountToken] {
        let now = Date()
        return try await ServiceAccountToken.query(on: database)
            .group(.or) { or in
                or.filter(\.$expiresAt > now)
                or.filter(\.$expiresAt == nil)
            }
            .filter(\.$isActive == true)
            .all()
    }
}
