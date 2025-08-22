import Foundation
import Logging
import Queues
import Vapor

// This file previously contained BazaarJob-based email jobs
// These have been consolidated into SimpleEmailJob for better compatibility

/// Extension to Application for email job dispatching
extension Application {
    /// Send a simple email via job queue
    public func sendEmailViaQueue(
        to: String,
        subject: String,
        body: String,
        isHTML: Bool = false,
        textBody: String? = nil,
        queue: QueueName = .default
    ) async throws {
        try await jobDispatcher.dispatchEmail(
            to: to,
            subject: subject,
            body: body,
            isHTML: isHTML,
            textBody: textBody,
            queue: queue
        )
    }
}
