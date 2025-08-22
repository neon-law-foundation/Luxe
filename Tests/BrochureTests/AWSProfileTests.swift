import Foundation
import Testing

@testable import Brochure

@Suite("AWS Profile Configuration")
struct AWSProfileTests {

    @Test("ProfileResolver prioritizes explicit profile over environment")
    func testExplicitProfilePriority() {
        let resolver = ProfileResolver()

        let resolution = resolver.resolveProfile(
            explicit: "production",
            environment: ["AWS_PROFILE": "staging", "AWS_REGION": "us-west-2"],
            configFile: nil
        )

        #expect(resolution.profileName == "production")
        #expect(resolution.source == .explicit)
        #expect(resolution.region == "us-west-2")
    }

    @Test("ProfileResolver uses environment profile when no explicit profile")
    func testEnvironmentProfileResolution() {
        let resolver = ProfileResolver()

        let resolution = resolver.resolveProfile(
            explicit: nil,
            environment: ["AWS_PROFILE": "staging", "AWS_REGION": "us-east-1"],
            configFile: nil
        )

        #expect(resolution.profileName == "staging")
        #expect(resolution.source == .environment)
        #expect(resolution.region == "us-east-1")
    }

    @Test("ProfileResolver falls back to default chain when no profile specified")
    func testDefaultChainFallback() {
        let resolver = ProfileResolver()

        let resolution = resolver.resolveProfile(
            explicit: nil,
            environment: [:],
            configFile: nil
        )

        #expect(resolution.profileName == nil)
        #expect(resolution.source == .defaultChain)
        #expect(resolution.region == nil)
    }

    @Test("ProfileError provides helpful error messages")
    func testProfileErrorMessages() {
        let profileNotFoundError = ProfileError.profileNotFound(
            profile: "nonexistent",
            available: ["default", "staging", "production"]
        )

        let description = profileNotFoundError.errorDescription
        #expect(description != nil)
        #expect(description!.contains("nonexistent"))
        #expect(description!.contains("default"))
        #expect(description!.contains("staging"))
        #expect(description!.contains("production"))
        #expect(description!.contains("aws configure --profile"))
    }

    @Test("ProfileError handles empty available profiles list")
    func testProfileErrorWithNoAvailableProfiles() {
        let profileNotFoundError = ProfileError.profileNotFound(
            profile: "test",
            available: []
        )

        let description = profileNotFoundError.errorDescription
        #expect(description != nil)
        #expect(description!.contains("No profiles configured"))
    }

    @Test("ProfileError provides AWS config not found guidance")
    func testAWSConfigNotFoundError() {
        let configError = ProfileError.awsConfigNotFound

        let description = configError.errorDescription
        #expect(description != nil)
        #expect(description!.contains("aws configure"))
        #expect(description!.contains("https://docs.aws.amazon.com"))
    }

    @Test("ProfileError provides invalid credentials guidance")
    func testInvalidCredentialsError() {
        let credentialsError = ProfileError.invalidCredentials(profile: "production")

        let description = credentialsError.errorDescription
        #expect(description != nil)
        #expect(description!.contains("production"))
        #expect(description!.contains("aws sts get-caller-identity"))
    }

    @Test("ProfileError provides bucket access denied guidance")
    func testBucketAccessDeniedError() {
        let accessError = ProfileError.bucketAccessDenied(bucket: "my-bucket", profile: "production")

        let description = accessError.errorDescription
        #expect(description != nil)
        #expect(description!.contains("my-bucket"))
        #expect(description!.contains("production"))
        #expect(description!.contains("s3:PutObject"))
    }

    @Test("S3Uploader accepts profile parameter")
    func testS3UploaderWithProfile() async throws {
        // Create uploader with profile
        let uploader = S3Uploader(
            bucketName: "test-bucket",
            keyPrefix: "test-prefix",
            profile: "production"
        )

        // The uploader should initialize successfully
        // We can't test actual AWS operations without real credentials,
        // but we can verify the initializer accepts the profile parameter
        // (No assertion needed - successful initialization is the test)

        // Clean up AWS client
        try await uploader.shutdown()
    }

    @Test("S3Uploader configuration initializer accepts profile")
    func testS3UploaderConfigurationWithProfile() async throws {
        let config = UploadConfiguration(bucketName: "test-bucket", keyPrefix: "test-prefix")

        let uploader = S3Uploader(
            configuration: config,
            profile: "staging"
        )

        // The uploader should initialize successfully
        // (No assertion needed - successful initialization is the test)

        // Clean up AWS client
        try await uploader.shutdown()
    }

    // Test that would require actual AWS credentials - disabled for CI
    // @Test("ProfileValidator validates real AWS profiles", .disabled("Requires AWS credentials"))
    // func testProfileValidatorWithRealProfiles() throws {
    //     let validator = ProfileValidator()
    //
    //     // This would work if AWS credentials are configured
    //     let profiles = try validator.listAvailableProfiles()
    //     #expect(!profiles.isEmpty)
    // }
}
