import Testing

@testable import Vegas

@Suite("Application Load Balancer Authentication", .serialized)
struct ALBAuthenticationTests {

    @Test("Should create ALB with basic configuration")
    func albBasicConfiguration() async throws {
        // Given an ALB with authentication configuration
        let albAuth = ApplicationLoadBalancerWithAuth()

        // When we examine the template
        let templateBody = albAuth.templateBody

        // Then it should include basic ALB configuration
        #expect(templateBody.contains("ApplicationLoadBalancer"))
        #expect(templateBody.contains("HTTPSListener"))
        #expect(templateBody.contains("sagebrush-alb"))
    }

    @Test("Should configure security group for ALB")
    func albSecurityGroupConfiguration() async throws {
        // Given an ALB with authentication configuration
        let albAuth = ApplicationLoadBalancerWithAuth()

        // When we examine the template
        let templateBody = albAuth.templateBody

        // Then it should include security group configuration
        #expect(templateBody.contains("ALBSecurityGroup"))
        #expect(templateBody.contains("Allow HTTPS traffic"))
        #expect(templateBody.contains("Allow HTTP traffic"))
    }

    @Test("Should import VPC and Certificate parameters")
    func albImportsRequiredParameters() async throws {
        // Given an ALB with authentication configuration
        let albAuth = ApplicationLoadBalancerWithAuth()

        // When we examine the template parameters
        let templateBody = albAuth.templateBody

        // Then it should reference required stack parameters
        #expect(templateBody.contains("VPCStackName"))
        #expect(templateBody.contains("CertificateStackNames"))
        #expect(templateBody.contains("CognitoStackName"))
    }

    @Test("Should export ALB resources for other stacks")
    func albExportsResources() async throws {
        // Given an ALB with authentication configuration
        let albAuth = ApplicationLoadBalancerWithAuth()

        // When we examine the outputs
        let templateBody = albAuth.templateBody

        // Then it should export necessary resources
        #expect(templateBody.contains("LoadBalancerArn"))
        #expect(templateBody.contains("LoadBalancerDNS"))
        #expect(templateBody.contains("HTTPSListenerArn"))
        #expect(templateBody.contains("ALBSecurityGroupId"))
    }
}
