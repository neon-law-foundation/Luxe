import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// URLSession mocking utilities for test environments
///
/// This class provides convenient methods to integrate ExternalServiceMocker
/// with existing URLSession-based test code, allowing for minimal changes to
/// existing test implementations.
public final class URLSessionTestMocker {

    /// Shared external service mocker instance for tests
    @MainActor
    public static let testMocker = ExternalServiceMocker()

    /// Performs a data task with optional mocking based on test environment
    ///
    /// This method first attempts to use the test mocker if available,
    /// falling back to the real URLSession if mocking is disabled or
    /// no mock is registered for the URL.
    ///
    /// - Parameter url: The URL to fetch
    /// - Returns: Data and URLResponse tuple
    /// - Throws: Network or mocking errors
    @MainActor
    public static func testCompatibleData(from url: URL) async throws -> (Data, URLResponse) {
        // Check if we're in a test environment
        let isTestEnvironment =
            ProcessInfo.processInfo.environment["SWIFT_TESTING"] != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        if isTestEnvironment && testMocker.configuration.isEnabled {
            do {
                return try await testMocker.mockURLSessionRequest(for: url)
            } catch ExternalServiceMockerError.noMockRegistered {
                // Fall back to real request if no mock is registered
                if testMocker.configuration.enableLogging {
                    print("🔄 [URLSession] Falling back to real request for: \(url)")
                }
                return try await URLSession.shared.data(from: url)
            }
        }

        // Use real URLSession for non-test environments or when mocking is disabled
        return try await URLSession.shared.data(from: url)
    }

    /// Performs a data task with optional mocking for URLRequest
    ///
    /// - Parameter request: The URLRequest to perform
    /// - Returns: Data and URLResponse tuple
    /// - Throws: Network or mocking errors
    @MainActor
    public static func testCompatibleData(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url else {
            throw ExternalServiceMockerError.invalidRequest("URLRequest has no URL")
        }

        return try await testCompatibleData(from: url)
    }
}

/// URLSession extension that delegates to URLSessionTestMocker for Linux compatibility
///
/// This extension provides a bridge to URLSessionTestMocker methods to maintain API compatibility
extension URLSession {

    /// Shared external service mocker instance for tests
    @MainActor
    public static var testMocker: ExternalServiceMocker {
        URLSessionTestMocker.testMocker
    }

    /// Performs a data task with optional mocking based on test environment
    @MainActor
    public static func testCompatibleData(from url: URL) async throws -> (Data, URLResponse) {
        try await URLSessionTestMocker.testCompatibleData(from: url)
    }

    /// Performs a data task with optional mocking for URLRequest
    @MainActor
    public static func testCompatibleData(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await URLSessionTestMocker.testCompatibleData(for: request)
    }
}

/// Test utilities for setting up external service mocks
public struct ExternalServiceTestUtilities {

    /// Sets up standard mocks for common test scenarios
    ///
    /// This is a convenience method that registers commonly needed mocks
    /// for external services used across different test suites.
    @MainActor
    public static func setupStandardMocks() {
        let mocker = URLSessionTestMocker.testMocker

        // Clear any existing mocks
        mocker.clearMocks()

        // Register website mocks for integration tests
        mocker.registerWebsiteMocks()

        // Register common API mocks
        mocker.registerCommonAPIMocks()

        // Register additional service-specific mocks
        setupDocketAlarmMock(mocker)
        setupHealthCheckMocks(mocker)

        if mocker.configuration.enableLogging {
            print("✅ [ExternalServiceTestUtilities] Standard mocks configured")
        }
    }

    /// Clears all registered mocks
    @MainActor
    public static func clearMocks() {
        URLSessionTestMocker.testMocker.clearMocks()
    }

    /// Sets up Docket Alarm API mock (integrates with existing RebelAI mock)
    private static func setupDocketAlarmMock(_ mocker: ExternalServiceMocker) {
        mocker.registerMock(
            for: .urlPattern("https://www.docketalarm.com/api/*"),
            response: .success(
                content:
                    #"{"error": "Mock API response - use mockSearchDocketAlarmCases() instead", "success": false}"#,
                statusCode: 200,
                headers: ["Content-Type": "application/json"]
            )
        )
    }

    /// Sets up health check endpoint mocks
    private static func setupHealthCheckMocks(_ mocker: ExternalServiceMocker) {
        let healthResponse =
            #"{"status": "ok", "service": "mock", "timestamp": "\#(ISO8601DateFormatter().string(from: Date()))"}"#

        // Common health check patterns
        let healthPatterns = [
            "*/health",
            "*/health/check",
            "*/status",
            "*/ping",
        ]

        for pattern in healthPatterns {
            mocker.registerMock(
                for: .urlPattern("https://\(pattern)"),
                response: .success(
                    content: healthResponse,
                    headers: ["Content-Type": "application/json"]
                )
            )
        }
    }
}

/// Test-specific URLSession configuration
extension ExternalServiceMocker.Configuration {

    /// Configuration optimized for fast test execution
    @MainActor
    public static let fastTests = ExternalServiceMocker.Configuration(
        isEnabled: true,
        defaultDelay: 0.01,  // Very fast for unit tests
        enableLogging: false
    )

    /// Configuration for integration tests with realistic delays
    @MainActor
    public static let integrationTests = ExternalServiceMocker.Configuration(
        isEnabled: true,
        defaultDelay: 0.1,  // Slightly more realistic
        enableLogging: false
    )

    /// Configuration for debugging test issues
    @MainActor
    public static let debug = ExternalServiceMocker.Configuration(
        isEnabled: true,
        defaultDelay: 0.05,
        enableLogging: true  // Enable logging for debugging
    )
}
