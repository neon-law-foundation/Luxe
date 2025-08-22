import Dali
import Foundation

/// Provides thread-safe access to the currently authenticated user throughout the request lifecycle.
///
/// This enum uses Swift's `@TaskLocal` to store the authenticated user in a way that's scoped to the current
/// async task context. This ensures that each request has its own isolated user context without requiring
/// explicit parameter passing throughout the application.
///
/// ## Usage
///
/// Access the current user from anywhere within an authenticated request:
///
/// ```swift
/// if let user = CurrentUserContext.user {
///     print("Current user: \(user.username)")
/// }
/// ```
///
/// The middleware automatically sets this value when authentication succeeds, and it's automatically
/// cleaned up when the request completes.
public enum CurrentUserContext {
    /// The currently authenticated user for this request context.
    ///
    /// This property is automatically set by the OIDC middleware when authentication succeeds.
    /// It will be `nil` if the request is not authenticated or if accessed outside of an authenticated request context.
    ///
    /// - Note: This value is scoped to the current async task and is automatically cleaned up when the request completes.
    @TaskLocal
    public static var user: User?
}
