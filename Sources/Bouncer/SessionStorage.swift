import Dali
import Fluent
import Foundation
import Vapor

/// Enhanced session storage that supports both OAuth and custom session tokens
///
/// This provides a unified session management system that can store:
/// - OAuth access tokens and refresh tokens
/// - User information
/// - Session metadata
///
/// ## Usage
///
/// ```swift
/// // Store OAuth session
/// app.sessionStorage.storeOAuthSession(
///     sessionId: sessionId,
///     accessToken: tokenResponse.access_token,
///     userId: user.id,
///     expiresIn: tokenResponse.expires_in
/// )
///
/// // Retrieve session
/// if let session = app.sessionStorage.getSession(sessionId) {
///     // Use session data
/// }
/// ```
public struct SessionStorage {
    /// Session data structure
    public struct SessionData: Codable, Sendable {
        public let sessionId: String
        public let userId: UUID
        public let accessToken: String
        public let refreshToken: String?
        public let idToken: String?
        public let createdAt: Date
        public let expiresAt: Date?
        public let metadata: [String: String]

        public init(
            sessionId: String,
            userId: UUID,
            accessToken: String,
            refreshToken: String? = nil,
            idToken: String? = nil,
            createdAt: Date = Date(),
            expiresAt: Date? = nil,
            metadata: [String: String] = [:]
        ) {
            self.sessionId = sessionId
            self.userId = userId
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.idToken = idToken
            self.createdAt = createdAt
            self.expiresAt = expiresAt
            self.metadata = metadata
        }

        /// Check if session is expired
        public var isExpired: Bool {
            guard let expiresAt = expiresAt else { return false }
            return Date() > expiresAt
        }
    }

    private let application: Application

    public init(application: Application) {
        self.application = application
    }

    /// Store OAuth session data
    public func storeOAuthSession(
        sessionId: String,
        userId: UUID,
        accessToken: String,
        refreshToken: String? = nil,
        idToken: String? = nil,
        expiresIn: Int? = nil
    ) {
        let expiresAt = expiresIn.map { Date().addingTimeInterval(TimeInterval($0)) }

        let sessionData = SessionData(
            sessionId: sessionId,
            userId: userId,
            accessToken: accessToken,
            refreshToken: refreshToken,
            idToken: idToken,
            expiresAt: expiresAt
        )

        // Store in application storage
        var sessions = application.storage[EnhancedSessionStorageKey.self] ?? [:]
        sessions[sessionId] = sessionData
        application.storage[EnhancedSessionStorageKey.self] = sessions

        application.logger.info("✅ Stored OAuth session for user: \(userId)")
    }

    /// Retrieve session data
    public func getSession(_ sessionId: String) -> SessionData? {
        guard let sessions = application.storage[EnhancedSessionStorageKey.self],
            let sessionData = sessions[sessionId]
        else {
            application.logger.debug("❌ Session not found: \(sessionId)")
            return nil
        }

        // Check if expired
        if sessionData.isExpired {
            application.logger.info("⏰ Session expired: \(sessionId)")
            removeSession(sessionId)
            return nil
        }

        return sessionData
    }

    /// Remove session
    public func removeSession(_ sessionId: String) {
        var sessions = application.storage[EnhancedSessionStorageKey.self] ?? [:]
        sessions.removeValue(forKey: sessionId)
        application.storage[EnhancedSessionStorageKey.self] = sessions

        application.logger.info("🗑️ Removed session: \(sessionId)")
    }

    /// Clean up expired sessions
    public func cleanupExpiredSessions() {
        guard var sessions = application.storage[EnhancedSessionStorageKey.self] else { return }

        let now = Date()
        var expiredCount = 0

        for (sessionId, sessionData) in sessions {
            if let expiresAt = sessionData.expiresAt, now > expiresAt {
                sessions.removeValue(forKey: sessionId)
                expiredCount += 1
            }
        }

        if expiredCount > 0 {
            application.storage[EnhancedSessionStorageKey.self] = sessions
            application.logger.info("🧹 Cleaned up \(expiredCount) expired sessions")
        }
    }
}

/// Storage key for enhanced session management
public struct EnhancedSessionStorageKey: StorageKey {
    public typealias Value = [String: SessionStorage.SessionData]
}

/// Application extension for session storage
extension Application {
    /// Access the session storage
    public var sessionStorage: SessionStorage {
        SessionStorage(application: self)
    }

    /// Initialize session storage
    public func initializeSessionStorage() {
        self.storage[EnhancedSessionStorageKey.self] = [:]
        self.logger.info("✅ Initialized session storage")
    }
}

/// Request extension for session management
extension Request {
    /// Get current session data from cookie
    public var sessionData: SessionStorage.SessionData? {
        guard let sessionId = self.cookies["luxe-session"]?.string else {
            return nil
        }
        return self.application.sessionStorage.getSession(sessionId)
    }

    /// Create new session cookie
    public func createSessionCookie(sessionId: String, maxAge: Int = 86400) {
        self.cookies["luxe-session"] = HTTPCookies.Value(
            string: sessionId,
            maxAge: maxAge,
            isHTTPOnly: true,
            sameSite: .lax
        )
    }

    /// Clear session cookie
    public func clearSessionCookie() {
        self.cookies["luxe-session"] = HTTPCookies.Value(
            string: "",
            maxAge: 0,
            isHTTPOnly: true,
            sameSite: .lax
        )
    }
}

/// Enhanced session middleware that uses the new session storage
public struct EnhancedSessionMiddleware: AsyncMiddleware {
    public init() {}

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Check for session data
        if let sessionData = request.sessionData {
            // Find user in database
            do {
                if let user = try await User.find(sessionData.userId, on: request.db) {
                    try await user.$person.load(on: request.db)

                    // Set current user context
                    return try await CurrentUserContext.$user.withValue(user) {
                        try await next.respond(to: request)
                    }
                }
            } catch {
                request.logger.error("Failed to load user for session: \(error)")
            }
        }

        // Continue without setting user
        return try await next.respond(to: request)
    }
}
