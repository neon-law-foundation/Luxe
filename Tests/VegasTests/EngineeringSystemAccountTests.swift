import Testing

@testable import Vegas

@Suite("Engineering System Account Infrastructure", .serialized)
struct EngineeringSystemAccountTests {

    @Test("Should create engineering system account CloudFormation template")
    func engineeringSystemAccountTemplateCreation() async throws {
        // Given an engineering system account stack
        let engineeringSystemAccount = EngineeringSystemAccount()

        // When we get the template body
        let templateBody = engineeringSystemAccount.templateBody

        // Then it should contain essential IAM and EC2 resources
        #expect(templateBody.contains("AWS::IAM::User"))
        #expect(templateBody.contains("AWS::IAM::Policy"))
        #expect(templateBody.contains("AWS::EC2::KeyPair"))
    }

    @Test("Should configure user with AdministratorAccess policy")
    func engineeringSystemAccountAdministratorAccess() async throws {
        // Given an engineering system account stack
        let engineeringSystemAccount = EngineeringSystemAccount()

        // When we examine the template
        let templateBody = engineeringSystemAccount.templateBody

        // Then it should grant full administrator access
        #expect(templateBody.contains("\"Action\": \"*\""))
        #expect(templateBody.contains("\"Resource\": \"*\""))
        #expect(templateBody.contains("\"Effect\": \"Allow\""))
    }

    @Test("Should create EC2 KeyPair with proper configuration")
    func engineeringSystemAccountEC2KeyPair() async throws {
        // Given an engineering system account stack
        let engineeringSystemAccount = EngineeringSystemAccount()

        // When we examine the template
        let templateBody = engineeringSystemAccount.templateBody

        // Then it should create an EC2 KeyPair with appropriate settings
        #expect(templateBody.contains("\"KeyName\": \"engineering-system-keypair\""))
        #expect(templateBody.contains("\"KeyType\": \"rsa\""))
        #expect(templateBody.contains("\"KeyFormat\": \"pem\""))
    }

    @Test("Should export necessary values for cross-stack references")
    func engineeringSystemAccountExports() async throws {
        // Given an engineering system account stack
        let engineeringSystemAccount = EngineeringSystemAccount()

        // When we examine the outputs
        let templateBody = engineeringSystemAccount.templateBody

        // Then it should export values needed for other stacks
        #expect(templateBody.contains("EngineeringSystemAccount-UserName"))
        #expect(templateBody.contains("EngineeringSystemAccount-UserArn"))
        #expect(templateBody.contains("EngineeringSystemAccount-KeyPairName"))
        #expect(templateBody.contains("EngineeringSystemAccount-KeyPairId"))
    }

    @Test("Should have proper IAM user name")
    func engineeringSystemAccountUserName() async throws {
        // Given an engineering system account stack
        let engineeringSystemAccount = EngineeringSystemAccount()

        // When we examine the template
        let templateBody = engineeringSystemAccount.templateBody

        // Then it should have the correct user name
        #expect(templateBody.contains("\"UserName\": \"engineering-system-account\""))
    }
}
