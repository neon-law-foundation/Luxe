import Foundation
import SotoCloudFormation
import SotoCore
import SotoECS
import SotoElasticLoadBalancingV2
import SotoS3

/// Represents the operational mode for the Holiday system.
public enum HolidayMode {
    /// Vacation mode: static pages served, ECS services stopped
    case vacation
    /// Work mode: ECS services running, normal operations
    case work
}

/// Core command executor for Holiday mode operations.
///
/// ## Overview
/// This class orchestrates the transition between vacation and work modes,
/// managing AWS resources including S3, ECS, and ALB configurations.
///
/// ## AWS Resources Managed
/// - **S3**: Static holiday pages in `sagebrush-public` bucket
/// - **ECS**: Service lifecycle management (start/stop)
/// - **ALB**: Listener rule updates for traffic routing
public class HolidayCommand {
    /// The current operational mode.
    public var mode: HolidayMode = .vacation

    /// AWS client for service interactions.
    public let awsClient: AWSClient

    /// AWS region for all operations.
    public let region = Region.uswest2

    /// Initializes a new Holiday command with AWS configuration.
    public init() {
        let config = AWSClientConfiguration()
        self.awsClient = config.client
    }

    deinit {
        try? awsClient.syncShutdown()
    }

    /// Executes the configured holiday mode operation.
    ///
    /// ## Behavior
    /// - **Vacation mode**: Uploads static pages, updates ALB rules, stops ECS services
    /// - **Work mode**: Starts ECS services, waits for health, restores ALB rules
    ///
    /// ## Idempotency
    /// Both modes are idempotent - running the same mode multiple times is safe
    /// and will display appropriate messages if already in the requested state.
    ///
    /// - Throws: AWS service errors if operations fail
    public func execute() async throws {
        switch mode {
        case .vacation:
            try await enableVacationMode()
        case .work:
            try await enableWorkMode()
        }
    }

    private func enableVacationMode() async throws {
        // Check if we're already in vacation mode
        let ecsOperations = ECSOperations(clusterPrefix: "")
        let config = HolidayConfiguration()

        let servicesStopped = try await ecsOperations.areServicesStopped(
            config.ecsServices,
            using: awsClient,
            in: region
        )

        if servicesStopped {
            print("🏖️ You're already on vacation, silly! 🌴")
            print("📋 All ECS services are already stopped.")
            print("🔇 Console logs and services are offline during vacation mode.")

            // Always regenerate and upload HTML files to ensure they're current
            let htmlGenerator = HolidayHTMLGenerator()
            let html = htmlGenerator.generateHTML()

            let s3Operations = S3Operations(config: AWSClientConfiguration(bucketName: "sagebrush-public"))
            try await s3Operations.uploadHolidayPages(html: html)

            // Also update ALB rules even if we're already in vacation mode
            print("🔄 Updating ALB rules to serve holiday pages...")
            let albOperations = ALBOperations()
            do {
                try await albOperations.updateListenerRulesForHoliday(using: awsClient, in: region)
            } catch {
                if error.localizedDescription.contains("ValidationError") {
                    print("📋 ALB configuration skipped (not configured for this environment)")
                } else {
                    print("⚠️ ALB configuration skipped: \(error)")
                }
                print("📋 Holiday pages are uploaded, but ALB rules may need manual configuration")
            }

            // Wait for expected vacation mode responses (301 redirects)
            await waitForExpectedHealthResponse(expectedMode: .vacation, timeout: 300)

            // Perform redirect checks even if already in vacation mode
            await performRedirectChecks()
            return
        }

        // 1. Generate and upload HTML files
        let htmlGenerator = HolidayHTMLGenerator()
        let html = htmlGenerator.generateHTML()

        let s3Operations = S3Operations(config: AWSClientConfiguration(bucketName: "sagebrush-public"))
        try await s3Operations.uploadHolidayPages(html: html)

        // 2. Update ALB listener rules to serve from S3
        let albOperations = ALBOperations()
        do {
            try await albOperations.updateListenerRulesForHoliday(using: awsClient, in: region)
        } catch {
            if error.localizedDescription.contains("ValidationError") {
                print("📋 ALB configuration skipped (not configured for this environment)")
            } else {
                print("⚠️ ALB configuration skipped: \(error)")
            }
            print("📋 Holiday pages are uploaded, but ALB rules may need manual configuration")
        }

        // 3. Stop ECS services
        try await ecsOperations.stopServices(config.ecsServices, using: awsClient, in: region)

        // 4. Wait for expected vacation mode responses (301 redirects)
        await waitForExpectedHealthResponse(expectedMode: .vacation, timeout: 300)

        // 5. Verify redirects are working properly
        await performRedirectChecks()
    }

