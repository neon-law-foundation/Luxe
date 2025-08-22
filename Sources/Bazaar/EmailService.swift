import Foundation
import Logging
import SotoCore
import SotoSES
import Vapor

/// Configuration for the email service
public struct EmailConfiguration {
    /// AWS region for SES service
    public let region: Region

    /// Source email address for outgoing emails
    public let sourceEmail: String

    /// AWS credentials provider
    public let credentialProvider: CredentialProviderFactory

    /// Create email configuration for local development
    public static func local() -> EmailConfiguration {
        EmailConfiguration(
            region: .uswest2,
            sourceEmail: "support@sagebrush.services",
            credentialProvider: .static(
                accessKeyId: ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"] ?? "test",
                secretAccessKey: ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] ?? "test"
            )
        )
    }

    /// Create email configuration for production
    public static func production() -> EmailConfiguration {
        EmailConfiguration(
            region: .uswest2,
            sourceEmail: "support@sagebrush.services",
            credentialProvider: .default
        )
    }

    public init(region: Region, sourceEmail: String, credentialProvider: CredentialProviderFactory) {
        self.region = region
        self.sourceEmail = sourceEmail
        self.credentialProvider = credentialProvider
    }
}

/// Email service protocol for sending emails via AWS SES
public protocol EmailServiceProtocol: Sendable {
    /// Send an email
    /// - Parameters:
    ///   - to: Recipient email address
    ///   - subject: Email subject
    ///   - body: Email body content
    /// - Throws: EmailServiceError or AWS SES errors
    func sendEmail(to: String, subject: String, body: String) async throws

    /// Send an email with both HTML and text content
    /// - Parameters:
    ///   - to: Recipient email address
    ///   - subject: Email subject
    ///   - htmlBody: HTML content
    ///   - textBody: Plain text content
    /// - Throws: EmailServiceError or AWS SES errors
    func sendEmail(to: String, subject: String, htmlBody: String, textBody: String) async throws
}

/// AWS SES implementation of the email service
public actor EmailService: EmailServiceProtocol {
    private let ses: SES
    private let configuration: EmailConfiguration
    private let logger: Logger
    private let awsClient: AWSClient

    /// Initialize the email service
    /// - Parameters:
    ///   - configuration: Email service configuration
    ///   - logger: Logger instance
    public init(configuration: EmailConfiguration, logger: Logger) async throws {
        self.configuration = configuration
        self.logger = logger

        // For local development, we might want to use LocalStack
        let isLocalDevelopment = ProcessInfo.processInfo.environment["ENV"] != "PRODUCTION"

        if isLocalDevelopment {
            // Create AWS client for local development (could use LocalStack if configured)
            self.awsClient = AWSClient(
                credentialProvider: configuration.credentialProvider,
                logger: logger
            )
            logger.info("EmailService configured for local development")
        } else {
            // Create AWS client for production
            self.awsClient = AWSClient(
                credentialProvider: configuration.credentialProvider,
                logger: logger
            )
            logger.info("EmailService configured for production")
        }

        self.ses = SES(client: awsClient, region: configuration.region)
        logger.info(
            "✅ EmailService initialized",
            metadata: [
                "region": .string(configuration.region.rawValue),
                "source_email": .string(configuration.sourceEmail),
            ]
        )
    }

    /// Send a plain text email
    public func sendEmail(to: String, subject: String, body: String) async throws {
        try await _sendEmail(to: to, subject: subject, htmlBody: nil, textBody: body)
    }

    /// Send an email with both HTML and text content
    public func sendEmail(to: String, subject: String, htmlBody: String, textBody: String) async throws {
        try await _sendEmail(to: to, subject: subject, htmlBody: htmlBody, textBody: textBody)
    }

    /// Internal method to send email with optional HTML and text content
    private func _sendEmail(to: String, subject: String, htmlBody: String?, textBody: String?) async throws {
        logger.info(
            "Sending email",
            metadata: [
                "to": .string(to),
                "subject": .string(subject),
                "from": .string(configuration.sourceEmail),
            ]
        )

        // Create message content
        let htmlContent = htmlBody.map { SES.Content(data: $0) }
        let textContent = textBody.map { SES.Content(data: $0) }
        let body = SES.Body(html: htmlContent, text: textContent)

        // Create the message
        let message = SES.Message(
            body: body,
            subject: SES.Content(data: subject)
        )

        // Create destination
        let destination = SES.Destination(toAddresses: [to])

        // Create send request
        let request = SES.SendEmailRequest(
            destination: destination,
            message: message,
            source: configuration.sourceEmail
        )

        do {
            let response = try await ses.sendEmail(request)
            logger.info(
                "✅ Email sent successfully",
                metadata: [
                    "message_id": .string(response.messageId),
                    "to": .string(to),
                ]
            )
        } catch {
            logger.error(
                "❌ Failed to send email",
                metadata: [
                    "error": .string(error.localizedDescription),
                    "to": .string(to),
                ]
            )
            throw EmailServiceError.sendFailed(error)
        }
    }

    /// Cleanup resources
    public func shutdown() async throws {
        try await awsClient.shutdown()
        logger.info("EmailService shutdown completed")
    }
}

