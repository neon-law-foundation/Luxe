import Logging
import ServiceLifecycle
import Vapor
import VaporElementary

struct VaporService: Service {
    let app: Application

    func run() async throws {
        try await cancelWhenGracefulShutdown {
            try await app.execute()
        }
    }
}

@main
struct Entrypoint {
    static func main() async throws {
        let logger = Logger(label: "Destined")

        let app = try await Application.make()

        // Configure hostname: 127.0.0.1 for local development, 0.0.0.0 for Docker containers
        app.http.server.configuration.hostname =
            ProcessInfo.processInfo.environment["ENV"] == "PRODUCTION" ? "0.0.0.0" : "127.0.0.1"

        // Configure port: 4444 for local development, 8080 for Docker
        let defaultPort = ProcessInfo.processInfo.environment["ENV"] == "PRODUCTION" ? 8080 : 4444
        app.http.server.configuration.port =
            Int(ProcessInfo.processInfo.environment["PORT"] ?? "\(defaultPort)") ?? defaultPort

        try configureApp(app)

        let vaporService = VaporService(app: app)

        let serviceGroup = ServiceGroup(
            services: [vaporService],
            gracefulShutdownSignals: [.sigterm, .sigint],
            logger: logger
        )

        try await serviceGroup.run()
    }
}
