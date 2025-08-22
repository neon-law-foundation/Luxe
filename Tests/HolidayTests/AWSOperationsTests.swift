import ServiceLifecycle
import Testing

@testable import Holiday

@Suite("AWS Operations", .serialized)
struct AWSOperationsTests {
    @Test("S3 operations upload HTML correctly")
    func s3UploadOperationWorksCorrectly() async throws {
        let awsConfig = AWSClientConfiguration(bucketName: "sagebrush-public")
        let s3Operations = S3Operations(config: awsConfig)

        // Test that we can generate the correct S3 key for each active domain
        let activeDomains = [
            "www.sagebrush.services"
        ]

        for domain in activeDomains {
            let key = s3Operations.s3KeyForDomain(domain)
            #expect(key.hasSuffix("/index.html"))
            #expect(key.hasPrefix("holiday/"))
        }

        // Test S3 key generation for any domain
        let testKey = s3Operations.s3KeyForDomain("example.com")
        #expect(testKey == "holiday/example.com/index.html")

        // Manually shutdown the AWS client to avoid the assertion failure
        try await awsConfig.client.shutdown()
    }

    @Test("ECS operations handle service updates")
    func ecsOperationsWorkCorrectly() async throws {
        let ecsOperations = ECSOperations(clusterPrefix: "")

        // Test service name to cluster mapping
        let serviceToCluster = [
            "sagebrushweb-service": "sagebrushweb-cluster"
        ]

        for (service, expectedCluster) in serviceToCluster {
            let cluster = ecsOperations.clusterNameForService(service)
            #expect(cluster == expectedCluster)
        }
    }

    @Test("ALB operations update listener rules")
    func albOperationsWorkCorrectly() async throws {
        let albOperations = ALBOperations()

        // Test that we have the correct listener rule priorities for active services
        let activePriorities = [
            "www.sagebrush.services": 200
        ]

        for (domain, expectedPriority) in activePriorities {
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
}