/// Email service specific errors
public enum EmailServiceError: Error, LocalizedError {
    case sendFailed(Error)
    case invalidConfiguration(String)
    case serviceUnavailable

    public var errorDescription: String? {
        switch self {
        case .sendFailed(let error):
            return "Failed to send email: \(error.localizedDescription)"
        case .invalidConfiguration(let message):
            return "Invalid email configuration: \(message)"
        case .serviceUnavailable:
            return "Email service is unavailable"
        }
    }
}

/// Storage key for email service in Vapor application
public struct EmailServiceKey: StorageKey {
    public typealias Value = EmailService
}

/// Email template utilities for formatting outbound messages
public struct EmailTemplate {
    /// Create a basic HTML email template
    /// - Parameters:
    ///   - title: Email title
    ///   - content: Main content body
    ///   - footer: Optional footer content
    /// - Returns: Formatted HTML email content
    public static func html(title: String, content: String, footer: String? = nil) -> String {
        let footerHTML =
            footer.map {
                "<div style=\"margin-top: 20px; padding-top: 20px; border-top: 1px solid #eee; color: #666; font-size: 12px;\">\($0)</div>"
            } ?? ""

        return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <title>\(title)</title>
                <style>
                    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; }
                    .header { background-color: #f8f9fa; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
                    .content { background-color: #ffffff; padding: 30px; border: 1px solid #e9ecef; }
                    .footer { background-color: #f8f9fa; padding: 15px; text-align: center; border-radius: 0 0 8px 8px; }
                    h1 { color: #2c3e50; margin-top: 0; }
                    a { color: #007bff; }
                </style>
            </head>
            <body>
                <div class="header">
                    <h1>\(title)</h1>
                </div>
                <div class="content">
                    \(content)
                </div>
                \(footerHTML.isEmpty ? "" : "<div class=\"footer\">\(footerHTML)</div>")
            </body>
            </html>
            """
    }

    /// Create a plain text email template
    /// - Parameters:
    ///   - title: Email title
    ///   - content: Main content body
    ///   - footer: Optional footer content
    /// - Returns: Formatted plain text email content
    public static func text(title: String, content: String, footer: String? = nil) -> String {
        var result = """
            \(title)
            \(String(repeating: "=", count: title.count))

            \(content)
            """

        if let footer = footer {
            result += "\n\n---\n\(footer)"
        }

        return result
    }

    /// Standard footer for Sagebrush Services emails
    public static let sagebrushFooter = """
        This email was sent from Sagebrush Services.
        If you have any questions, please contact support@sagebrush.services
        """
}
