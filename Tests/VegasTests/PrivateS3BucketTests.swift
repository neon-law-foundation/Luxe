import Foundation
import Testing

@testable import Vegas

@Suite("Private S3 Bucket Infrastructure", .serialized)
struct PrivateS3BucketTests {
    @Test("Private S3 bucket should be named sagebrush-private")
    func bucketNameIsConfiguredCorrectly() throws {
        let stack = PrivateS3Bucket()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]
        let bucket = resources?["PrivateS3Bucket"] as? [String: Any]
        let properties = bucket?["Properties"] as? [String: Any]
        let bucketName = properties?["BucketName"] as? String

        #expect(bucketName == "sagebrush-private")
    }

    @Test("Private S3 bucket should block all public access")
    func publicAccessBlockIsConfiguredCorrectly() throws {
        let stack = PrivateS3Bucket()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]
        let bucket = resources?["PrivateS3Bucket"] as? [String: Any]
        let properties = bucket?["Properties"] as? [String: Any]
        let publicAccessBlock = properties?["PublicAccessBlockConfiguration"] as? [String: Any]

        #expect(publicAccessBlock?["BlockPublicAcls"] as? Bool == true)
        #expect(publicAccessBlock?["BlockPublicPolicy"] as? Bool == true)
        #expect(publicAccessBlock?["IgnorePublicAcls"] as? Bool == true)
        #expect(publicAccessBlock?["RestrictPublicBuckets"] as? Bool == true)
    }

    @Test("Private S3 bucket should have a restrictive bucket policy")
    func bucketPolicyIsConfiguredCorrectly() throws {
        let stack = PrivateS3Bucket()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]
        let bucketPolicy = resources?["PrivateS3BucketPolicy"] as? [String: Any]
        let properties = bucketPolicy?["Properties"] as? [String: Any]
        let policyDocument = properties?["PolicyDocument"] as? [String: Any]
        let statements = policyDocument?["Statement"] as? [[String: Any]]

        #expect(statements?.count == 1)

        let denyStatement = statements?.first
        #expect(denyStatement?["Effect"] as? String == "Deny")
        #expect(denyStatement?["Principal"] as? String == "*")

        let condition = denyStatement?["Condition"] as? [String: Any]
        let stringNotEquals = condition?["StringNotEquals"] as? [String: Any]
        #expect(stringNotEquals?["aws:SourceVpce"] != nil)
    }

    @Test("Private S3 bucket should have server-side encryption")
    func encryptionIsConfiguredCorrectly() throws {
        let stack = PrivateS3Bucket()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]
        let bucket = resources?["PrivateS3Bucket"] as? [String: Any]
        let properties = bucket?["Properties"] as? [String: Any]
        let encryptionConfig = properties?["BucketEncryption"] as? [String: Any]
        let serverSideEncryptionRules = encryptionConfig?["ServerSideEncryptionConfiguration"] as? [[String: Any]]

        #expect(serverSideEncryptionRules?.count == 1)

        let rule = serverSideEncryptionRules?.first
        let serverSideEncryptionByDefault = rule?["ServerSideEncryptionByDefault"] as? [String: Any]
        #expect(serverSideEncryptionByDefault?["SSEAlgorithm"] as? String == "AES256")
    }

    @Test("Private S3 bucket should have versioning enabled")
    func versioningIsConfiguredCorrectly() throws {
        let stack = PrivateS3Bucket()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]
        let bucket = resources?["PrivateS3Bucket"] as? [String: Any]
        let properties = bucket?["Properties"] as? [String: Any]
        let versioningConfig = properties?["VersioningConfiguration"] as? [String: Any]

        #expect(versioningConfig?["Status"] as? String == "Enabled")
    }

    @Test("Private S3 bucket should have appropriate outputs")
    func outputsAreConfiguredCorrectly() throws {
        let stack = PrivateS3Bucket()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let outputs = template?["Outputs"] as? [String: Any]

        #expect(outputs?["BucketName"] != nil)
        #expect(outputs?["BucketArn"] != nil)
    }

    @Test("Private S3 bucket policy should reference VPC stack")
    func vpcStackReferenceIsConfiguredCorrectly() throws {
        let stack = PrivateS3Bucket()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let parameters = template?["Parameters"] as? [String: Any]
        #expect(parameters?["VPCStackName"] != nil)
    }
}
