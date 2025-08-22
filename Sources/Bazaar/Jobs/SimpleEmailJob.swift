import Fluent
import Foundation
import Logging
import NIOCore
import Queues
import Vapor

/// Simple email job that directly implements Vapor's Job protocol
public struct SimpleEmailJob: Job {
    public typealias Payload = EmailPayload

    public struct EmailPayload: Codable, Sendable {
        public let to: String
        public let subject: String
        public let body: String
        public let isHTML: Bool
        public let textBody: String?

        public init(
            to: String,
            subject: String,
            body: String,
            isHTML: Bool = false,
            textBody: String? = nil
        ) {
            self.to = to
            self.subject = subject
            self.body = body
            self.isHTML = isHTML
            self.textBody = textBody
        }
    }

    /// Execute the job using Vapor's Job interface
    public func dequeue(_ context: QueueContext, _ payload: EmailPayload) -> EventLoopFuture<Void> {
        let promise = context.eventLoop.makePromise(of: Void.self)

        Task {
            do {
                context.logger.info(
                    "📧 Sending email",
                    metadata: [
                        "to": .string(payload.to),
                        "subject": .string(payload.subject),
                        "is_html": .stringConvertible(payload.isHTML),
                    ]
                )

                // Get the email service from the application storage
                guard let emailService = context.application.storage[EmailServiceKey.self] else {
                    throw SimpleEmailJobError.serviceNotFound("EmailService not configured")
                }

                // Send the email
                if payload.isHTML && payload.textBody != nil {
                    try await emailService.sendEmail(
                        to: payload.to,
                        subject: payload.subject,
                        htmlBody: payload.body,
                        textBody: payload.textBody!
                    )
                } else {
                    try await emailService.sendEmail(
                        to: payload.to,
                        subject: payload.subject,
                        body: payload.body
                    )
                }

                context.logger.info(
                    "✅ Email sent successfully",
                    metadata: ["to": .string(payload.to)]
                )

                promise.succeed()
            } catch {
                context.logger.error(
                    "❌ Failed to send email",
                    metadata: [
                        "to": .string(payload.to),
                        "error": .string(error.localizedDescription),
                    ]
                )
                promise.fail(error)
            }
        }

        return promise.futureResult
    }

    /// Handle job execution errors
    public func error(_ context: QueueContext, _ error: any Error, _ payload: EmailPayload) -> EventLoopFuture<Void> {
        context.logger.error(
            "❌ Email job failed",
            metadata: [
                "error": .string(error.localizedDescription),
                "to": .string(payload.to),
                "subject": .string(payload.subject),
            ]
        )

        return context.eventLoop.makeSucceededFuture(())
    }

    /// Configure retry logic for failed email jobs
    public func nextRetryIn(attempt: Int) -> Int {
        // Exponential backoff: 30s, 2m, 8m, 32m
        let delays = [30, 120, 480, 1920]
        let index = min(attempt - 1, delays.count - 1)
        return delays[index]
    }
}

/// Errors specific to simple email jobs
public enum SimpleEmailJobError: Error, LocalizedError {
    case serviceNotFound(String)
    case sendFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .serviceNotFound(let message):
            return "Service not found: \(message)"
        case .sendFailed(let error):
            return "Email send failed: \(error.localizedDescription)"
        }
    }
}

/// Convenience extensions for dispatching email jobs
extension Application {
    /// Send an email using the job queue
    /// - Parameters:
    ///   - to: Recipient email address
    ///   - subject: Email subject
    ///   - body: Email body content
    ///   - isHTML: Whether body is HTML
    ///   - textBody: Optional plain text version
    ///   - queue: Queue name (default: .default)
    public func sendEmailJob(
        to: String,
        subject: String,
        body: String,
        isHTML: Bool = false,
        textBody: String? = nil,
        queue: QueueName = .default
    ) async throws {
        let payload = SimpleEmailJob.EmailPayload(
            to: to,
            subject: subject,
            body: body,
            isHTML: isHTML,
            textBody: textBody
        )

        try await self.queues.queue(queue).dispatch(SimpleEmailJob.self, payload)
    }
}
