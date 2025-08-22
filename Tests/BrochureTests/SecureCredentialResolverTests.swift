import Foundation
import Logging
import Testing

@testable import Brochure

/// Tests for secure credential resolution with keychain integration.
///
/// These tests verify the SecureCredentialResolver's ability to integrate keychain
/// credentials with traditional AWS credential sources and provide secure credential
/// resolution with proper fallback mechanisms.
@Suite("SecureCredentialResolver Tests")
struct SecureCredentialResolverTests {

    @Test("SecureCredentialResolver initializes correctly")
    func testSecureCredentialResolverInitialization() async throws {
        let logger = createTestLogger()
        let keychainManager = KeychainManager(logger: logger)
        let _ = SecureCredentialResolver(
            keychainManager: keychainManager,
            logger: logger
        )

        // Should initialize without errors
        // Note: We test functionality through method calls since internal state is private
    }

    @Test("SecureCredentialResolver resolves keychain credentials when available")
    func testKeychainCredentialResolution() async throws {
        let logger = createTestLogger()
        let keychainManager = KeychainManager(logger: logger)
        let resolver = SecureCredentialResolver(
            keychainManager: keychainManager,
            logger: logger
        )

        let testProfile = "keychain-test-\(UUID().uuidString)"

        // Store secure credentials
        try await resolver.storeSecureCredentials(
            profile: testProfile,
            accessKeyId: "AKIAIOSFODNN7EXAMPLE",
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            region: "us-east-1"
        )

        // Resolve credentials with keychain enabled
        let resolution = await resolver.resolveSecureCredentials(
            explicit: testProfile,
            environment: [:],
            enableKeychain: true
        )

        // Verify keychain resolution
        #expect(resolution.profileName == testProfile)
        #expect(resolution.securityLevel == .high)

        switch resolution.source {
        case .keychain:
            break  // Expected
        case .traditional:
            #expect(Bool(false), "Expected keychain source, got traditional")
        }

        #expect(resolution.credentials != nil)
        #expect(resolution.credentials?.accessKeyId == "AKIAIOSFODNN7EXAMPLE")
        #expect(resolution.region == "us-east-1")

        // Cleanup
        try? await resolver.removeSecureCredentials(profile: testProfile)
    }

    @Test("SecureCredentialResolver falls back to traditional credentials when keychain unavailable")
    func testTraditionalCredentialFallback() async throws {
        let logger = createTestLogger()
        let keychainManager = KeychainManager(logger: logger)
        let resolver = SecureCredentialResolver(
            keychainManager: keychainManager,
            logger: logger
        )

        // Resolve with non-existent profile (should fall back to traditional)
        let environment = [
            "AWS_PROFILE": "non-existent-profile",
            "AWS_REGION": "us-west-2",
        ]

        let resolution = await resolver.resolveSecureCredentials(
            explicit: nil,
            environment: environment,
            enableKeychain: true
        )

        // Verify traditional fallback
        #expect(resolution.profileName == "non-existent-profile")
        #expect(resolution.securityLevel == .standard)
        #expect(resolution.region == "us-west-2")

        switch resolution.source {
        case .keychain:
            #expect(Bool(false), "Expected traditional source, got keychain")
        case .traditional(let source):
            #expect(source == .environment)
        }

        #expect(resolution.credentials == nil)  // No keychain credentials
    }

    @Test("SecureCredentialResolver handles keychain disabled correctly")
    func testKeychainDisabled() async throws {
        let logger = createTestLogger()
        let keychainManager = KeychainManager(logger: logger)
        let resolver = SecureCredentialResolver(
            keychainManager: keychainManager,
            logger: logger
        )

        let testProfile = "disabled-test-\(UUID().uuidString)"

        // Store keychain credentials
        try await resolver.storeSecureCredentials(
            profile: testProfile,
            accessKeyId: "AKIAIOSFODNN7EXAMPLE",
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        )

        // Resolve with keychain disabled
        let resolution = await resolver.resolveSecureCredentials(
            explicit: testProfile,
            environment: [:],
            enableKeychain: false
        )

        // Should use traditional resolution even though keychain credentials exist
        switch resolution.source {
        case .keychain:
            #expect(Bool(false), "Expected traditional source when keychain disabled")
        case .traditional:
            break  // Expected
        }

        #expect(resolution.credentials == nil)  // No keychain credentials when disabled

        // Cleanup
        try? await resolver.removeSecureCredentials(profile: testProfile)
    }

