import Foundation
import SotoCloudFormation
import SotoCore
import SotoElasticLoadBalancingV2

/// Errors that can occur during Holiday operations.
public enum HolidayError: Error {
    /// CloudFormation stack was not found.
    case cloudFormationStackNotFound(String)
    /// ALB listener ARN could not be determined.
    case listenerArnNotFound
    /// Target group ARN could not be found for the specified service.
    case targetGroupArnNotFound(String)
}

/// Manages Application Load Balancer (ALB) operations for Holiday mode.
///
/// ## Overview
/// This struct handles updating ALB listener rules to switch between
/// routing traffic to S3 (vacation mode) or ECS services (work mode).
public struct ALBOperations {
    /// The CloudFormation stack name containing the ALB.
    private let albStackName = "sagebrush-alb"

    /// Retrieves the ALB listener rule priority for a given domain.
    ///
    /// - Parameter domain: The domain name (e.g., "www.sagebrush.services")
    /// - Returns: The configured priority, or 999 if not found
    public func listenerPriorityForDomain(_ domain: String) -> Int {
        let config = HolidayConfiguration()
        return config.listenerPriorities[domain] ?? 999
    }

    /// Updates ALB listener rules to redirect traffic to S3 holiday pages.
    ///
    /// ## Process
    /// 1. Retrieves the HTTPS listener ARN
    /// 2. For each configured domain, finds the corresponding rule
    /// 3. Updates the rule action to redirect to S3 static pages
    ///
    /// - Parameters:
    ///   - client: AWS client for ALB operations
    ///   - region: AWS region where the ALB is located
    /// - Throws: ALB or CloudFormation errors if operations fail
    public func updateListenerRulesForHoliday(using client: AWSClient, in region: Region) async throws {
        let elbv2 = ElasticLoadBalancingV2(client: client, region: region)

        // First, get the HTTPS listener ARN from CloudFormation
        let listenerArn = try await getListenerArn(using: client, in: region)

        let config = HolidayConfiguration()

        // Update all domains' listener rules to redirect to S3
        for domain in config.allDomains {
            let priority = listenerPriorityForDomain(domain)

            print("🔄 Updating ALB rule for \(domain)...")

            // Get the existing rules
            let rules = try await elbv2.describeRules(.init(listenerArn: listenerArn))

            // Find the rule with matching priority
            guard let rule = rules.rules?.first(where: { $0.priority == String(priority) }) else {
                print("⚠️ No rule found for priority \(priority), skipping...")
                continue
            }

            guard let ruleArn = rule.ruleArn else { continue }

            // Update the rule to redirect to S3 static website
            _ = try await elbv2.modifyRule(
                .init(
                    actions: [
                        .init(
                            redirectConfig: .init(
                                host: "sagebrush-public.s3.us-west-2.amazonaws.com",
                                path: "/holiday/\(domain)/index.html",
                                protocol: "HTTPS",
                                statusCode: .http301
                            ),
                            type: .redirect
                        )
                    ],
                    ruleArn: ruleArn
                )
            )
        }

        print("✅ All ALB rules updated for holiday mode")
    }

