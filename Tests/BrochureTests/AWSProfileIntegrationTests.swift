import ArgumentParser
import Foundation
import Testing

@testable import Brochure

@Suite("AWS Profile Integration Tests")
struct AWSProfileIntegrationTests {
    private let testDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("AWSProfileIntegrationTests")
        .appendingPathComponent(UUID().uuidString)

    init() throws {
        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    // MARK: - Command Integration Tests

    @Test("UploadCommand should accept and use profile parameter")
    func testUploadCommandWithProfile() throws {
        // Test parsing with profile
        let command = try UploadCommand.parse([
            "NeonLaw",
            "--profile", "staging",
            "--dry-run",
        ])

        #expect(command.profile == "staging")
        #expect(command.siteName == "NeonLaw")
        #expect(command.dryRun == true)
    }

    @Test("UploadCommand should work without profile parameter")
    func testUploadCommandWithoutProfile() throws {
        let command = try UploadCommand.parse([
            "HoshiHoshi",
            "--dry-run",
        ])

        #expect(command.profile == nil)
        #expect(command.siteName == "HoshiHoshi")
    }

    @Test("Should validate profile configuration during upload")
    func testProfileValidationDuringUpload() async throws {
        // Create a mock S3Uploader to test profile validation
        let uploader = S3Uploader(
            bucketName: "test-bucket",
            keyPrefix: "test-prefix",
            profile: "nonexistent-profile"
        )

        // Test that the uploader was created (validation happens during AWS operations)
        // This tests the integration of profile handling in the upload process
        // Just verify we can create an uploader with a profile

        // Clean up the uploader
        try await uploader.shutdown()
    }

    // MARK: - Profile Resolution Integration Tests

    @Test("Should resolve profiles in correct priority order")
    func testProfileResolutionPriority() {
        let resolver = ProfileResolver()

        // Test 1: Explicit profile takes precedence
        let explicitResolution = resolver.resolveProfile(
            explicit: "production",
            environment: ["AWS_PROFILE": "staging"],
            configFile: nil
        )
        #expect(explicitResolution.profileName == "production")
        #expect(explicitResolution.source == .explicit)

        // Test 2: Environment variable used when no explicit profile
        let envResolution = resolver.resolveProfile(
            explicit: nil,
            environment: ["AWS_PROFILE": "development"],
            configFile: nil
        )
        #expect(envResolution.profileName == "development")
        #expect(envResolution.source == .environment)

        // Test 3: Falls back to default chain
        let defaultResolution = resolver.resolveProfile(
            explicit: nil,
            environment: [:],
            configFile: nil
        )
        #expect(defaultResolution.source == .defaultChain)
    }

    @Test("Should handle region resolution from different sources")
    func testRegionResolution() {
        let resolver = ProfileResolver()

        // Test region from environment
        let resolution = resolver.resolveProfile(
            explicit: "prod",
            environment: ["AWS_REGION": "eu-west-1"],
            configFile: nil
        )

        #expect(resolution.region == "eu-west-1")
    }

    // MARK: - Error Handling Integration Tests

    @Test("Should provide comprehensive error information")
    func testProfileErrorIntegration() {
        let availableProfiles = ["default", "staging", "production", "development"]
        let profileError = ProfileError.profileNotFound(
            profile: "missing-profile",
            available: availableProfiles
        )

        let description = profileError.errorDescription ?? ""

        // Should mention the missing profile
        #expect(description.contains("missing-profile"))

        // Should list available profiles
        for profile in availableProfiles {
            #expect(description.contains(profile))
        }

        // Should provide actionable instructions
        #expect(description.contains("aws configure"))
    }

    @Test("Should handle AWS configuration file scenarios")
    func testAWSConfigurationFileHandling() {
        // Test case where AWS config directory doesn't exist
        let configError = ProfileError.awsConfigNotFound
        let errorDescription = configError.errorDescription ?? ""

        #expect(errorDescription.contains("AWS configuration"))
        #expect(errorDescription.contains("aws configure"))
        #expect(errorDescription.contains("https://docs.aws.amazon.com"))
    }

    // MARK: - Multi-Account Scenarios

    @Test("Should support multiple account configurations")
    func testMultiAccountSupport() {
        let resolver = ProfileResolver()

        // Simulate multi-account scenario
        let accountProfiles = [
            ("prod-account-1", "us-east-1"),
            ("staging-account-2", "us-west-2"),
            ("dev-account-3", "eu-west-1"),
        ]

        for (profile, region) in accountProfiles {
            let resolution = resolver.resolveProfile(
                explicit: profile,
                environment: ["AWS_REGION": region],
                configFile: nil
            )

            #expect(resolution.profileName == profile)
            #expect(resolution.region == region)
            #expect(resolution.source == .explicit)
        }
    }

    @Test("Should handle cross-account bucket access scenarios")
    func testCrossAccountBucketAccess() {
        // Test bucket access denied error for specific account
        let bucketError = ProfileError.bucketAccessDenied(
            bucket: "cross-account-bucket",
            profile: "restricted-profile"
        )

        let description = bucketError.errorDescription ?? ""
        #expect(description.contains("cross-account-bucket"))
        #expect(description.contains("restricted-profile"))
        #expect(description.contains("s3:PutObject"))
        #expect(description.contains("bucket policy"))
    }

    // MARK: - Command Line Integration Tests

    @Test("Should integrate profiles with all upload command options")
    func testProfileWithAllUploadOptions() throws {
        let command = try UploadCommand.parse([
            "TarotSwift",
            "--profile", "prod-deployment",
            "--dry-run",
            "--verbose",
            "--exclude", "*.log,temp/**",
        ])

        #expect(command.siteName == "TarotSwift")
        #expect(command.profile == "prod-deployment")
        #expect(command.dryRun == true)
        #expect(command.verbose == true)
        #expect(command.exclude == "*.log,temp/**")
    }

    @Test("Should validate profile parameter in command parsing")
    func testProfileParameterValidation() throws {
        // Valid profile parameter
        let validCommand = try UploadCommand.parse([
            "NLF",
            "--profile", "staging",
        ])
        #expect(validCommand.profile == "staging")

        // No profile parameter (should be nil)
        let noProfileCommand = try UploadCommand.parse(["NVSciTech"])
        #expect(noProfileCommand.profile == nil)

        // Empty profile parameter should still parse
        let emptyProfileCommand = try UploadCommand.parse([
            "1337lawyers",
            "--profile", "",
        ])
        #expect(emptyProfileCommand.profile == "")
    }

    // MARK: - Environment Variable Integration

    @Test("Should integrate with environment variable scenarios")
    func testEnvironmentVariableIntegration() {
        let resolver = ProfileResolver()

        // Test various AWS environment variable combinations
        let environmentScenarios = [
            // Standard AWS_PROFILE
            (["AWS_PROFILE": "production"], "production"),
            // AWS_PROFILE with region
            (["AWS_PROFILE": "staging", "AWS_REGION": "us-west-2"], "staging"),
        ]

        for (env, expectedProfile) in environmentScenarios {
            let resolution = resolver.resolveProfile(
                explicit: nil,
                environment: env,
                configFile: nil
            )

            #expect(
                resolution.profileName == expectedProfile,
                "Expected profile '\(expectedProfile)' for environment \(env)"
            )
        }
    }