    private func enableWorkMode() async throws {
        // Check if we're already in work mode
        let ecsOperations = ECSOperations(clusterPrefix: "")
        let config = HolidayConfiguration()

        let servicesRunning = try await ecsOperations.areServicesRunning(
            config.ecsServices,
            using: awsClient,
            in: region
        )

        if servicesRunning {
            print("💼 You're already working, silly! 💻")
            print("📋 ECS services are already running.")

            // Wait for ALB target groups to be healthy before health checks even if already in work mode
            let albOperations = ALBOperations()
            do {
                try await albOperations.waitForTargetGroupsHealthy(using: awsClient, in: region, timeout: 300)
            } catch {
                print("⚠️ ALB target health check failed: \(error)")
            }

            // Wait for expected work mode responses (200 OK)
            await waitForExpectedHealthResponse(expectedMode: .work, timeout: 300)

            // Perform final health check verification
            await performHealthChecks()
            return
        }

        // 1. Start ECS services
        try await ecsOperations.startServices(config.ecsServices, using: awsClient, in: region)

        // 2. Wait for services to be healthy with detailed monitoring (5 minutes timeout)
        try await ecsOperations.waitForServicesHealthy(config.ecsServices, using: awsClient, in: region, timeout: 300)

        // 3. Update ALB listener rules back to ECS
        let albOperations = ALBOperations()
        do {
            try await albOperations.updateListenerRulesForWork(using: awsClient, in: region)

            // 4. Verify ALB routing and target group health
            try await albOperations.verifyWorkModeRouting(using: awsClient, in: region)

            // 5. Wait for ALB target groups to be healthy before health checks
            try await albOperations.waitForTargetGroupsHealthy(using: awsClient, in: region, timeout: 300)

            print("✅ Work mode enabled! ECS services are running and ALB routing is verified.")
        } catch {
            if error.localizedDescription.contains("ValidationError") {
                print("📋 ALB configuration skipped (not configured for this environment)")
            } else {
                print("⚠️ ALB configuration skipped: \(error)")
            }
            print("📋 ECS services are running, but ALB rules may need manual configuration")
        }

        // 6. Wait for expected work mode responses (200 OK)
        await waitForExpectedHealthResponse(expectedMode: .work, timeout: 300)

        // 7. Perform final health check verification
        await performHealthChecks()
    }

