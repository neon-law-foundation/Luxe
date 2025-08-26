import Foundation
import Testing

@testable import Vegas

@Suite("Sagebrush GitHub System Account Infrastructure", .serialized)
struct SagebrushGithubSystemAccountTests {

    @Test("Should create GitHub system account CloudFormation template")
    func sagebrushGithubSystemAccountTemplateCreation() async throws {
        // Given a Sagebrush GitHub system account stack
        let githubSystemAccount = SagebrushGithubSystemAccount()

        // When we get the template body
        let templateBody = githubSystemAccount.templateBody

        // Then it should contain essential IAM resources
        #expect(templateBody.contains("AWS::IAM::User"))
        #expect(templateBody.contains("AWS::IAM::Policy"))
        #expect(templateBody.contains("SagebrushGithubUser"))
        #expect(templateBody.contains("SagebrushGithubS3Policy"))
        #expect(templateBody.contains("SagebrushGithubECSPolicy"))
    }

    @Test("Should configure S3 access permissions for binary uploads")
    func sagebrushGithubS3AccessPermissions() async throws {
        // Given a Sagebrush GitHub system account stack
        let githubSystemAccount = SagebrushGithubSystemAccount()

        // When we examine the template
        let templateBody = githubSystemAccount.templateBody

        // Then it should grant S3 access to sagebrush-public/bin/*
        #expect(templateBody.contains("s3:PutObject"))
        #expect(templateBody.contains("s3:PutObjectAcl"))
        #expect(templateBody.contains("arn:aws:s3:::sagebrush-public/bin/*"))
    }

    @Test("Should configure ECS service restart permissions")
    func sagebrushGithubECSServicePermissions() async throws {
        // Given a Sagebrush GitHub system account stack
        let githubSystemAccount = SagebrushGithubSystemAccount()

        // When we examine the template
        let templateBody = githubSystemAccount.templateBody

        // Then it should grant ECS service management permissions
        #expect(templateBody.contains("ecs:UpdateService"))
        #expect(templateBody.contains("ecs:DescribeServices"))
        #expect(templateBody.contains("ecs:DescribeTaskDefinition"))
        #expect(templateBody.contains("ecs:RegisterTaskDefinition"))
        #expect(templateBody.contains("ecs:ListServices"))
        #expect(templateBody.contains("ecs:ListClusters"))
    }

    @Test("Should include IAM PassRole permissions for ECS task and execution roles")
    func sagebrushGithubPassRolePermissions() async throws {
        // Given a Sagebrush GitHub system account stack
        let githubSystemAccount = SagebrushGithubSystemAccount()

        // When we examine the template
        let templateBody = githubSystemAccount.templateBody

        // Then it should grant IAM PassRole permissions for both services
        #expect(templateBody.contains("iam:PassRole"))
        #expect(templateBody.contains("arn:aws:iam::*:role/bazaar-service-TaskRole-*"))
        #expect(templateBody.contains("arn:aws:iam::*:role/destined-service-TaskRole-*"))
        #expect(templateBody.contains("arn:aws:iam::*:role/bazaar-service-TaskExecutionRole-*"))
        #expect(templateBody.contains("arn:aws:iam::*:role/destined-service-TaskExecutionRole-*"))
    }

    @Test("Should target specific ECS services for restart permissions")
    func sagebrushGithubECSServiceTargets() async throws {
        // Given a Sagebrush GitHub system account stack
        let githubSystemAccount = SagebrushGithubSystemAccount()

        // When we examine the template
        let templateBody = githubSystemAccount.templateBody

        // Then it should target the correct ECS services
        #expect(templateBody.contains("arn:aws:ecs:*:*:service/bazaar-cluster/bazaar"))
        #expect(templateBody.contains("arn:aws:ecs:*:*:service/destined-cluster/destined"))
    }

    @Test("Should have proper IAM user name")
    func sagebrushGithubSystemAccountUserName() async throws {
        // Given a Sagebrush GitHub system account stack
        let githubSystemAccount = SagebrushGithubSystemAccount()

        // When we examine the template
        let templateBody = githubSystemAccount.templateBody

        // Then it should have the correct user name
        #expect(templateBody.contains("\"UserName\": \"sagebrush-github-system-account\""))
    }

    @Test("Should export necessary values for cross-stack references")
    func sagebrushGithubSystemAccountExports() async throws {
        // Given a Sagebrush GitHub system account stack
        let githubSystemAccount = SagebrushGithubSystemAccount()

        // When we examine the outputs
        let templateBody = githubSystemAccount.templateBody

        // Then it should export values needed for other stacks
        #expect(templateBody.contains("SagebrushGithubSystemAccount-UserName"))
        #expect(templateBody.contains("SagebrushGithubSystemAccount-UserArn"))
    }

    @Test("Should have valid JSON CloudFormation template structure")
    func sagebrushGithubSystemAccountJSONValidity() async throws {
        // Given a Sagebrush GitHub system account stack
        let githubSystemAccount = SagebrushGithubSystemAccount()

        // When we parse the template as JSON
        let templateBody = githubSystemAccount.templateBody
        let jsonData = templateBody.data(using: .utf8)!

        // Then it should be valid JSON and contain required CloudFormation sections
        let template = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]

        #expect(template["AWSTemplateFormatVersion"] as? String == "2010-09-09")
        #expect(template["Description"] != nil)
        #expect(template["Resources"] != nil)
        #expect(template["Outputs"] != nil)
    }
}