    @Test("SecureCredentialResolver stores and retrieves temporary credentials correctly")
    func testTemporaryCredentialHandling() async throws {
        let logger = createTestLogger()
        let keychainManager = KeychainManager(logger: logger)
        let resolver = SecureCredentialResolver(
            keychainManager: keychainManager,
            logger: logger
        )

        let testProfile = "temp-test-\(UUID().uuidString)"

        // Store temporary credentials
        try await resolver.storeSecureCredentials(
            profile: testProfile,
            accessKeyId: "ASIAIOSFODNN7EXAMPLE",
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            sessionToken: "IQoJb3JpZ2luX2VjEHoaCXVzLWVhc3QtMSJHMEUCIEXAMPLETOKEN",
            region: "us-east-1"
        )

        // Retrieve credentials directly
        let credentials = try await resolver.getSecureCredentials(profile: testProfile)

        // Verify temporary credential properties
        #expect(credentials.isTemporary)
        #expect(credentials.sessionToken != nil)
        #expect(!credentials.isPotentiallyExpired)  // Should be fresh

        // Resolve through secure resolution
        let resolution = await resolver.resolveSecureCredentials(
            explicit: testProfile,
            environment: [:],
            enableKeychain: true
        )

        #expect(resolution.securityLevel == .enhanced)  // Enhanced for temporary credentials
        #expect(resolution.credentials?.isTemporary == true)

        // Cleanup
        try? await resolver.removeSecureCredentials(profile: testProfile)
    }

    @Test("SecureCredentialResolver lists secure profiles with metadata")
    func testListSecureProfiles() async throws {
        let logger = createTestLogger()
        let keychainManager = KeychainManager(logger: logger)
        let resolver = SecureCredentialResolver(
            keychainManager: keychainManager,
            logger: logger
        )

        let testProfiles = [
            "list-secure-1-\(UUID().uuidString)",
            "list-secure-2-\(UUID().uuidString)",
        ]

        // Store test profiles with different configurations
        try await resolver.storeSecureCredentials(
            profile: testProfiles[0],
            accessKeyId: "AKIAIOSFODNN7EXAMPLE",
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            region: "us-east-1"
        )

        try await resolver.storeSecureCredentials(
            profile: testProfiles[1],
            accessKeyId: "ASIAIOSFODNN7EXAMPLE",
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            sessionToken: "IQoJb3JpZ2luX2VjEHoaCXVzLWVhc3QtMSJHMEUCIEXAMPLETOKEN",
            region: "us-west-2"
        )

        // List profiles
        let profiles = try await resolver.listSecureProfiles()

        // Find our test profiles
        let testProfileInfos = profiles.filter { testProfiles.contains($0.name) }
        #expect(testProfileInfos.count == 2)

        // Verify profile metadata
        for profileInfo in testProfileInfos {
            #expect(profileInfo.name.starts(with: "list-secure-"))
            #expect(profileInfo.securityStatus.contains("🔐") || profileInfo.securityStatus.contains("🔑"))
            #expect(profileInfo.ageDescription.contains("Created"))

            if profileInfo.name == testProfiles[1] {
                #expect(profileInfo.isTemporary)
            } else {
                #expect(!profileInfo.isTemporary)
            }
        }

        // Cleanup test profiles
        for profile in testProfiles {
            try? await resolver.removeSecureCredentials(profile: profile)
        }
    }

    @Test(
        "SecureCredentialResolver handles credential removal correctly",
        .disabled(if: ProcessInfo.processInfo.environment["CI"] != nil, "Keychain tests disabled in CI")
    )
    func testCredentialRemoval() async throws {
        let logger = createTestLogger()
        let keychainManager = KeychainManager(logger: logger)
        let resolver = SecureCredentialResolver(
            keychainManager: keychainManager,
            logger: logger
        )

        let testProfile = "remove-secure-\(UUID().uuidString)"

        // Store credentials
        try await resolver.storeSecureCredentials(
            profile: testProfile,
            accessKeyId: "AKIAIOSFODNN7EXAMPLE",
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        )

        // Verify credentials exist
        let _ = try await resolver.getSecureCredentials(profile: testProfile)

        // Remove credentials
        try await resolver.removeSecureCredentials(profile: testProfile)

        // Verify credentials are removed
        await #expect(throws: KeychainError.itemNotFound("com.neonlaw.brochure.aws.\(testProfile)")) {
            _ = try await resolver.getSecureCredentials(profile: testProfile)
        }

