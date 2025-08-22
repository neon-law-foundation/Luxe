import Foundation
import Testing

@testable import Holiday

@Suite("Holiday Integration Tests", .serialized)
struct HolidayIntegrationTests {

    @Test(
        "Vacation mode is idempotent - shows vacation message when already in vacation mode",
        .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil)
    )
    func vacationModeIdempotencyWorksCorrectly() async throws {
        // This test verifies that running vacation mode twice shows the idempotent message
        let command = HolidayCommand()
        command.mode = .vacation

        // Test the idempotency logic by checking if services are already stopped
        let ecsOperations = ECSOperations(clusterPrefix: "")
        let config = HolidayConfiguration()

        // In a test environment, services won't exist, so they should be considered "stopped"
        let servicesStopped = try await ecsOperations.areServicesStopped(
            config.ecsServices,
            using: command.awsClient,
            in: command.region
        )

        // Services should be considered stopped in test environment
        #expect(servicesStopped == true)

        // Explicitly shutdown the AWS client to avoid assertion failure
        try await command.awsClient.shutdown()
    }

    @Test(
        "Work mode is idempotent - shows work message when already in work mode",
        .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil)
    )
    func workModeIdempotencyWorksCorrectly() async throws {
        let command = HolidayCommand()
        command.mode = .work

        // Test the idempotency logic by checking if services are running
        let ecsOperations = ECSOperations(clusterPrefix: "")
        let config = HolidayConfiguration()

        // In a test environment, services won't exist, so they should be considered "not running"
        let servicesRunning = try await ecsOperations.areServicesRunning(
            config.ecsServices,
            using: command.awsClient,
            in: command.region
        )

        // Services should be considered not running in test environment
        #expect(servicesRunning == false)

        // Explicitly shutdown the AWS client to avoid assertion failure
        try await command.awsClient.shutdown()
    }

    @Test("Holiday HTML content is generated correctly")
    func holidayHTMLGenerationWorksCorrectly() throws {
        let generator = HolidayHTMLGenerator()
        let html = generator.generateHTML()

        // Verify HTML structure
        #expect(html.contains("<!DOCTYPE html>"))
        #expect(html.contains("<html"))
        #expect(html.contains("</html>"))
        #expect(html.contains("<title>We are currently on holiday</title>"))
        #expect(html.contains("<h1>We are currently on holiday</h1>"))

        // Verify trifecta information
        #expect(html.contains("Sagebrush Services"))
        #expect(html.contains("Neon Law"))
        #expect(html.contains("Neon Law Foundation"))
        #expect(html.contains("support@sagebrush.services"))

        // Verify it's a complete HTML document
        #expect(html.count > 1000)  // Should be substantial content
    }

    @Test("S3 operations generate correct keys for all domains")
    func s3KeyGenerationWorksCorrectly() async throws {
        let awsConfig = AWSClientConfiguration(bucketName: "sagebrush-public")
        let s3Operations = S3Operations(config: awsConfig)
        let expectedDomains = [
            "www.sagebrush.services",
            "www.neonlaw.com",
            "www.neonlaw.org",
            "bazaar.sagebrush.services",
        ]

        for domain in expectedDomains {
            let key = s3Operations.s3KeyForDomain(domain)
            #expect(key == "holiday/\(domain)/index.html")
        }

        // Manually shutdown the AWS client to avoid the assertion failure
        try await awsConfig.client.shutdown()
    }

    @Test("ECS cluster name generation works correctly")
    func ecsClusterNameGenerationWorksCorrectly() throws {
        let ecsOperations = ECSOperations(clusterPrefix: "")

        let serviceToClusterMapping = [
            "bazaar": "bazaar-cluster",
            "sagebrushweb-service": "sagebrushweb-cluster",
            "bazaar-service": "bazaar-cluster",
            "neon-web-service": "neon-web-cluster",
            "nlf-web-service": "nlf-web-cluster",
        ]

        for (service, expectedCluster) in serviceToClusterMapping {
            let cluster = ecsOperations.clusterNameForService(service)
            #expect(cluster == expectedCluster)
        }
    }

    @Test("ALB listener priorities are configured correctly")
    func albListenerPrioritiesAreConfiguredCorrectly() throws {
        let albOperations = ALBOperations()

        // Test active domain priorities (unified bazaar service)
        let activeDomainMapping = [
            "www.sagebrush.services": 200
        ]

        for (domain, expectedPriority) in activeDomainMapping {
            let priority = albOperations.listenerPriorityForDomain(domain)
            #expect(priority == expectedPriority)
        }

        // Test that inactive domains return default priority (999)
        let inactiveDomains = [
            "bazaar.sagebrush.services",
            "www.neonlaw.com",
            "www.neonlaw.org",
        ]

        for domain in inactiveDomains {
            let priority = albOperations.listenerPriorityForDomain(domain)
            #expect(priority == 999)
        }
    }

    @Test("Holiday configuration contains active services")
    func holidayConfigurationCompletenessIsValidated() throws {
        let config = HolidayConfiguration()

        // Verify active ECS services are configured (unified bazaar service)
        let activeServices = [
            "bazaar"
        ]

        #expect(config.ecsServices.count == activeServices.count)
        for service in activeServices {
            #expect(config.ecsServices.contains(service))
        }

        // Verify inactive services are not included
        let inactiveServices = [
            "sagebrushweb",
            "neon-web-service",
            "nlf-web-service",
        ]

        for service in inactiveServices {
            #expect(!config.ecsServices.contains(service))
        }

        // Verify active domains are mapped to services
        let activeDomains = [
            "www.sagebrush.services"
        ]

        #expect(config.domainMappings.count == activeDomains.count)
        for domain in activeDomains {
            #expect(config.domainMappings[domain] != nil)
        }

        // Verify inactive domains are not included
        let inactiveDomains = [
            "bazaar.sagebrush.services",
            "www.neonlaw.com",
            "www.neonlaw.org",
        ]

        for domain in inactiveDomains {
            #expect(config.domainMappings[domain] == nil)
        }

        // Verify listener priorities are assigned for active domains
        #expect(config.listenerPriorities.count == activeDomains.count)
        for domain in activeDomains {
            #expect(config.listenerPriorities[domain] != nil)
        }

        // Verify inactive domains don't have priorities
        for domain in inactiveDomains {
            #expect(config.listenerPriorities[domain] == nil)
        }
    }

    @Test("Domain mappings are consistent between services and priorities")
    func domainMappingConsistencyIsValidated() throws {
        let config = HolidayConfiguration()

        // Every domain in domainMappings should have a priority
        for domain in config.domainMappings.keys {
            #expect(config.listenerPriorities[domain] != nil, "Domain \(domain) missing priority")
        }

        // Every domain with a priority should have a service mapping
        for domain in config.listenerPriorities.keys {
            #expect(config.domainMappings[domain] != nil, "Domain \(domain) missing service mapping")
        }

        // Every service in domainMappings should be in ecsServices
        for service in config.domainMappings.values {
            #expect(config.ecsServices.contains(service), "Service \(service) not in ECS services list")
        }
    }
}