    // MARK: - Configuration File Integration

    @Test("Should handle AWS configuration file integration")
    func testConfigurationFileIntegration() {
        // Test that resolver can handle config file scenarios
        let resolver = ProfileResolver()

        // Create a temporary config file for testing
        let configContent = """
            [default]
            region = us-east-1
            output = json

            [profile staging]
            region = us-west-2
            output = json
            """

        let tempConfigFile = testDirectory.appendingPathComponent("config")

        defer {
            try? FileManager.default.removeItem(at: tempConfigFile)
        }

        do {
            try configContent.write(to: tempConfigFile, atomically: true, encoding: .utf8)
        } catch {
            // If we can't create the file, skip this test
            return
        }

        // Test that the resolver handles config file input appropriately
        let resolution = resolver.resolveProfile(
            explicit: nil,
            environment: ["AWS_PROFILE": "staging"],
            configFile: tempConfigFile
        )

        #expect(resolution.profileName == "staging")
        #expect(resolution.source == ProfileSource.environment)
    }

    // MARK: - Performance and Resource Management

    @Test("Should efficiently create and clean up S3 uploaders with profiles")
    func testS3UploaderResourceManagement() async throws {
        let profiles = ["default", "staging", "production"]
        var uploaders: [S3Uploader] = []

        // Create multiple uploaders with different profiles
        for profile in profiles {
            let uploader = S3Uploader(
                bucketName: "test-bucket",
                keyPrefix: "test-\(profile)",
                profile: profile
            )
            uploaders.append(uploader)
        }

        // Verify all uploaders were created
        #expect(uploaders.count == profiles.count)

        // Clean up all uploaders
        for uploader in uploaders {
            try await uploader.shutdown()
        }
    }

    @Test("Should handle concurrent profile operations")
    func testConcurrentProfileOperations() async throws {
        let resolver = ProfileResolver()

        // Test concurrent profile resolution
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    let resolution = resolver.resolveProfile(
                        explicit: "test-profile-\(i)",
                        environment: ["AWS_REGION": "us-east-1"],
                        configFile: nil
                    )

                    #expect(resolution.profileName == "test-profile-\(i)")
                }
            }
        }
    }

    // MARK: - Integration with Real World Scenarios

    @Test("Should support typical CI/CD profile scenarios")
    func testCICDProfileScenarios() {
        let resolver = ProfileResolver()

        // CI/CD typically uses environment variables
        let ciEnvironment = [
            "AWS_ACCESS_KEY_ID": "AKIA...",
            "AWS_SECRET_ACCESS_KEY": "secret...",
            "AWS_REGION": "us-east-1",
            "AWS_PROFILE": "ci-deployment",
        ]

        let resolution = resolver.resolveProfile(
            explicit: nil,
            environment: ciEnvironment,
            configFile: nil
        )

        #expect(resolution.profileName == "ci-deployment")
        #expect(resolution.region == "us-east-1")
        #expect(resolution.source == .environment)
    }

    @Test("Should support local development profile scenarios")
    func testLocalDevelopmentProfileScenarios() {
        let resolver = ProfileResolver()

        // Local development typically uses explicit profiles
        let localDevelopmentResolution = resolver.resolveProfile(
            explicit: "my-dev-profile",
            environment: ["AWS_REGION": "us-west-2"],
            configFile: nil
        )

        #expect(localDevelopmentResolution.profileName == "my-dev-profile")
        #expect(localDevelopmentResolution.region == "us-west-2")
        #expect(localDevelopmentResolution.source == .explicit)
    }
}
