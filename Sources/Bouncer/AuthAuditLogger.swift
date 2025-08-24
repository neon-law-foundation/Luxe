import Foundation
import Logging
import Vapor

/// Structured authentication audit logging service
struct AuthAuditLogger {
    let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    /// Logs successful authentication events with comprehensive context
    func logAuthentication(
        userId: UUID?,
        cognitoSub: String,
        cognitoGroups: [String],
        requestPath: String,
        userAgent: String?,
        sourceIP: String?,
        albHeaders: [String: String] = [:]
    ) {
        logger.info(
            "AUTH_AUDIT",
            metadata: [
                "event": "auth_success",
                "timestamp": .string(ISO8601DateFormatter().string(from: Date())),
                "user_id": .string(userId?.uuidString ?? "unknown"),
                "cognito_sub": .string(cognitoSub),
                "cognito_groups": .array(cognitoGroups.map { .string($0) }),
                "request_path": .string(requestPath),
                "user_agent": .string(userAgent ?? "unknown"),
                "source_ip": .string(sourceIP ?? "unknown"),
                "alb_headers_count": .string(String(albHeaders.count)),
            ]
        )
    }

    /// Logs authentication failure events with diagnostic information
    func logAuthenticationFailure(
        reason: String,
        requestPath: String,
        userAgent: String?,
        sourceIP: String?
    ) {
        logger.warning(
            "AUTH_AUDIT_FAILURE",
            metadata: [
                "event": "auth_failure",
                "timestamp": .string(ISO8601DateFormatter().string(from: Date())),
                "reason": .string(reason),
                "request_path": .string(requestPath),
                "user_agent": .string(userAgent ?? "unknown"),
                "source_ip": .string(sourceIP ?? "unknown"),
            ]
        )
    }

    /// Logs authorization failure events when user lacks required permissions
    func logAuthorizationFailure(
        userId: UUID?,
        cognitoSub: String?,
        requiredRole: String,
        userRoles: [String],
        requestPath: String
    ) {
        logger.warning(
            "AUTH_AUDIT_AUTHZ_FAILURE",
            metadata: [
                "event": "authz_failure",
                "timestamp": .string(ISO8601DateFormatter().string(from: Date())),
                "user_id": .string(userId?.uuidString ?? "unknown"),
                "cognito_sub": .string(cognitoSub ?? "unknown"),
                "required_role": .string(requiredRole),
                "user_roles": .array(userRoles.map { .string($0) }),
                "request_path": .string(requestPath),
            ]
        )
    }

    /// Logs session-related events during migration period
    func logSessionEvent(
        event: String,
        userId: UUID?,
        sessionId: String?,
        requestPath: String
    ) {
        logger.info(
            "AUTH_AUDIT_SESSION",
            metadata: [
                "event": .string("session_\(event)"),
                "timestamp": .string(ISO8601DateFormatter().string(from: Date())),
                "user_id": .string(userId?.uuidString ?? "unknown"),
                "session_id": .string(sessionId ?? "unknown"),
                "request_path": .string(requestPath),
            ]
        )
    }
}
