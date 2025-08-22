import Bouncer
import Dali
import Fluent
import Foundation
import Vapor

/// Middleware that checks for session authentication on all routes (not just protected ones)
/// and sets CurrentUserContext.user if a valid session exists.
/// This allows public pages to show authentication state in navigation.
public struct SessionMiddleware: AsyncMiddleware {

    public init() {}

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Check for session cookie
        if let sessionId = request.cookies["luxe-session"]?.string,
            let accessToken = request.application.storage[SessionStorageKey.self]?[sessionId]
        {

            // Extract username from token (matches ALBAuthMiddleware logic)
            let username: String
            if accessToken.hasPrefix("shicholas:") {
                username = "admin@neonlaw.com"
            } else if accessToken.hasPrefix("admin@neonlaw.com:") {
                username = "admin@neonlaw.com"
            } else {
                // Invalid token format, continue without setting user
                return try await next.respond(to: request)
            }

            // Find user in database
            do {
                let user = try await User.query(on: request.db)
                    .filter(\.$username == username)
                    .with(\.$person)
                    .first()

                if let user = user {
                    // Set the user in the task-local context for this request
                    return try await CurrentUserContext.$user.withValue(user) {
                        try await next.respond(to: request)
                    }
                }
            } catch {
                // Database error, continue without setting user
                // (don't fail the request for authentication check issues)
            }
        }

        // No valid session found, continue without setting user
        return try await next.respond(to: request)
    }
}
