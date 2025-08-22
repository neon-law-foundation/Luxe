import Foundation
import Logging
import Testing

@testable import Brochure

/// Tests for secure credential management using keychain integration.
///
/// These tests verify the KeychainManager's ability to securely store, retrieve,
/// and manage AWS credentials and configuration data in the macOS keychain.
@Suite("KeychainManager Tests")
struct KeychainManagerTests {

    @Test("KeychainManager initializes correctly with logging")
    func testKeychainManagerInitialization() async throws {
        let logger = createTestLogger()
        let _ = KeychainManager(logger: logger)

        // Should initialize without errors
        // Note: We can't easily test internal state, but we can test that operations work
    }

    @Test("KeychainManager stores and retrieves AWS credentials successfully")
    func testStoreAndRetrieveCredentials() async throws {
        let logger = createTestLogger()
        let keychain = KeychainManager(logger: logger)
        let testProfile = "test-profile-\(UUID().uuidString)"

        // Clean up will be done at the end of the test

        // Store test credentials
        try await keychain.storeAWSCredentials(
            profile: testProfile,
            accessKeyId: "AKIAIOSFODNN7EXAMPLE",
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            region: "us-east-1"
        )

        // Retrieve credentials
        let credentials = try await keychain.getAWSCredentials(profile: testProfile)

        // Verify credentials
        #expect(credentials.accessKeyId == "AKIAIOSFODNN7EXAMPLE")
        #expect(credentials.secretAccessKey == "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY")
        #expect(credentials.sessionToken == nil)
        #expect(credentials.region == "us-east-1")
        #expect(!credentials.isTemporary)
        #expect(!credentials.isPotentiallyExpired)
    }

    @Test("KeychainManager handles temporary credentials with session tokens")
    func testTemporaryCredentials() async throws {
        let logger = createTestLogger()
        let keychain = KeychainManager(logger: logger)
        let testProfile = "temp-profile-\(UUID().uuidString)"

        // Clean up will be done at the end of the test

        // Store temporary credentials
        try await keychain.storeAWSCredentials(
            profile: testProfile,
            accessKeyId: "ASIAIOSFODNN7EXAMPLE",
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            sessionToken: "IQoJb3JpZ2luX2VjEHoaCXVzLWVhc3QtMSJHMEUCIEXAMPLETOKEN",
            region: "us-west-2"
        )

        // Retrieve credentials
        let credentials = try await keychain.getAWSCredentials(profile: testProfile)

        // Verify temporary credential properties
        #expect(credentials.accessKeyId == "ASIAIOSFODNN7EXAMPLE")
        #expect(credentials.sessionToken != nil)
        #expect(credentials.isTemporary)
        #expect(credentials.region == "us-west-2")

        // Check that session token is stored correctly
        #expect(credentials.sessionToken == "IQoJb3JpZ2luX2VjEHoaCXVzLWVhc3QtMSJHMEUCIEXAMPLETOKEN")
    }

    @Test("KeychainManager updates existing credentials correctly")
    func testUpdateCredentials() async throws {
        let logger = createTestLogger()
        let keychain = KeychainManager(logger: logger)
        let testProfile = "update-profile-\(UUID().uuidString)"

        // Clean up will be done at the end of the test

        // Store initial credentials
        try await keychain.storeAWSCredentials(
            profile: testProfile,
            accessKeyId: "AKIAIOSFODNN7EXAMPLE",
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            region: "us-east-1"
        )

        // Update with new credentials
        try await keychain.storeAWSCredentials(
            profile: testProfile,
            accessKeyId: "AKIANEWKEYEXAMPLE123",
            secretAccessKey: "newSecretKey1234567890ABCDEF1234567890abc",
            region: "us-west-1"
        )

        // Verify updated credentials
        let updatedCredentials = try await keychain.getAWSCredentials(profile: testProfile)
        #expect(updatedCredentials.accessKeyId == "AKIANEWKEYEXAMPLE123")
        #expect(updatedCredentials.secretAccessKey == "newSecretKey1234567890ABCDEF1234567890abc")
        #expect(updatedCredentials.region == "us-west-1")
    }

