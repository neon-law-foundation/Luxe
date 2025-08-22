import Foundation

/// Configuration for Holiday mode operations.
///
/// ## Overview
/// This struct centralizes all service and domain configuration for the Holiday system,
/// ensuring consistent mapping between domains, ECS services, and ALB listener priorities.
///
/// ## Configuration Structure
/// - **ECS Services**: List of all managed ECS service names
/// - **Domain Mappings**: Maps domains to their corresponding ECS services
/// - **Listener Priorities**: ALB listener rule priorities for each domain
/// - **All Domains**: Complete list of all domains for holiday page generation
public struct HolidayConfiguration {
    /// All ECS services managed by Holiday mode.
    ///
    /// These services will be stopped during vacation mode and started during work mode.
    public let ecsServices = [
        "bazaar"
        // TODO: Add these services back at a future date
        // "neon-web",
        // "nlf-web",
    ]

    /// Maps domain names to their corresponding ECS service names.
    ///
    /// Used to determine which target group to route traffic to in work mode.
    public let domainMappings = [
        "www.sagebrush.services": "bazaar"
            // TODO: Add these mappings back at a future date
            // "bazaar.sagebrush.services": "bazaar",
            // "www.neonlaw.com": "neon-web",
            // "www.neonlaw.org": "nlf-web",
    ]

    /// ALB listener rule priorities for each domain.
    ///
    /// Lower numbers have higher priority in ALB rule evaluation.
    /// These priorities ensure consistent rule ordering across mode switches.
    public let listenerPriorities = [
        "www.sagebrush.services": 200
            // TODO: Add these priorities back at a future date
            // "bazaar.sagebrush.services": 300,
            // "www.neonlaw.com": 400,
            // "www.neonlaw.org": 500,
    ]

    /// All domains that should have holiday pages created.
    ///
    /// This includes domains that remain in vacation mode even when work mode is active.
    public let allDomains = [
        "www.sagebrush.services"
        // TODO: Add these domains back at a future date
        // "www.neonlaw.com",
        // "www.neonlaw.org",
    ]
}
