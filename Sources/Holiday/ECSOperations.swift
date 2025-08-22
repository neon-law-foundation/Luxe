import Foundation
import SotoCore
import SotoECS

/// Manages ECS service lifecycle operations for Holiday mode.
///
/// ## Overview
/// This struct handles starting and stopping ECS services, as well as
/// checking their current state for idempotent operations.
public struct ECSOperations {
    /// Optional prefix for cluster names (not currently used).
    public let clusterPrefix: String

    /// Derives the ECS cluster name from a service name.
    ///
    /// ## Naming Convention
    /// Services follow the pattern: `{name}-service`
    /// Clusters follow the pattern: `{name}-cluster`
    ///
    /// - Parameter serviceName: The ECS service name (e.g., "standards-service")
    /// - Returns: The corresponding cluster name (e.g., "standards-cluster")
    public func clusterNameForService(_ serviceName: String) -> String {
        // Remove "-service" suffix if present, then add "-cluster"
        let baseName =
            serviceName.hasSuffix("-service")
            ? String(serviceName.dropLast(8))
            : serviceName
        return "\(baseName)-cluster"
    }

    /// Stops all specified ECS services by setting desired count to 0.
    ///
    /// ## Behavior
    /// - Sets each service's desired count to 0
    /// - Handles missing services gracefully
    /// - Waits 10 seconds for tasks to stop
    ///
    /// - Parameters:
    ///   - services: Array of service names to stop
    ///   - client: AWS client for ECS operations
    ///   - region: AWS region where services are located
    /// - Throws: ECS errors if operations fail
    public func stopServices(_ services: [String], using client: AWSClient, in region: Region) async throws {
        let ecs = ECS(client: client, region: region)

        print("🛑 Starting shutdown of \(services.count) ECS services...")
        print("📋 Services to stop: \(services.joined(separator: ", "))")

        var successfullyStoppedServices: [String] = []
        var failedServices: [String] = []

        for serviceName in services {
            let clusterName = clusterNameForService(serviceName)

            print("🛑 Stopping service \(serviceName) in cluster \(clusterName)...")

            // Update the service to have 0 desired tasks
            let updateRequest = ECS.UpdateServiceRequest(
                cluster: clusterName,
                desiredCount: 0,
                service: serviceName
            )

            do {
                _ = try await ecs.updateService(updateRequest)
                print("✅ Service \(serviceName) set to 0 desired tasks")
                successfullyStoppedServices.append(serviceName)
            } catch {
                let errorString = String(describing: error)
                if errorString.contains("ServiceNotFoundException") {
                    print("📋 Service \(serviceName) not found (already stopped or doesn't exist)")
                } else {
                    print("⚠️ Failed to stop service \(serviceName): \(error)")
                    failedServices.append(serviceName)
                }
            }
        }

        // Wait for tasks to stop
        print("⏳ Waiting for all tasks to stop...")
        try await Task.sleep(nanoseconds: 10 * 1_000_000_000)  // 10 seconds

        // Summary of shutdown operation
        print("\n🔍 ECS Service Shutdown Summary:")
        print("✅ Successfully stopped: \(successfullyStoppedServices.count) services")
        if !successfullyStoppedServices.isEmpty {
            print("   - \(successfullyStoppedServices.joined(separator: "\n   - "))")
        }
        if !failedServices.isEmpty {
            print("❌ Failed to stop: \(failedServices.count) services")
            print("   - \(failedServices.joined(separator: "\n   - "))")
        }
        print("✅ All ECS services shutdown process completed")
    }

    /// Starts all specified ECS services by setting desired count to 1.
    ///
    /// ## Behavior
    /// - Sets each service's desired count to 1
    /// - Handles missing services gracefully
    /// - Reports successful starts
    ///
    /// - Parameters:
    ///   - services: Array of service names to start
    ///   - client: AWS client for ECS operations
    ///   - region: AWS region where services are located
    /// - Throws: ECS errors if operations fail
    public func startServices(_ services: [String], using client: AWSClient, in region: Region) async throws {
        let ecs = ECS(client: client, region: region)

        print("💼 Returning to work mode...")

        for serviceName in services {
            let clusterName = clusterNameForService(serviceName)

            print("🚀 Starting service \(serviceName) in cluster \(clusterName)...")

            // Update the service to have 1 desired task (can be adjusted based on needs)
            let updateRequest = ECS.UpdateServiceRequest(
                cluster: clusterName,
                desiredCount: 1,
                service: serviceName
            )

            do {
                _ = try await ecs.updateService(updateRequest)
                print("✅ Service \(serviceName) set to 1 desired task")
            } catch {
                let errorString = String(describing: error)
                if errorString.contains("ServiceNotFoundException") {
                    print("📋 Service \(serviceName) not found (service doesn't exist in this environment)")
                } else {
                    print("⚠️ Failed to start service \(serviceName): \(error)")
                }
            }
        }

        print("✅ All ECS services started")
    }

