import Foundation
import Testing

@testable import Vegas

@Suite("Private Email S3 Bucket Infrastructure", .serialized)
struct PrivateEmailS3BucketTests {
    @Test("Private email S3 bucket should be named sagebrush-emails")
    func bucketNameIsConfiguredCorrectly() throws {
        let stack = PrivateEmailS3Bucket()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]
        let bucket = resources?["PrivateEmailS3Bucket"] as? [String: Any]
        let properties = bucket?["Properties"] as? [String: Any]
        let bucketName = properties?["BucketName"] as? String

        #expect(bucketName == "sagebrush-emails")
    }

    @Test("Private email S3 bucket should block all public access")
    func publicAccessBlockIsConfiguredCorrectly() throws {
        let stack = PrivateEmailS3Bucket()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]
        let bucket = resources?["PrivateEmailS3Bucket"] as? [String: Any]
        let properties = bucket?["Properties"] as? [String: Any]
        let publicAccessBlock = properties?["PublicAccessBlockConfiguration"] as? [String: Any]

        #expect(publicAccessBlock?["BlockPublicAcls"] as? Bool == true)
        #expect(publicAccessBlock?["BlockPublicPolicy"] as? Bool == true)
        #expect(publicAccessBlock?["IgnorePublicAcls"] as? Bool == true)
        #expect(publicAccessBlock?["RestrictPublicBuckets"] as? Bool == true)
    }

    @Test("Private email S3 bucket should have SES service access policy")
    func sesBucketPolicyIsConfiguredCorrectly() throws {
        let stack = PrivateEmailS3Bucket()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]
        let bucketPolicy = resources?["PrivateEmailS3BucketPolicy"] as? [String: Any]
        let properties = bucketPolicy?["Properties"] as? [String: Any]
        let policyDocument = properties?["PolicyDocument"] as? [String: Any]
        let statements = policyDocument?["Statement"] as? [[String: Any]]

        #expect(statements?.count == 1)

        let allowStatement = statements?.first
        #expect(allowStatement?["Effect"] as? String == "Allow")
        #expect(allowStatement?["Principal"] as? [String: String] == ["Service": "ses.amazonaws.com"])

        let actions = allowStatement?["Action"] as? [String]
        #expect(actions?.contains("s3:PutObject") == true)
    }

    @Test("Private email S3 bucket should have server-side encryption")
    func encryptionIsConfiguredCorrectly() throws {
        let stack = PrivateEmailS3Bucket()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]
        let bucket = resources?["PrivateEmailS3Bucket"] as? [String: Any]
        let properties = bucket?["Properties"] as? [String: Any]
        let encryptionConfig = properties?["BucketEncryption"] as? [String: Any]
        let serverSideEncryptionRules = encryptionConfig?["ServerSideEncryptionConfiguration"] as? [[String: Any]]

        #expect(serverSideEncryptionRules?.count == 1)

        let rule = serverSideEncryptionRules?.first
        let serverSideEncryptionByDefault = rule?["ServerSideEncryptionByDefault"] as? [String: Any]
        #expect(serverSideEncryptionByDefault?["SSEAlgorithm"] as? String == "AES256")
    }

    @Test("Private email S3 bucket should have versioning enabled")
    func versioningIsConfiguredCorrectly() throws {
        let stack = PrivateEmailS3Bucket()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]
        let bucket = resources?["PrivateEmailS3Bucket"] as? [String: Any]
        let properties = bucket?["Properties"] as? [String: Any]
        let versioningConfig = properties?["VersioningConfiguration"] as? [String: Any]

        #expect(versioningConfig?["Status"] as? String == "Enabled")
    }

    @Test("Private email S3 bucket should have lifecycle rule for email cleanup")
    func lifecycleRuleIsConfiguredCorrectly() throws {
        let stack = PrivateEmailS3Bucket()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]
        let bucket = resources?["PrivateEmailS3Bucket"] as? [String: Any]
        let properties = bucket?["Properties"] as? [String: Any]
        let lifecycleConfig = properties?["LifecycleConfiguration"] as? [String: Any]
        let rules = lifecycleConfig?["Rules"] as? [[String: Any]]

        #expect(rules?.count == 2)

        // Check for email cleanup rule
        let emailCleanupRule = rules?.first { rule in
            (rule["Id"] as? String) == "DeleteProcessedEmails"
        }
        #expect(emailCleanupRule != nil)
        #expect(emailCleanupRule?["ExpirationInDays"] as? Int == 30)
        #expect(emailCleanupRule?["Status"] as? String == "Enabled")

        // Check for old version cleanup rule
        let versionCleanupRule = rules?.first { rule in
            (rule["Id"] as? String) == "DeleteOldVersions"
        }
        #expect(versionCleanupRule != nil)
        #expect(versionCleanupRule?["NoncurrentVersionExpirationInDays"] as? Int == 7)
        #expect(versionCleanupRule?["Status"] as? String == "Enabled")
    }

    @Test("Private email S3 bucket should have appropriate outputs")
    func outputsAreConfiguredCorrectly() throws {
        let stack = PrivateEmailS3Bucket()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let outputs = template?["Outputs"] as? [String: Any]

        #expect(outputs?["BucketName"] != nil)
        #expect(outputs?["BucketArn"] != nil)
        #expect(outputs?["BucketDomainName"] != nil)
    }

    @Test("Private email S3 bucket should have notification configuration for processed emails")
    func notificationConfigurationIsConfiguredCorrectly() throws {
        let stack = PrivateEmailS3Bucket()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]
        let bucket = resources?["PrivateEmailS3Bucket"] as? [String: Any]
        let properties = bucket?["Properties"] as? [String: Any]
        let notificationConfig = properties?["NotificationConfiguration"] as? [String: Any]

        #expect(notificationConfig?["QueueConfigurations"] != nil)
    }

    @Test("Private email S3 bucket should have no required parameters")
    func noRequiredParametersAreNeeded() throws {
        let stack = PrivateEmailS3Bucket()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let parameters = template?["Parameters"] as? [String: Any]
        #expect(parameters?.isEmpty == true)
    }
}
