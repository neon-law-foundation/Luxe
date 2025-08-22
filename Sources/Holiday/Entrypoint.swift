import ArgumentParser
import Foundation

/// The main Holiday command-line tool for toggling between static holiday pages and active ECS services.
///
/// ## Overview
/// Holiday provides a cost-effective way to switch your infrastructure between active and maintenance modes.
/// During holidays or planned downtime, you can serve static pages from S3 instead of running ECS services.
///
/// ## Usage
/// ```bash
/// swift run Holiday vacation  # Enable holiday mode
/// swift run Holiday work      # Return to normal operations
/// ```
@main
struct Holiday: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "Holiday",
        abstract: "Toggle between static holiday pages and ECS services",
        subcommands: [Vacation.self, Work.self, Verify.self, VerifyMode.self]
    )
}

/// Enables holiday mode by uploading static pages and stopping ECS services.
///
/// ## Overview
/// The vacation command performs the following operations:
/// 1. Uploads static holiday pages to S3
/// 2. Updates ALB listener rules to redirect traffic to S3
/// 3. Stops all configured ECS services to save costs
///
/// ## Idempotency
/// Running this command multiple times is safe. If already in vacation mode,
/// it will display "🏖️ You're already on vacation, silly! 🌴"
struct Vacation: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Enable holiday mode: upload static pages and stop ECS services"
    )

    /// Executes the vacation mode workflow.
    ///
    /// - Throws: AWS service errors if operations fail
    func run() async throws {
        print("🏖️ Enabling holiday mode...")

        let command = HolidayCommand()
        command.mode = .vacation

        try await command.execute()

        print("✅ Holiday mode enabled! Static pages are now serving.")
        print("📧 Customers can contact support@sagebrush.services if needed.")
        print("🔇 Console logs and services are offline during vacation mode.")
    }
}

/// Disables holiday mode by starting ECS services and restoring normal routing.
///
/// ## Overview
/// The work command performs the following operations:
/// 1. Starts all configured ECS services
/// 2. Waits for services to become healthy (30 seconds)
/// 3. Updates ALB listener rules to route traffic back to ECS
///
/// ## Idempotency
/// Running this command multiple times is safe. If already in work mode,
/// it will display "💼 You're already working, silly! 💻"
struct Work: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Disable holiday mode: start ECS services and restore normal routing"
    )

    /// Executes the work mode workflow.
    ///
    /// - Throws: AWS service errors if operations fail
    func run() async throws {
        print("💼 Returning to work mode...")

        let command = HolidayCommand()
        command.mode = .work

        try await command.execute()

        print("✅ Work mode enabled! ECS services are now running.")
    }
}

/// Verifies that holiday pages are correctly uploaded to S3.
///
/// ## Overview
/// The verify command checks:
/// - All holiday pages exist in the S3 bucket
/// - File sizes are correct
/// - Provides accessible URLs for each page
///
/// ## Usage
/// This is useful for confirming the vacation mode setup completed successfully.
struct Verify: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Verify that holiday pages are uploaded to S3"
    )

    /// Executes the S3 verification workflow.
    ///
    /// - Throws: AWS S3 errors if verification fails
    func run() async throws {
        print("🔍 Verifying holiday pages in S3...")

        let awsConfig = AWSClientConfiguration(bucketName: "sagebrush-public")
        let s3Operations = S3Operations(config: awsConfig)

        try await s3Operations.verifyUploads()
    }
}

/// Verifies that ECS services are in the expected state for Holiday mode.
///
/// ## Overview
/// The verify-mode command checks:
/// - ECS services are in correct state (running for work mode, stopped for vacation mode)
/// - Times out after 5 minutes and exits with status 1 if verification fails
/// - Uses SOTO to directly query AWS ECS for accurate service states
///
/// ## Usage
/// ```bash
/// swift run Holiday verify-mode work      # Verify services are running
/// swift run Holiday verify-mode vacation  # Verify services are stopped
/// ```
struct VerifyMode: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "verify-mode",
        abstract:
            "Verify ECS services are in expected state (exits with status 1 if verification fails within 5 minutes)"
    )

    @Argument(help: "Mode to verify: 'work' (services running) or 'vacation' (services stopped)")
    var mode: String

    /// Executes the ECS service state verification with 5-minute timeout.
    ///
    /// - Throws: Verification errors or timeout
    func run() async throws {
        guard mode == "work" || mode == "vacation" else {
            print("❌ Invalid mode: \(mode). Use 'work' or 'vacation'")
            Foundation.exit(1)
        }

        print("🔍 Verifying ECS services are in \(mode) mode...")
        print("⏱️ Will timeout after 5 minutes if verification fails")

        let command = HolidayCommand()
        let ecsOperations = ECSOperations(clusterPrefix: "")
        let config = HolidayConfiguration()

        let timeout: TimeInterval = 300  // 5 minutes
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            let elapsed = Int(Date().timeIntervalSince(startTime))
            print("⏳ Checking service states... (\(elapsed)s elapsed)")

            do {
                let verificationPassed: Bool

                if mode == "vacation" {
                    verificationPassed = try await ecsOperations.areServicesStopped(
                        config.ecsServices,
                        using: command.awsClient,
                        in: command.region
                    )
                    if verificationPassed {
                        print("✅ VERIFICATION SUCCESSFUL: All ECS services are stopped (vacation mode)")
                        Foundation.exit(0)
                    } else {
                        print("❌ Services still running, retrying...")
                    }
                } else {  // work mode
                    verificationPassed = try await ecsOperations.areServicesRunning(
                        config.ecsServices,
                        using: command.awsClient,
                        in: command.region
                    )
                    if verificationPassed {
                        print("✅ VERIFICATION SUCCESSFUL: ECS services are running (work mode)")
                        Foundation.exit(0)
                    } else {
                        print("❌ Services not running, retrying...")
                    }
                }

                // Wait 10 seconds before retrying
                try await Task.sleep(nanoseconds: 10 * 1_000_000_000)

            } catch {
                print("⚠️ Error checking service states: \(error)")
                // Continue retrying on errors
            }
        }

        print("❌ TIMEOUT: Holiday mode verification FAILED for \(mode) mode after 5 minutes")
        Foundation.exit(1)
    }
}