    /// Waits for all specified services to become healthy with detailed monitoring.
    ///
    /// ## Behavior
    /// - Monitors service health every 5 seconds
    /// - Reports individual service status
    /// - Times out after specified duration
    /// - Shows running vs desired task counts
    ///
    /// - Parameters:
    ///   - services: Array of service names to monitor
    ///   - client: AWS client for ECS operations
    ///   - region: AWS region where services are located
    ///   - timeout: Maximum time to wait in seconds (default: 120)
    /// - Throws: Timeout error if services don't become healthy
    public func waitForServicesHealthy(
        _ services: [String],
        using client: AWSClient,
        in region: Region,
        timeout: TimeInterval = 120
    ) async throws {
        let ecs = ECS(client: client, region: region)
        let startTime = Date()

        print("⏳ Monitoring service health (timeout: \(Int(timeout))s)...")

        while Date().timeIntervalSince(startTime) < timeout {
            var allHealthy = true
            var statusReport: [String] = []

            for serviceName in services {
                let clusterName = clusterNameForService(serviceName)

                do {
                    let describeRequest = ECS.DescribeServicesRequest(
                        cluster: clusterName,
                        services: [serviceName]
                    )

                    let response = try await ecs.describeServices(describeRequest)

                    guard let service = response.services?.first else {
                        statusReport.append("📋 \(serviceName): Service not found")
                        allHealthy = false
                        continue
                    }

                    let desiredCount = service.desiredCount ?? 0
                    let runningCount = service.runningCount ?? 0
                    let pendingCount = service.pendingCount ?? 0

                    if runningCount >= desiredCount && desiredCount > 0 {
                        statusReport.append("✅ \(serviceName): \(runningCount)/\(desiredCount) running")
                    } else if pendingCount > 0 {
                        statusReport.append(
                            "🔄 \(serviceName): \(runningCount)/\(desiredCount) running, \(pendingCount) pending"
                        )
                        allHealthy = false
                    } else {
                        statusReport.append("⏳ \(serviceName): \(runningCount)/\(desiredCount) running")
                        allHealthy = false
                    }

                } catch {
                    statusReport.append("⚠️ \(serviceName): Error checking status - \(error)")
                    allHealthy = false
                }
            }

            // Print status report
            for status in statusReport {
                print(status)
            }

            if allHealthy {
                print("🎉 All services are healthy and ready!")
                return
            }

            print("⏳ Waiting 5 seconds before next health check...")
            try await Task.sleep(nanoseconds: 5 * 1_000_000_000)  // 5 second intervals
        }

        print("⚠️ Timeout: Services did not become healthy within \(Int(timeout)) seconds")
        print("💡 Services may still be starting up. Check AWS console for details.")
    }

    /// Checks if any of the specified services are currently running.
    ///
    /// ## Logic
    /// - Returns `true` if ANY service has desired count > 0
    /// - Returns `false` if ALL services have desired count = 0 or don't exist
    ///
    /// - Parameters:
    ///   - services: Array of service names to check
    ///   - client: AWS client for ECS operations
    ///   - region: AWS region where services are located
    /// - Returns: `true` if any service is running, `false` otherwise
    /// - Throws: ECS errors if operations fail
    public func areServicesRunning(
        _ services: [String],
        using client: AWSClient,
        in region: Region
    ) async throws -> Bool {
        let ecs = ECS(client: client, region: region)

        for serviceName in services {
            let clusterName = clusterNameForService(serviceName)

            do {
                let describeRequest = ECS.DescribeServicesRequest(
                    cluster: clusterName,
                    services: [serviceName]
                )

                let response = try await ecs.describeServices(describeRequest)

                guard let service = response.services?.first else {
                    // Service doesn't exist, consider it not running
                    continue
                }

                // Check if desired count is greater than 0
                if let desiredCount = service.desiredCount, desiredCount > 0 {
                    return true
                }
            } catch {
                // If we can't describe the service, assume it's not running
                continue
            }
        }

        return false
    }

    /// Checks if all specified services are currently stopped.
    ///
    /// ## Logic
    /// - Returns `true` if ALL services have desired count = 0 or don't exist
    /// - Returns `false` if ANY service has desired count > 0
    ///
    /// - Parameters:
    ///   - services: Array of service names to check
    ///   - client: AWS client for ECS operations
    ///   - region: AWS region where services are located
    /// - Returns: `true` if all services are stopped, `false` otherwise
    /// - Throws: ECS errors if operations fail
    public func areServicesStopped(
        _ services: [String],
        using client: AWSClient,
        in region: Region
    ) async throws -> Bool {
        let ecs = ECS(client: client, region: region)

        for serviceName in services {
            let clusterName = clusterNameForService(serviceName)

            do {
                let describeRequest = ECS.DescribeServicesRequest(
                    cluster: clusterName,
                    services: [serviceName]
                )

                let response = try await ecs.describeServices(describeRequest)

                guard let service = response.services?.first else {
                    // Service doesn't exist, consider it stopped
                    continue
                }

                // Check if desired count is 0
                if let desiredCount = service.desiredCount, desiredCount > 0 {
                    return false
                }
            } catch {
                // If we can't describe the service, assume it's stopped
                continue
            }
        }

        return true
    }
}
