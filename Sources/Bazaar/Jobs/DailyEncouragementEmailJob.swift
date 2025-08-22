import Foundation
import Logging
import Queues
import Vapor

/// Daily encouragement email job that runs at 4:20 AM to send motivation
/// Sends from support@sagebrush.services to admin@neonlaw.com
public struct DailyEncouragementEmailJob: ScheduledJob {
    public let name: String = "daily_encouragement_email"

    public func run(context: QueueContext) -> EventLoopFuture<Void> {
        let promise = context.eventLoop.makePromise(of: Void.self)

        Task {
            do {
                context.logger.info("🌵 Starting daily encouragement email job")

                // Get the email service from the application storage
                guard let emailService = context.application.storage[EmailServiceKey.self] else {
                    throw EncouragementJobError.serviceNotFound("EmailService not configured")
                }

                let emailContent = createEncouragementEmailContent()

                // Send encouragement email
                try await emailService.sendEmail(
                    to: "admin@neonlaw.com",
                    subject: emailContent.subject,
                    htmlBody: emailContent.htmlBody,
                    textBody: emailContent.textBody
                )

                context.logger.info("✅ Daily encouragement email sent successfully")
                promise.succeed()
            } catch {
                context.logger.error(
                    "❌ Failed to send daily encouragement email",
                    metadata: ["error": .string(error.localizedDescription)]
                )
                promise.fail(error)
            }
        }

        return promise.futureResult
    }

    /// Create the encouragement email content with "Home Means Nevada" theme
    private func createEncouragementEmailContent() -> EmailContent {
        let currentDate = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")  // Nevada timezone
        let dateString = formatter.string(from: currentDate)

        let subject = "🌵 Home Means Nevada - Daily Encouragement (\(formatShortDate(currentDate)))"

        let htmlBody = EmailTemplate.html(
            title: "Home Means Nevada - Daily Encouragement",
            content: """
                <div style="text-align: center; margin: 20px 0;">
                    <h2 style="color: #2c5530;">🌵 Good Morning, Nevada Builder! 🌵</h2>
                    <p style="font-size: 18px; color: #4a4a4a; font-style: italic;">
                        "\(getRandomEncouragementMessage())"
                    </p>
                </div>

                <div style="background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%); padding: 25px; border-radius: 10px; margin: 20px 0;">
                    <h3 style="color: #2c5530; text-align: center; margin-bottom: 20px;">🏜️ Building in the Silver State</h3>
                    <p style="margin-bottom: 15px; line-height: 1.6;">
                        Today is <strong>\(dateString)</strong>, and you're building something amazing in Nevada -
                        the land of opportunity, business freedom, and endless possibilities.
                    </p>
                    <p style="margin-bottom: 15px; line-height: 1.6;">
                        Nevada's business-friendly environment isn't just about tax advantages - it's about the pioneering spirit
                        that built this state. From the silver mines to the bright lights of innovation, Nevada has always been
                        where dreamers come to build their future.
                    </p>
                    <p style="text-align: center; font-weight: bold; color: #2c5530; font-size: 16px;">
                        "Home means Nevada" - and you're helping to shape its future! 🚀
                    </p>
                </div>

                <div style="border-left: 4px solid #2c5530; padding-left: 20px; margin: 25px 0;">
                    <h4 style="color: #2c5530; margin-bottom: 15px;">💪 Your Daily Reminders</h4>
                    <ul style="list-style-type: none; padding-left: 0;">
                        <li style="margin-bottom: 10px;">🎯 <strong>Focus:</strong> Every great business started with someone who refused to give up</li>
                        <li style="margin-bottom: 10px;">🌱 <strong>Growth:</strong> Small consistent actions compound into extraordinary results</li>
                        <li style="margin-bottom: 10px;">🤝 <strong>Community:</strong> You're part of Nevada's entrepreneurial legacy</li>
                        <li style="margin-bottom: 10px;">⚡ <strong>Energy:</strong> Channel that Nevada spirit - bold, independent, and unstoppable</li>
                    </ul>
                </div>

                <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; text-align: center; margin: 25px 0;">
                    <h4 style="color: #2c5530; margin-bottom: 15px;">🏢 Sagebrush Services - Building Nevada Together</h4>
                    <p style="margin-bottom: 15px; color: #666;">
                        Just like the resilient sagebrush that thrives in Nevada's landscape, your business is built to endure and flourish.
                        Sagebrush Services is here to help you navigate the business landscape with the same rugged determination.
                    </p>
                    <p style="font-weight: bold; color: #2c5530;">
                        Keep building, keep growing, keep making Nevada proud! 🌵✨
                    </p>
                </div>
                """,
            footer: EmailTemplate.sagebrushFooter
        )

        let textBody = EmailTemplate.text(
            title: "🌵 Home Means Nevada - Daily Encouragement",
            content: """
                Good Morning, Nevada Builder!

                "\(getRandomEncouragementMessage())"

                BUILDING IN THE SILVER STATE
                ============================

                Today is \(dateString), and you're building something amazing in Nevada -
                the land of opportunity, business freedom, and endless possibilities.

                Nevada's business-friendly environment isn't just about tax advantages - it's about the pioneering spirit
                that built this state. From the silver mines to the bright lights of innovation, Nevada has always been
                where dreamers come to build their future.

                "Home means Nevada" - and you're helping to shape its future!

                YOUR DAILY REMINDERS
                ===================

                • Focus: Every great business started with someone who refused to give up
                • Growth: Small consistent actions compound into extraordinary results
                • Community: You're part of Nevada's entrepreneurial legacy
                • Energy: Channel that Nevada spirit - bold, independent, and unstoppable

                SAGEBRUSH SERVICES - BUILDING NEVADA TOGETHER
                ============================================

                Just like the resilient sagebrush that thrives in Nevada's landscape, your business is built to endure and flourish.
                Sagebrush Services is here to help you navigate the business landscape with the same rugged determination.

                Keep building, keep growing, keep making Nevada proud!
                """,
            footer: EmailTemplate.sagebrushFooter
        )

        return EmailContent(subject: subject, htmlBody: htmlBody, textBody: textBody)
    }