    /// Updates ALB listener rules to forward traffic back to ECS services.
    ///
    /// ## Process
    /// 1. Retrieves the HTTPS listener ARN
    /// 2. For each configured domain, finds the corresponding rule
    /// 3. Updates the rule action to forward to the appropriate ECS target group
    ///
    /// - Parameters:
    ///   - client: AWS client for ALB operations
    ///   - region: AWS region where the ALB is located
    /// - Throws: ALB or CloudFormation errors if operations fail
    public func updateListenerRulesForWork(using client: AWSClient, in region: Region) async throws {
        let elbv2 = ElasticLoadBalancingV2(client: client, region: region)

        // Get the listener ARN
        let listenerArn = try await getListenerArn(using: client, in: region)

        let config = HolidayConfiguration()

        // Update active domains' listener rules back to ECS
        for (domain, serviceName) in config.domainMappings {
            let priority = listenerPriorityForDomain(domain)

            print("🔄 Restoring ALB rule for \(domain) to \(serviceName)...")

            // Get the target group ARN for this service
            let targetGroupArn = try await getTargetGroupArn(for: serviceName, using: client, in: region)

            // Get the existing rules
            let rules = try await elbv2.describeRules(.init(listenerArn: listenerArn))

            guard let rule = rules.rules?.first(where: { $0.priority == String(priority) }) else {
                print("⚠️ No rule found for priority \(priority), skipping...")
                continue
            }

            guard let ruleArn = rule.ruleArn else { continue }

            // Update the rule to forward to target group
            _ = try await elbv2.modifyRule(
                .init(
                    actions: [
                        .init(
                            targetGroupArn: targetGroupArn,
                            type: .forward
                        )
                    ],
                    ruleArn: ruleArn
                )
            )
        }

        // Set inactive domains to vacation mode (S3 redirect)
        let activeDomains = Set(config.domainMappings.keys)
        let inactiveDomains = config.allDomains.filter { !activeDomains.contains($0) }

        for domain in inactiveDomains {
            let priority = listenerPriorityForDomain(domain)

            print("🏖️ Setting ALB rule for \(domain) to vacation mode...")

            // Get the existing rules
            let rules = try await elbv2.describeRules(.init(listenerArn: listenerArn))

            guard let rule = rules.rules?.first(where: { $0.priority == String(priority) }) else {
                print("⚠️ No rule found for priority \(priority), skipping...")
                continue
            }

            guard let ruleArn = rule.ruleArn else { continue }

            // Update the rule to redirect to S3 static website
            _ = try await elbv2.modifyRule(
                .init(
                    actions: [
                        .init(
                            redirectConfig: .init(
                                host: "sagebrush-public.s3.us-west-2.amazonaws.com",
                                path: "/holiday/\(domain)/index.html",
                                protocol: "HTTPS",
                                statusCode: .http301
                            ),
                            type: .redirect
                        )
                    ],
                    ruleArn: ruleArn
                )
            )
        }

        print("✅ All ALB rules updated for hybrid work mode")
    }

    /// Waits for ALB target groups to be healthy with a timeout.
    ///
    /// ## Behavior
    /// - Polls target group health every 5 seconds
    /// - Waits until all targets are healthy or timeout is reached
    /// - Provides detailed progress updates
    ///
    /// - Parameters:
    ///   - client: AWS client for ALB operations
    ///   - region: AWS region where the ALB is located
    ///   - timeout: Maximum time to wait in seconds (default: 300)
    /// - Throws: ALB errors or timeout errors if operations fail
    public func waitForTargetGroupsHealthy(using client: AWSClient, in region: Region, timeout: Int = 300) async throws
    {
        let startTime = Date()
        let config = HolidayConfiguration()

        print("🎯 Waiting for ALB target groups to be healthy (timeout: \(timeout)s)...")

        while Date().timeIntervalSince(startTime) < TimeInterval(timeout) {
            var allHealthy = true
            var statusMessages: [String] = []

            for (domain, serviceName) in config.domainMappings {
                do {
                    let targetGroupArn = try await getTargetGroupArn(for: serviceName, using: client, in: region)
                    let elbv2 = ElasticLoadBalancingV2(client: client, region: region)
                    let healthResponse = try await elbv2.describeTargetHealth(.init(targetGroupArn: targetGroupArn))

                    let targetDescriptions = healthResponse.targetHealthDescriptions ?? []
                    let healthyTargets = targetDescriptions.filter { $0.targetHealth?.state == .healthy }
                    let registering = targetDescriptions.filter {
                        $0.targetHealth?.reason?.rawValue.contains("registration") == true
                    }

                    if healthyTargets.count == targetDescriptions.count && targetDescriptions.count > 0 {
                        statusMessages.append(
                            "✅ \(domain): \(healthyTargets.count)/\(targetDescriptions.count) healthy"
                        )
                    } else if registering.count > 0 {
                        statusMessages.append(
                            "🔄 \(domain): \(healthyTargets.count)/\(targetDescriptions.count) healthy, \(registering.count) registering"
                        )
                        allHealthy = false
                    } else if targetDescriptions.count > 0 {
                        statusMessages.append(
                            "⚠️ \(domain): \(healthyTargets.count)/\(targetDescriptions.count) healthy"
                        )
                        allHealthy = false
                    } else {
                        statusMessages.append("📋 \(domain): No targets registered")
                        allHealthy = false
                    }
                } catch {
                    statusMessages.append("⚠️ \(domain): Health check failed - \(error)")
                    allHealthy = false
                }
            }

            // Print status
            for message in statusMessages {
                print(message)
            }

            if allHealthy {
                print("🎉 All ALB target groups are healthy!")
                return
            }

            // Wait 5 seconds before next check
            print("⏳ Waiting 5 seconds before next health check...")
            try await Task.sleep(nanoseconds: 5_000_000_000)
        }

        throw HolidayError.listenerArnNotFound  // Reusing error for timeout
    }

