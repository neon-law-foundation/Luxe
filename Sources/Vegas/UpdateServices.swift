import ArgumentParser
import Foundation
import SotoCloudFormation
import SotoCore
import SotoECS

struct UpdateServices: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "update-services",
        abstract: "Update ECS services with latest container images from GitHub Container Registry",
        discussion: """
            Update the Bazaar and Destined ECS services with the latest container images from GitHub Container Registry.

            This command will:
            1. Pull the latest images from ghcr.io/neon-law-foundation/
            2. Update both Bazaar and Destined services
            3. Wait for deployments to complete

            Examples:
              swift run Vegas update-services
              swift run Vegas update-services --timeout 600
            """
    )

    @Option(name: .long, help: "Timeout in seconds for deployment completion (default: 300)")
    var timeout: Int = 300

    func run() async throws {
        fputs("🔄 Updating ECS services with latest container images from GitHub Container Registry...\n", stderr)

        let primaryRegion = Region.uswest2

        guard let accessKey = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"] else {
            fputs("❌ AWS_ACCESS_KEY_ID environment variable not set\n", stderr)
            throw ExitCode.failure
        }

        guard let secretKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] else {
            fputs("❌ AWS_SECRET_ACCESS_KEY environment variable not set\n", stderr)
            throw ExitCode.failure
        }

        let luxeCloud = LuxeCloud(accessKey: accessKey, secretKey: secretKey)

        do {
            let cloudFormation = CloudFormation(client: luxeCloud.client, region: primaryRegion)
            let ecs = ECS(client: luxeCloud.client, region: primaryRegion)

            // Services to update based on current infrastructure
            let servicesToUpdate = [
                ServiceUpdateConfig(
                    serviceName: "bazaar",
                    stackName: "bazaar-service",
                    clusterName: "bazaar-cluster",
                    imageRepository: "ghcr.io/neon-law-foundation/bazaar"
                ),
                ServiceUpdateConfig(
                    serviceName: "destined",
                    stackName: "destined-service",
                    clusterName: "destined-cluster",
                    imageRepository: "ghcr.io/neon-law-foundation/destined"
                ),
            ]

            fputs("📋 Services to update:\n", stderr)
            for service in servicesToUpdate {
                fputs("  • \(service.serviceName) (\(service.imageRepository):latest)\n", stderr)
            }

            for serviceConfig in servicesToUpdate {
                fputs("\n🚀 Updating \(serviceConfig.serviceName) service...\n", stderr)

                // Update the service by forcing a new deployment
                try await updateECSService(
                    serviceConfig: serviceConfig,
                    ecs: ecs,
                    cloudFormation: cloudFormation,
                    timeout: timeout
                )
            }

            try await luxeCloud.client.shutdown()
            fputs("\n🎉 All ECS services updated successfully!\n", stderr)

        } catch {
            fputs("❌ Error updating ECS services: \(error)\n", stderr)
            try await luxeCloud.client.shutdown()
            throw error
        }
    }

    private func updateECSService(
        serviceConfig: ServiceUpdateConfig,
        ecs: ECS,
        cloudFormation: CloudFormation,
        timeout: Int
    ) async throws {
        // Get current service details
        let describeServicesRequest = ECS.DescribeServicesRequest(
            cluster: serviceConfig.clusterName,
            services: [serviceConfig.serviceName]
        )

        let describeResponse = try await ecs.describeServices(describeServicesRequest)

        guard let service = describeResponse.services?.first else {
            fputs("⚠️ Service \(serviceConfig.serviceName) not found in cluster \(serviceConfig.clusterName)\n", stderr)
            return
        }

        guard let taskDefinitionArn = service.taskDefinition else {
            fputs("⚠️ No task definition found for service \(serviceConfig.serviceName)\n", stderr)
            return
        }

        fputs("📋 Current task definition: \(taskDefinitionArn)\n", stderr)

        // Get the current task definition details
        let describeTaskDefRequest = ECS.DescribeTaskDefinitionRequest(
            taskDefinition: taskDefinitionArn
        )

        let taskDefResponse = try await ecs.describeTaskDefinition(describeTaskDefRequest)

        guard let taskDefinition = taskDefResponse.taskDefinition else {
            fputs("⚠️ Could not retrieve task definition details for \(serviceConfig.serviceName)\n", stderr)
            return
        }

        guard let containerDefinitions = taskDefinition.containerDefinitions else {
            fputs("⚠️ No container definitions found in task definition for \(serviceConfig.serviceName)\n", stderr)
            return
        }

        // Update container definitions with latest images
        let updatedContainerDefinitions = containerDefinitions.map { containerDef in
            if let currentImage = containerDef.image,
                currentImage.contains(serviceConfig.imageRepository)
            {
                // Update to latest tag
                let newImage = "\(serviceConfig.imageRepository):latest"
                fputs("📦 Updating container image from \(currentImage) to \(newImage)\n", stderr)

                // Create new container definition with updated image
                return ECS.ContainerDefinition(
                    cpu: containerDef.cpu,
                    environment: containerDef.environment,
                    essential: containerDef.essential,
                    healthCheck: containerDef.healthCheck,
                    image: newImage,
                    logConfiguration: containerDef.logConfiguration,
                    memory: containerDef.memory,
                    memoryReservation: containerDef.memoryReservation,
                    name: containerDef.name,
                    portMappings: containerDef.portMappings,
                    secrets: containerDef.secrets
                )
            }
            return containerDef
        }

        // Register new task definition
        let registerRequest = ECS.RegisterTaskDefinitionRequest(
            containerDefinitions: updatedContainerDefinitions,
            cpu: taskDefinition.cpu,
            executionRoleArn: taskDefinition.executionRoleArn,
            family: taskDefinition.family ?? "unknown",
            memory: taskDefinition.memory,
            networkMode: taskDefinition.networkMode,
            requiresCompatibilities: taskDefinition.requiresCompatibilities,
            taskRoleArn: taskDefinition.taskRoleArn
        )

        let registerResponse = try await ecs.registerTaskDefinition(registerRequest)

        guard let newTaskDefinitionArn = registerResponse.taskDefinition?.taskDefinitionArn else {
            fputs("⚠️ Failed to register new task definition for \(serviceConfig.serviceName)\n", stderr)
            return
        }

        fputs("✅ New task definition registered: \(newTaskDefinitionArn)\n", stderr)

        // Update the service to use the new task definition
        let updateServiceRequest = ECS.UpdateServiceRequest(
            cluster: serviceConfig.clusterName,
            forceNewDeployment: true,  // Force deployment even if task definition hasn't changed
            service: serviceConfig.serviceName,
            taskDefinition: newTaskDefinitionArn
        )

        let updateResponse = try await ecs.updateService(updateServiceRequest)

        if let updatedService = updateResponse.service {
            fputs("✅ Service \(serviceConfig.serviceName) updated successfully\n", stderr)
            fputs("📋 New task definition: \(updatedService.taskDefinition ?? "unknown")\n", stderr)
        } else {
            fputs("⚠️ Service update response did not contain service details\n", stderr)
        }

        // Wait for deployment to complete
        fputs("⏳ Waiting for service deployment to complete...\n", stderr)
        try await waitForServiceDeployment(
            serviceName: serviceConfig.serviceName,
            clusterName: serviceConfig.clusterName,
            ecs: ecs,
            timeout: TimeInterval(timeout)
        )
    }

    private func waitForServiceDeployment(
        serviceName: String,
        clusterName: String,
        ecs: ECS,
        timeout: TimeInterval
    ) async throws {
        let startTime = Date()
        let checkInterval: TimeInterval = 10  // Check every 10 seconds

        while Date().timeIntervalSince(startTime) < timeout {
            let describeRequest = ECS.DescribeServicesRequest(
                cluster: clusterName,
                services: [serviceName]
            )

            let response = try await ecs.describeServices(describeRequest)

            guard let service = response.services?.first else {
                throw UpdateServicesError.serviceNotFound(serviceName)
            }

            let deployments = service.deployments ?? []
            let runningDeployments = deployments.filter { $0.status == "RUNNING" }

            if runningDeployments.count <= 1 {
                // Only one deployment running means update is complete
                if let deployment = runningDeployments.first {
                    let runningCount = deployment.runningCount ?? 0
                    let desiredCount = deployment.desiredCount ?? 0

                    if runningCount == desiredCount && desiredCount > 0 {
                        fputs("✅ Service \(serviceName) deployment completed successfully\n", stderr)
                        fputs("📊 Running tasks: \(runningCount)/\(desiredCount)\n", stderr)
                        return
                    }
                }
            }

            fputs("⏳ Deployment in progress for \(serviceName)...\n", stderr)
            try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
        }

        fputs("⚠️ Timeout: Service \(serviceName) deployment did not complete within \(Int(timeout)) seconds\n", stderr)
        fputs("💡 The deployment may still be in progress. Check AWS console for details.\n", stderr)
    }
}