    @Test(
        "KeychainManager removes credentials successfully",
        .disabled(if: ProcessInfo.processInfo.environment["CI"] != nil, "Keychain tests disabled in CI")
    )
    func testRemoveCredentials() async throws {
        let logger = createTestLogger()
        let keychain = KeychainManager(logger: logger)
        let testProfile = "remove-profile-\(UUID().uuidString)"

        // Store credentials
        try await keychain.storeAWSCredentials(
            profile: testProfile,
            accessKeyId: "AKIAIOSFODNN7EXAMPLE",
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        )

        // Verify credentials exist
        let _ = try await keychain.getAWSCredentials(profile: testProfile)

        // Remove credentials
        try await keychain.removeAWSCredentials(profile: testProfile)

        // Verify credentials are removed
        await #expect(throws: KeychainError.itemNotFound("com.neonlaw.brochure.aws.\(testProfile)")) {
            _ = try await keychain.getAWSCredentials(profile: testProfile)
        }
    }

    @Test("KeychainManager lists AWS profiles correctly")
    func testListAWSProfiles() async throws {
        let logger = createTestLogger()
        let keychain = KeychainManager(logger: logger)
        let testProfiles = [
            "list-test-1-\(UUID().uuidString)",
            "list-test-2-\(UUID().uuidString)",
            "list-test-3-\(UUID().uuidString)",
        ]

        // Clean up will be done at the end of the test

        // Store test profiles
        for profile in testProfiles {
            try await keychain.storeAWSCredentials(
                profile: profile,
                accessKeyId: "AKIAIOSFODNN7EXAMPLE",
                secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
            )
        }

        // List profiles
        let listedProfiles = try await keychain.listAWSProfiles()

        // Verify all test profiles are listed
        for testProfile in testProfiles {
            #expect(listedProfiles.contains(testProfile))
        }

        // Verify list contains at least our test profiles
        #expect(listedProfiles.count >= testProfiles.count)
    }

    @Test("KeychainManager handles configuration storage and retrieval")
    func testConfigurationStorage() async throws {
        let logger = createTestLogger()
        let keychain = KeychainManager(logger: logger)
        let configKey = "test-config-\(UUID().uuidString)"
        let configValue = "test-config-value-12345"

        // Clean up will be done at the end of the test

        // Store configuration
        try await keychain.storeConfiguration(key: configKey, value: configValue)

        // Retrieve configuration
        let retrievedValue = try await keychain.getConfiguration(key: configKey)
        #expect(retrievedValue == configValue)

        // Test retrieving non-existent configuration
        let nonExistentValue = try await keychain.getConfiguration(key: "non-existent-key")
        #expect(nonExistentValue == nil)

        // Remove configuration
        try await keychain.removeConfiguration(key: configKey)

        // Verify configuration is removed
        let removedValue = try await keychain.getConfiguration(key: configKey)
        #expect(removedValue == nil)
    }

    @Test("KeychainManager handles credential age calculation correctly")
    func testCredentialAgeCalculation() async throws {
        let logger = createTestLogger()
        let keychain = KeychainManager(logger: logger)
        let testProfile = "age-test-\(UUID().uuidString)"

        // Clean up will be done at the end of the test

        let startTime = Date()

        // Store credentials
        try await keychain.storeAWSCredentials(
            profile: testProfile,
            accessKeyId: "AKIAIOSFODNN7EXAMPLE",
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        )

        // Small delay to ensure measurable age
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

        // Retrieve and check age
        let credentials = try await keychain.getAWSCredentials(profile: testProfile)
        let age = credentials.age

        #expect(age >= 0.0)
        #expect(age < 5.0)  // Should be less than 5 seconds
        #expect(credentials.storedAt >= startTime)
        #expect(credentials.storedAt <= Date())
    }

    @Test(
        "KeychainManager handles invalid profile names gracefully",
        .disabled(if: ProcessInfo.processInfo.environment["CI"] != nil, "Keychain tests disabled in CI")
    )
    func testInvalidProfileHandling() async throws {
        let logger = createTestLogger()
        let keychain = KeychainManager(logger: logger)
        let invalidProfile = "non-existent-profile-\(UUID().uuidString)"

        // Test retrieving non-existent profile
        await #expect(throws: KeychainError.itemNotFound("com.neonlaw.brochure.aws.\(invalidProfile)")) {
            _ = try await keychain.getAWSCredentials(profile: invalidProfile)
        }

        // Test removing non-existent profile (should not throw)
        try await keychain.removeAWSCredentials(profile: invalidProfile)
    }

    @Test("AWSCredentials calculates expiration correctly")
    func testCredentialExpirationLogic() {
        // Test permanent credentials
        let permanentCredentials = AWSCredentials(
            accessKeyId: "AKIAIOSFODNN7EXAMPLE",
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            sessionToken: nil,
            region: "us-east-1",
            storedAt: Date()
        )

        #expect(!permanentCredentials.isTemporary)
        #expect(!permanentCredentials.isPotentiallyExpired)

        // Test fresh temporary credentials
        let freshTemporaryCredentials = AWSCredentials(
            accessKeyId: "ASIAIOSFODNN7EXAMPLE",
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            sessionToken: "IQoJb3JpZ2luX2VjEHoaCXVzLWVhc3QtMSJHMEUCIEXAMPLETOKEN",
            region: "us-east-1",
            storedAt: Date()
        )

        #expect(freshTemporaryCredentials.isTemporary)
        #expect(!freshTemporaryCredentials.isPotentiallyExpired)

        // Test old temporary credentials (simulate 2 hours old)
        let oldDate = Date(timeIntervalSinceNow: -7200)  // 2 hours ago
        let oldTemporaryCredentials = AWSCredentials(
            accessKeyId: "ASIAIOSFODNN7EXAMPLE",
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            sessionToken: "IQoJb3JpZ2luX2VjEHoaCXVzLWVhc3QtMSJHMEUCIEXAMPLETOKEN",
            region: "us-east-1",
            storedAt: oldDate
        )

        #expect(oldTemporaryCredentials.isTemporary)
        #expect(oldTemporaryCredentials.isPotentiallyExpired)
        #expect(oldTemporaryCredentials.age > 3600)  // Greater than 1 hour
    }

    @Test("KeychainError provides meaningful error descriptions")
    func testKeychainErrorMessages() {
        // Test storage failed error
        let storageError = KeychainError.storageFailed(-25300)
        #expect(storageError.errorDescription?.contains("Failed to store") == true)
        #expect(storageError.errorDescription?.contains("-25300") == true)

        // Test item not found error
        let notFoundError = KeychainError.itemNotFound("test-account")
        #expect(notFoundError.errorDescription?.contains("not found") == true)
        #expect(notFoundError.errorDescription?.contains("test-account") == true)

        // Test invalid data error
        let invalidDataError = KeychainError.invalidData("corrupted data")
        #expect(invalidDataError.errorDescription?.contains("Invalid keychain data") == true)
        #expect(invalidDataError.errorDescription?.contains("corrupted data") == true)

        // Test user-friendly descriptions
        let userFriendlyDescription = storageError.userFriendlyDescription
        #expect(userFriendlyDescription.contains("Failed to securely store") == true)
        #expect(userFriendlyDescription.contains("keychain is unlocked") == true)
    }
}

// MARK: - Supporting Types

/// Creates a test logger for testing purposes.
private func createTestLogger() -> Logger {
    var logger = Logger(label: "KeychainTest")
    logger.logLevel = .critical  // Suppress logs during testing
    return logger
}
