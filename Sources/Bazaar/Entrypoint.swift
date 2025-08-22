import Foundation
import Logging
import ServiceLifecycle
import Vapor

/// Service wrapper for Vapor application
struct VaporService: Service {
    let app: Application

    func run() async throws {
        try await cancelWhenGracefulShutdown {
            try await app.execute()
        }
    }
}

/// Main entry point for the Bazaar API service
@main
struct Entrypoint {
    static func main() async throws {
        let logger = Logger(label: "Bazaar")

        let app = try await Application.make()

        // Ensure the app listens on all interfaces
        // Use 127.0.0.1 for local development, 0.0.0.0 in Docker containers
        app.http.server.configuration.hostname =
            ProcessInfo.processInfo.environment["ENV"] == "PRODUCTION" ? "0.0.0.0" : "127.0.0.1"

        try await configureApp(app)

        let vaporService = VaporService(app: app)

        // Per Vapor docs: Queue workers should be started separately with CLI command
        // Not as part of the main app service group
        let serviceGroup = ServiceGroup(
            services: [vaporService],
            gracefulShutdownSignals: [.sigterm, .sigint],
            logger: logger
        )

        try await serviceGroup.run()
    }

}

/// Bazaar-specific errors
enum BazaarError: Error {
    case invalidConfiguration(String)
}