        // Verify profile is removed from list
        let profiles = try await resolver.listSecureProfiles()
        let remainingTestProfiles = profiles.filter { $0.name == testProfile }
        #expect(remainingTestProfiles.isEmpty)
    }

    @Test("SecureProfileInfo provides correct metadata")
    func testSecureProfileInfoMetadata() {
        let now = Date()
        let oneHourAgo = Date(timeIntervalSinceNow: -3600)
        let oneDayAgo = Date(timeIntervalSinceNow: -86400)
        let oneWeekAgo = Date(timeIntervalSinceNow: -604800)
        let oneMonthAgo = Date(timeIntervalSinceNow: -2_592_000)

        // Test recent profile
        let recentProfile = SecureProfileInfo(
            name: "recent-test",
            region: "us-east-1",
            isTemporary: false,
            securityLevel: "high",
            createdAt: now,
            lastAccessed: now,
            isPotentiallyExpired: false
        )

        #expect(recentProfile.securityStatus == "🔐 Secure Storage")
        #expect(recentProfile.ageDescription == "Created today")

        // Test temporary expired profile
        let expiredTempProfile = SecureProfileInfo(
            name: "expired-test",
            region: "us-west-2",
            isTemporary: true,
            securityLevel: "enhanced",
            createdAt: oneHourAgo,
            lastAccessed: oneHourAgo,
            isPotentiallyExpired: true
        )

        #expect(expiredTempProfile.securityStatus == "⚠️ Potentially Expired")

        // Test age descriptions
        let oneDayProfile = SecureProfileInfo(
            name: "day-test",
            region: nil,
            isTemporary: false,
            securityLevel: "high",
            createdAt: oneDayAgo,
            lastAccessed: oneDayAgo,
            isPotentiallyExpired: false
        )

        #expect(oneDayProfile.ageDescription == "Created yesterday")

        let oneWeekProfile = SecureProfileInfo(
            name: "week-test",
            region: nil,
            isTemporary: false,
            securityLevel: "high",
            createdAt: oneWeekAgo,
            lastAccessed: oneWeekAgo,
            isPotentiallyExpired: false
        )

        #expect(oneWeekProfile.ageDescription == "Created 1 weeks ago")

        let oneMonthProfile = SecureProfileInfo(
            name: "month-test",
            region: nil,
            isTemporary: false,
            securityLevel: "high",
            createdAt: oneMonthAgo,
            lastAccessed: oneMonthAgo,
            isPotentiallyExpired: false
        )

        #expect(oneMonthProfile.ageDescription == "Created 1 months ago")
    }

    @Test("SecurityLevel enum provides correct values")
    func testSecurityLevels() {
        #expect(SecurityLevel.high.rawValue == "high")
        #expect(SecurityLevel.enhanced.rawValue == "enhanced")
        #expect(SecurityLevel.standard.rawValue == "standard")
        #expect(SecurityLevel.low.rawValue == "low")
    }

    @Test("SecureCredentialSource enum handles different sources")
    func testCredentialSources() {
        let keychainSource = SecureCredentialSource.keychain
        let traditionalExplicitSource = SecureCredentialSource.traditional(.explicit)
        let _ = SecureCredentialSource.traditional(.environment)
        let _ = SecureCredentialSource.traditional(.defaultChain)

        // Test that sources can be created and compared
        switch keychainSource {
        case .keychain:
            break  // Expected
        case .traditional:
            #expect(Bool(false), "Expected keychain source")
        }

        switch traditionalExplicitSource {
        case .keychain:
            #expect(Bool(false), "Expected traditional source")
        case .traditional(let profileSource):
            #expect(profileSource == .explicit)
        }
    }
}

// MARK: - Supporting Types

/// Creates a test logger for testing purposes.
private func createTestLogger() -> Logger {
    var logger = Logger(label: "SecureCredentialTest")
    logger.logLevel = .critical  // Suppress logs during testing
    return logger
}