struct ServiceUpdateConfig {
    let serviceName: String
    let stackName: String
    let clusterName: String
    let imageRepository: String
}

enum UpdateServicesError: Error {
    case serviceNotFound(String)
}

// MARK: - Security Types

/// Security errors for container registry operations
enum SecurityError: Error, LocalizedError {
    case invalidGitHubContainerRegistry(String)

    var errorDescription: String? {
        switch self {
        case .invalidGitHubContainerRegistry(let path):
            return
                "Invalid GitHub Container Registry repository path: \(path). Only valid ghcr.io repository paths are allowed."
        }
    }
}

/// Secure wrapper for GitHub Container Registry URLs
struct SecureGitHubRegistry {
    let imageURL: String

    /// Creates a secure GitHub Container Registry URL
    /// - Parameter repository: The repository path (e.g., "org/repo")
    /// - Throws: SecurityError.invalidGitHubContainerRegistry if the repository path is invalid
    init(repository: String) throws {
        // Validate the repository path for security
        guard Self.isValidRepositoryPath(repository) else {
            throw SecurityError.invalidGitHubContainerRegistry(repository)
        }

        // Always use ghcr.io - never trust user input for the domain
        self.imageURL = "ghcr.io/\(repository)"
    }

    /// Validates that a repository path is safe to use
    /// - Parameter path: The repository path to validate
    /// - Returns: true if the path is safe, false otherwise
    private static func isValidRepositoryPath(_ path: String) -> Bool {
        // Reject empty or whitespace-only paths
        guard !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        // Reject paths containing protocols
        guard !path.contains("://") else {
            return false
        }

        // Reject paths starting with domains (potential fishing attacks)
        let suspiciousDomains = [
            "github.io", "ghcr.com", "gcr.io", "docker.io", "quay.io",
            "dockerhub.com", "registry.hub.docker.com", "ghcr.io.evil.com",
        ]

        for domain in suspiciousDomains {
            if path.hasPrefix(domain) {
                return false
            }
        }

        // Additional check: reject any path containing 'ghcr.io' but not starting with org/repo pattern
        // This prevents domains like "malicious.ghcr.io" or "ghcr.io.evil.com"
        if path.contains("ghcr.io") {
            return false
        }

        // Reject path traversal attempts
        guard !path.contains("..") && !path.hasPrefix(".") && !path.hasPrefix("/") else {
            return false
        }

        // Reject file:// or other protocol schemes
        guard !path.contains("file:") && !path.contains("://") else {
            return false
        }

        // Ensure it contains at least org/repo format
        let components = path.split(separator: "/")
        guard components.count >= 2 else {
            return false
        }

        // Validate each component contains only safe characters
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        for component in components {
            guard component.unicodeScalars.allSatisfy(allowedCharacters.contains) else {
                return false
            }

            // Reject components that are too short or too long
            guard component.count >= 1 && component.count <= 255 else {
                return false
            }
        }

        return true
    }
}

/// Secure wrapper for ServiceUpdateConfig that ensures only ghcr.io is used
struct SecureServiceUpdateConfig {
    let serviceName: String
    let stackName: String
    let clusterName: String
    let imageRepository: String

    /// Creates a secure service update configuration
    /// - Parameters:
    ///   - serviceName: Name of the ECS service
    ///   - stackName: CloudFormation stack name
    ///   - clusterName: ECS cluster name
    ///   - repository: GitHub repository path (e.g., "org/repo")
    /// - Throws: SecurityError.invalidGitHubContainerRegistry if repository is invalid
    init(serviceName: String, stackName: String, clusterName: String, repository: String) throws {
        self.serviceName = serviceName
        self.stackName = stackName
        self.clusterName = clusterName

        // Use SecureGitHubRegistry to ensure only ghcr.io URLs
        let secureRegistry = try SecureGitHubRegistry(repository: repository)
        self.imageRepository = secureRegistry.imageURL
    }
}