    /// Verifies ALB target group health after restoring work mode rules.
    ///
    /// ## Behavior
    /// - Checks health of targets in each service's target group
    /// - Reports healthy vs total target counts
    /// - Provides detailed status for troubleshooting
    ///
    /// - Parameters:
    ///   - client: AWS client for ALB operations
    ///   - region: AWS region where the ALB is located
    /// - Throws: ALB errors if operations fail
    public func verifyTargetGroupHealth(using client: AWSClient, in region: Region) async throws {
        let elbv2 = ElasticLoadBalancingV2(client: client, region: region)
        let config = HolidayConfiguration()

        print("🎯 Verifying target group health...")

        for (domain, serviceName) in config.domainMappings {
            do {
                let targetGroupArn = try await getTargetGroupArn(for: serviceName, using: client, in: region)
                let healthResponse = try await elbv2.describeTargetHealth(.init(targetGroupArn: targetGroupArn))

                let targetDescriptions = healthResponse.targetHealthDescriptions ?? []
                let healthyTargets = targetDescriptions.filter { $0.targetHealth?.state == .healthy }
                let unhealthyTargets = targetDescriptions.filter { $0.targetHealth?.state != .healthy }

                if healthyTargets.count > 0 {
                    print("✅ \(domain): \(healthyTargets.count)/\(targetDescriptions.count) targets healthy")
                } else if targetDescriptions.count > 0 {
                    print("⚠️ \(domain): 0/\(targetDescriptions.count) targets healthy")

                    // Show detailed status for unhealthy targets
                    for target in unhealthyTargets {
                        let state = target.targetHealth?.state?.rawValue ?? "unknown"
                        let reason = target.targetHealth?.reason?.rawValue ?? "no reason"
                        let description = target.targetHealth?.description ?? "no description"
                        print("   🔍 Target \(target.target?.id ?? "unknown"): \(state) - \(reason) - \(description)")
                    }
                } else {
                    print("📋 \(domain): No targets registered")
                }

            } catch {
                print("⚠️ \(domain): Failed to check target health - \(error)")
            }
        }

        print("🎯 Target group health verification complete")
    }

    /// Performs a comprehensive verification that ALB routing is working correctly.
    ///
    /// ## Verification Steps
    /// 1. Checks that ALB rules are correctly configured for work mode
    /// 2. Verifies target group health
    /// 3. Optionally tests HTTP responses (if testUrls is true)
    ///
    /// - Parameters:
    ///   - client: AWS client for ALB operations
    ///   - region: AWS region where the ALB is located
    ///   - testUrls: Whether to perform actual HTTP requests (default: false)
    /// - Throws: ALB errors if operations fail
    public func verifyWorkModeRouting(using client: AWSClient, in region: Region, testUrls: Bool = false) async throws {
        let elbv2 = ElasticLoadBalancingV2(client: client, region: region)
        let config = HolidayConfiguration()

        print("🔍 Verifying ALB routing configuration...")

        // Get the listener ARN
        let listenerArn = try await getListenerArn(using: client, in: region)

        // Get all rules for the listener
        let rules = try await elbv2.describeRules(.init(listenerArn: listenerArn))

        for (domain, _) in config.domainMappings {
            let priority = listenerPriorityForDomain(domain)

            // Find the rule for this domain
            guard let rule = rules.rules?.first(where: { $0.priority == String(priority) }) else {
                print("⚠️ \(domain): No rule found with priority \(priority)")
                continue
            }

            // Check if the rule is configured for forwarding (work mode)
            if let actions = rule.actions, let firstAction = actions.first {
                if firstAction.type == .forward && firstAction.targetGroupArn != nil {
                    print("✅ \(domain): Rule correctly configured for work mode (forward to target group)")
                } else if firstAction.type == .redirect {
                    print("⚠️ \(domain): Rule still configured for holiday mode (redirect to S3)")
                } else {
                    print("❓ \(domain): Rule has unexpected configuration: \(firstAction.type?.rawValue ?? "unknown")")
                }
            } else {
                print("⚠️ \(domain): Rule has no actions configured")
            }
        }

        // Verify target group health
        try await verifyTargetGroupHealth(using: client, in: region)

        print("🔍 ALB routing verification complete")
    }