    /// Waits for health checks to return expected status codes based on current mode.
    ///
    /// - Work mode: Expects 200 OK responses from /health endpoints
    /// - Vacation mode: Expects 301 redirects from main domain endpoints
    ///
    /// - Parameters:
    ///   - expectedMode: The mode to check for (.work expects 200, .vacation expects 301)
    ///   - timeout: Maximum time to wait in seconds (default: 300)
    private func waitForExpectedHealthResponse(expectedMode: HolidayMode, timeout: Int = 300) async {
        let startTime = Date()
        let healthChecker = HTTPHealthChecker(timeout: 10)

        let urls: [URL]
        let expectedStatusCodes: [Int]
        let modeDescription: String

        switch expectedMode {
        case .work:
            // Only check health for services that are active in work mode
            let config = HolidayConfiguration()
            urls = config.domainMappings.keys.map { domain in
                "https://\(domain)/health"
            }.compactMap { URL(string: $0) }
            expectedStatusCodes = [200]
            modeDescription = "work mode (200 OK)"
        case .vacation:
            // Check all domains in vacation mode as they should all redirect
            let config = HolidayConfiguration()
            urls = config.allDomains.map { domain in
                "https://\(domain)"
            }.compactMap { URL(string: $0) }
            expectedStatusCodes = [301, 302]
            modeDescription = "vacation mode (301/302 redirects)"
        }

        print("🏥 Waiting for \(modeDescription) responses (timeout: \(timeout)s)...")

        while Date().timeIntervalSince(startTime) < TimeInterval(timeout) {
            let results = await healthChecker.checkHealthConcurrently(urls: urls)

            var allExpectedResponses = true
            var statusMessages: [String] = []

            for result in results {
                switch result {
                case .success(let url, let statusCode, _):
                    if expectedStatusCodes.contains(statusCode) {
                        statusMessages.append("✅ \(url.host ?? "unknown"): Expected response (HTTP \(statusCode))")
                    } else {
                        statusMessages.append("⚠️ \(url.host ?? "unknown"): Unexpected response (HTTP \(statusCode))")
                        allExpectedResponses = false
                    }
                case .failure(let url, let statusCode, _):
                    if expectedStatusCodes.contains(statusCode) {
                        statusMessages.append("✅ \(url.host ?? "unknown"): Expected response (HTTP \(statusCode))")
                    } else {
                        statusMessages.append("❌ \(url.host ?? "unknown"): Unexpected response (HTTP \(statusCode))")
                        allExpectedResponses = false
                    }
                case .error(let message):
                    statusMessages.append("⚠️ Health check error: \(message)")
                    allExpectedResponses = false
                }
            }

            // Print status
            for message in statusMessages {
                print(message)
            }

            if allExpectedResponses {
                print("🎉 All endpoints are responding as expected for \(modeDescription)!")
                return
            }

            // Wait 5 seconds before next check
            print("⏳ Waiting 5 seconds before next check...")
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }

        print("⚠️ Timeout reached. Some endpoints may not be responding as expected.")
    }

    /// Performs health checks on the unified Bazaar service endpoint.
    ///
    /// Checks `/health` endpoint for:
    /// - www.sagebrush.services/health (unified Bazaar service)
    private func performHealthChecks() async {
        print("🏥 Performing final health check verification...")

        let healthChecker = HTTPHealthChecker(timeout: 10)
        let healthURLs = [
            "https://www.sagebrush.services/health"
        ].compactMap { URL(string: $0) }

        let results = await healthChecker.checkHealthConcurrently(urls: healthURLs)

        var allHealthy = true
        for result in results {
            switch result {
            case .success(let url, let statusCode, _):
                print("✅ \(url.host ?? "unknown"): Healthy (HTTP \(statusCode))")
            case .failure(let url, let statusCode, _):
                print("❌ \(url.host ?? "unknown"): Unhealthy (HTTP \(statusCode))")
                allHealthy = false
            case .error(let message):
                print("⚠️ Health check error: \(message)")
                allHealthy = false
            }
        }

        if allHealthy {
            print("✅ All services are healthy and responding!")
        } else {
            print("⚠️ Some services may need attention. Check logs for details.")
        }
    }

    /// Performs redirect checks to verify vacation mode is working properly.
    ///
    /// Verifies that the main domain redirects to S3 static pages:
    /// - www.sagebrush.services → S3
    private func performRedirectChecks() async {
        print("🔄 Verifying vacation mode redirects...")

        let healthChecker = HTTPHealthChecker(timeout: 10)
        let redirectURLs = [
            "https://www.sagebrush.services"
        ].compactMap { URL(string: $0) }

        let results = await healthChecker.checkRedirectsConcurrently(urls: redirectURLs)

        var allRedirecting = true
        for result in results {
            switch result {
            case .redirect(let url, let statusCode, let location, let isS3):
                if isS3 {
                    print("✅ \(url.host ?? "unknown"): Redirecting to S3 (HTTP \(statusCode))")
                } else {
                    print("⚠️ \(url.host ?? "unknown"): Redirecting but not to S3 (HTTP \(statusCode) → \(location))")
                    allRedirecting = false
                }
            case .noRedirect(let url, let statusCode):
                print("❌ \(url.host ?? "unknown"): Not redirecting (HTTP \(statusCode))")
                allRedirecting = false
            case .error(let message):
                print("⚠️ Redirect check error: \(message)")
                allRedirecting = false
            }
        }

        if allRedirecting {
            print("✅ The unified Bazaar domain is properly redirecting to S3 holiday pages!")
        } else {
            print("⚠️ The domain may not be redirecting properly. Check ALB configuration.")
        }
    }
}
