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
        print("🔄 Updating ECS services with latest container images from GitHub Container Registry...")

        let primaryRegion = Region.uswest2

        guard let accessKey = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"] else {
            print("❌ AWS_ACCESS_KEY_ID environment variable not set")
            throw ExitCode.failure
        }

        guard let secretKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] else {
            print("❌ AWS_SECRET_ACCESS_KEY environment variable not set")
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

            print("📋 Services to update:")
            for service in servicesToUpdate {
                print("  • \(service.serviceName) (\(service.imageRepository):latest)")
            }

            for serviceConfig in servicesToUpdate {
                print("\n🚀 Updating \(serviceConfig.serviceName) service...")

                // Update the service by forcing a new deployment
                try await updateECSService(
                    serviceConfig: serviceConfig,
                    ecs: ecs,
                    cloudFormation: cloudFormation,
                    timeout: timeout
                )
            }

            try await luxeCloud.client.shutdown()
            print("\n🎉 All ECS services updated successfully!")

        } catch {
            print("❌ Error updating ECS services: \(error)")
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
            print("⚠️ Service \(serviceConfig.serviceName) not found in cluster \(serviceConfig.clusterName)")
            return
        }

        guard let taskDefinitionArn = service.taskDefinition else {
            print("⚠️ No task definition found for service \(serviceConfig.serviceName)")
            return
        }

        print("📋 Current task definition: \(taskDefinitionArn)")

        // Get the current task definition details
        let describeTaskDefRequest = ECS.DescribeTaskDefinitionRequest(
            taskDefinition: taskDefinitionArn
        )

        let taskDefResponse = try await ecs.describeTaskDefinition(describeTaskDefRequest)

        guard let taskDefinition = taskDefResponse.taskDefinition else {
            print("⚠️ Could not retrieve task definition details for \(serviceConfig.serviceName)")
            return
        }

        guard let containerDefinitions = taskDefinition.containerDefinitions else {
            print("⚠️ No container definitions found in task definition for \(serviceConfig.serviceName)")
            return
        }

        // Update container definitions with latest images
        let updatedContainerDefinitions = containerDefinitions.map { containerDef in
            if let currentImage = containerDef.image,
                currentImage.contains(serviceConfig.imageRepository)
            {
                // Update to latest tag
                let newImage = "\(serviceConfig.imageRepository):latest"
                print("📦 Updating container image from \(currentImage) to \(newImage)")

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
            print("⚠️ Failed to register new task definition for \(serviceConfig.serviceName)")
            return
        }

        print("✅ New task definition registered: \(newTaskDefinitionArn)")

        // Update the service to use the new task definition
        let updateServiceRequest = ECS.UpdateServiceRequest(
            cluster: serviceConfig.clusterName,
            forceNewDeployment: true,  // Force deployment even if task definition hasn't changed
            service: serviceConfig.serviceName,
            taskDefinition: newTaskDefinitionArn
        )

        let updateResponse = try await ecs.updateService(updateServiceRequest)

        if let updatedService = updateResponse.service {
            print("✅ Service \(serviceConfig.serviceName) updated successfully")
            print("📋 New task definition: \(updatedService.taskDefinition ?? "unknown")")
        } else {
            print("⚠️ Service update response did not contain service details")
        }

        // Wait for deployment to complete
        print("⏳ Waiting for service deployment to complete...")
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
                        print("✅ Service \(serviceName) deployment completed successfully")
                        print("📊 Running tasks: \(runningCount)/\(desiredCount)")
                        return
                    }
                }
            }

            print("⏳ Deployment in progress for \(serviceName)...")
            try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
        }

        print("⚠️ Timeout: Service \(serviceName) deployment did not complete within \(Int(timeout)) seconds")
        print("💡 The deployment may still be in progress. Check AWS console for details.")
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