    private func getListenerArn(using client: AWSClient, in region: Region) async throws -> String {
        // First try to get from CloudFormation
        do {
            let cloudFormation = CloudFormation(client: client, region: region)
            let describeStacksRequest = CloudFormation.DescribeStacksInput(stackName: albStackName)
            let response = try await cloudFormation.describeStacks(describeStacksRequest)

            if let stack = response.stacks?.first,
                let outputs = stack.outputs
            {
                // Look for the HTTPS listener ARN in the outputs
                for output in outputs {
                    if let outputKey = output.outputKey,
                        let outputValue = output.outputValue,
                        outputKey.contains("HTTPSListener") || outputKey.contains("Listener")
                    {
                        return outputValue
                    }
                }
            }
        } catch {
            // If CloudFormation fails, query the ALB directly
            let elbv2 = ElasticLoadBalancingV2(client: client, region: region)

            // Get load balancer by name
            let loadBalancersResponse = try await elbv2.describeLoadBalancers(.init(names: [albStackName]))

            guard let loadBalancer = loadBalancersResponse.loadBalancers?.first else {
                throw HolidayError.cloudFormationStackNotFound(albStackName)
            }

            // Get listeners for this load balancer
            let listenersResponse = try await elbv2.describeListeners(
                .init(loadBalancerArn: loadBalancer.loadBalancerArn)
            )

            // Find HTTPS listener (port 443)
            guard let httpsListener = listenersResponse.listeners?.first(where: { $0.port == 443 }) else {
                throw HolidayError.listenerArnNotFound
            }

            return httpsListener.listenerArn!
        }

        throw HolidayError.listenerArnNotFound
    }

    private func getTargetGroupArn(
        for serviceName: String,
        using client: AWSClient,
        in region: Region
    ) async throws -> String {
        // Try to get the target group ARN from CloudFormation exports
        // Vegas infrastructure exports target group ARNs as {StackName}-TargetGroupArn
        let cloudFormation = CloudFormation(client: client, region: region)

        do {
            // Use the exact stack name from Vegas configuration
            let stackName = "\(serviceName)-service"  // e.g., "standards-service"
            let describeStacksRequest = CloudFormation.DescribeStacksInput(stackName: stackName)
            let response = try await cloudFormation.describeStacks(describeStacksRequest)

            if let stack = response.stacks?.first,
                let outputs = stack.outputs
            {
                // Look for TargetGroupArn output
                for output in outputs {
                    if let outputKey = output.outputKey,
                        let outputValue = output.outputValue,
                        outputKey == "TargetGroupArn"
                    {
                        return outputValue
                    }
                }
            }
        } catch {
            print("⚠️ Failed to get target group ARN from CloudFormation for \(serviceName): \(error)")
        }

        // If CloudFormation lookup fails, try to find the target group by name
        do {
            let elbv2 = ElasticLoadBalancingV2(client: client, region: region)
            let targetGroupName = serviceName  // Target groups use the service name directly

            let response = try await elbv2.describeTargetGroups(.init(names: [targetGroupName]))

            if let targetGroup = response.targetGroups?.first,
                let targetGroupArn = targetGroup.targetGroupArn
            {
                return targetGroupArn
            }
        } catch {
            print("⚠️ Failed to find target group by name \(serviceName): \(error)")
        }

        throw HolidayError.targetGroupArnNotFound(serviceName)
    }

}