    /// Get a random encouragement message
    private func getRandomEncouragementMessage() -> String {
        let messages = [
            "The silver mines of Nevada were built by those who dared to dig deeper.",
            "In Nevada, we don't just survive the desert - we thrive in it.",
            "Every sunrise over the Sierra Nevada reminds us that new opportunities begin each day.",
            "The Battle Born state was forged in determination - so is your business.",
            "Like the sagebrush, the strongest businesses grow where others can't.",
            "Nevada chose statehood during the Civil War because it believes in doing the hard thing when it matters.",
            "The brightest lights in Nevada shine because someone refused to accept darkness.",
            "In the land of the midnight sun and endless sky, your dreams have room to grow.",
            "Nevada's motto: 'All for our country' - your success builds our shared prosperity.",
            "The Comstock Lode made Nevada famous, but your innovation makes it legendary.",
        ]

        return messages[Int.random(in: 0..<messages.count)]
    }

    /// Format date for email subject
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter.string(from: date)
    }
}

/// Email content structure for encouragement emails
private struct EmailContent {
    let subject: String
    let htmlBody: String
    let textBody: String
}

/// Errors specific to encouragement email job
public enum EncouragementJobError: Error, LocalizedError {
    case serviceNotFound(String)
    case emailSendFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .serviceNotFound(let message):
            return "Service not found: \(message)"
        case .emailSendFailed(let error):
            return "Failed to send encouragement email: \(error.localizedDescription)"
        }
    }
}

/// Extensions for registering the encouragement job
extension Application {
    /// Register the daily encouragement email job to run at 4:20 AM Pacific Time
    public func scheduleDailyEncouragementEmail() {
        let job = DailyEncouragementEmailJob()

        // Schedule to run daily at 4:20 AM Pacific Time
        queues.schedule(job)
            .daily()
            .at(4, 20)  // 4:20 AM

        logger.info("📅 Daily encouragement email job scheduled for 4:20 AM Pacific Time")
    }

    /// Manually trigger the daily encouragement email (for testing)
    public func triggerEncouragementEmail() async throws {
        logger.info("🧪 Manually triggering daily encouragement email for testing")

        guard storage[EmailServiceKey.self] != nil else {
            throw EncouragementJobError.serviceNotFound("EmailService not configured")
        }

        let job = DailyEncouragementEmailJob()
        let context = QueueContext(
            queueName: .default,
            configuration: queues.configuration,
            application: self,
            logger: logger,
            on: eventLoopGroup.next()
        )

        try await job.run(context: context).get()
        logger.info("✅ Manual encouragement email trigger completed")
    }
}
