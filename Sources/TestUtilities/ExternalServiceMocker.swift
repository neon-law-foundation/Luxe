import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Configurable framework for mocking external services in tests
///
/// This framework provides a unified approach to mocking various external services,
/// enabling tests to run in isolation without dependencies on external APIs,
/// websites, or network services.
///
/// ## Features
/// - URL pattern-based request matching
/// - Configurable response templates
/// - HTTP status code and header simulation
/// - Delay simulation for realistic testing
/// - Environment-based configuration
///
/// ## Usage
///
/// ### Basic Setup
/// ```swift
/// let mocker = ExternalServiceMocker()
/// mocker.registerMock(
///     for: .urlPattern("https://api.example.com/*"),
///     response: .success(data: mockData, statusCode: 200)
/// )
/// ```
///
/// ### Website Validation Mock
/// ```swift
/// mocker.registerWebsiteMocks()
/// let response = try await mocker.mockURLSessionRequest(for: URL(string: "https://www.neonlaw.com")!)
/// ```
public final class ExternalServiceMocker: @unchecked Sendable {

    /// Configuration for service mocking behavior
    public struct Configuration: Sendable {
        /// Whether mocking is enabled (can be controlled by environment variables)
        let isEnabled: Bool

        /// Default delay for simulated network requests
        let defaultDelay: TimeInterval

        /// Whether to log mock interactions for debugging
        let enableLogging: Bool

        public init(
            isEnabled: Bool = true,
            defaultDelay: TimeInterval = 0.1,
            enableLogging: Bool = false
        ) {
            self.isEnabled = isEnabled
            self.defaultDelay = defaultDelay
            self.enableLogging = enableLogging
        }

        /// Creates configuration from environment variables
        public static func fromEnvironment() -> Configuration {
            let isEnabled = ProcessInfo.processInfo.environment["MOCK_EXTERNAL_SERVICES"] != "false"
            let defaultDelay =
                ProcessInfo.processInfo.environment["MOCK_DELAY"]
                .flatMap { Double($0) } ?? 0.1
            let enableLogging = ProcessInfo.processInfo.environment["MOCK_LOGGING"] == "true"

            return Configuration(
                isEnabled: isEnabled,
                defaultDelay: defaultDelay,
                enableLogging: enableLogging
            )
        }
    }

    /// Request matching patterns
    public enum RequestPattern: Sendable {
        case urlPattern(String)  // Supports wildcards like "https://api.example.com/*"
        case exactURL(String)
        case domain(String)  // Matches any URL from this domain
        case custom(@Sendable (URL) -> Bool)

        /// Checks if a URL matches this pattern
        func matches(_ url: URL) -> Bool {
            switch self {
            case .urlPattern(let pattern):
                return url.absoluteString.matchesWildcardPattern(pattern)
            case .exactURL(let exactURL):
                return url.absoluteString == exactURL
            case .domain(let domain):
                return url.host?.lowercased().contains(domain.lowercased()) == true
            case .custom(let matcher):
                return matcher(url)
            }
        }
    }

    /// Mock response configuration
    public struct MockResponse: Sendable {
        let data: Data
        let statusCode: Int
        let headers: [String: String]
        let delay: TimeInterval?
        let error: Error?

        /// Creates a successful response mock
        public static func success(
            data: Data,
            statusCode: Int = 200,
            headers: [String: String] = ["Content-Type": "application/json"],
            delay: TimeInterval? = nil
        ) -> MockResponse {
            MockResponse(
                data: data,
                statusCode: statusCode,
                headers: headers,
                delay: delay,
                error: nil
            )
        }

        /// Creates a successful response with string content
        public static func success(
            content: String,
            statusCode: Int = 200,
            headers: [String: String] = ["Content-Type": "text/html"],
            delay: TimeInterval? = nil
        ) -> MockResponse {
            success(
                data: content.data(using: .utf8) ?? Data(),
                statusCode: statusCode,
                headers: headers,
                delay: delay
            )
        }

        /// Creates an error response mock
        public static func error(
            _ error: Error,
            delay: TimeInterval? = nil
        ) -> MockResponse {
            MockResponse(
                data: Data(),
                statusCode: 0,
                headers: [:],
                delay: delay,
                error: error
            )
        }

        /// Creates an HTTP error response
        public static func httpError(
            statusCode: Int,
            data: Data = Data(),
            headers: [String: String] = [:],
            delay: TimeInterval? = nil
        ) -> MockResponse {
            MockResponse(
                data: data,
                statusCode: statusCode,
                headers: headers,
                delay: delay,
                error: nil
            )
        }
    }

    /// Registered mock configurations
    private var registeredMocks: [(RequestPattern, MockResponse)] = []

    /// Configuration for the mocker
    public let configuration: Configuration

    /// Creates a new external service mocker with the given configuration
    public init(configuration: Configuration = .fromEnvironment()) {
        self.configuration = configuration
    }

    /// Registers a mock response for requests matching the given pattern
    public func registerMock(for pattern: RequestPattern, response: MockResponse) {
        registeredMocks.append((pattern, response))

        if configuration.enableLogging {
            print("🔧 [ExternalServiceMocker] Registered mock for pattern: \(pattern)")
        }
    }

    /// Removes all registered mocks
    public func clearMocks() {
        registeredMocks.removeAll()

        if configuration.enableLogging {
            print("🧹 [ExternalServiceMocker] Cleared all registered mocks")
        }
    }

    /// Finds a mock response for the given URL
    private func findMockResponse(for url: URL) -> MockResponse? {
        // Search in reverse order so last registered mock wins
        for (pattern, response) in registeredMocks.reversed() {
            if pattern.matches(url) {
                return response
            }
        }
        return nil
    }

    /// Performs a mocked URLSession request
    ///
    /// This method simulates a URLSession.shared.data(for:) call using registered mocks.
    /// If no mock is found, it will either throw an error or perform the real request
    /// depending on configuration.
    public func mockURLSessionRequest(for url: URL) async throws -> (Data, URLResponse) {
        guard configuration.isEnabled else {
            // If mocking is disabled, perform real request
            let (data, response) = try await URLSession.shared.data(from: url)
            return (data, response)
        }

        guard let mockResponse = findMockResponse(for: url) else {
            if configuration.enableLogging {
                print("⚠️ [ExternalServiceMocker] No mock found for URL: \(url)")
            }
            throw ExternalServiceMockerError.noMockRegistered(url: url.absoluteString)
        }

        if configuration.enableLogging {
            print("✅ [ExternalServiceMocker] Using mock for URL: \(url)")
        }

        // Simulate network delay
        let delay = mockResponse.delay ?? configuration.defaultDelay
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        // Throw error if mock is configured for error
        if let error = mockResponse.error {
            throw error
        }

        // Create mock URLResponse
        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: mockResponse.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: mockResponse.headers
        )!

        return (mockResponse.data, httpResponse)
    }

    /// Performs a mocked URLRequest
    public func mockURLSessionRequest(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url else {
            throw ExternalServiceMockerError.invalidRequest("Request has no URL")
        }

        return try await mockURLSessionRequest(for: url)
    }
}

// MARK: - Predefined Mock Collections

extension ExternalServiceMocker {

    /// Registers common website mocks for integration testing
    public func registerWebsiteMocks() {
        let websites = [
            "https://www.neonlaw.com",
            "https://www.neonlaw.org",
            "https://www.hoshihoshi.app",
            "https://www.tarotswift.me",
            "https://www.1337lawyers.com",
        ]

        for websiteURL in websites {
            registerMock(
                for: .exactURL(websiteURL),
                response: .success(
                    content: createMockHTMLResponse(for: websiteURL),
                    statusCode: 200,
                    headers: [
                        "Content-Type": "text/html; charset=utf-8",
                        "Server": "MockServer/1.0",
                    ]
                )
            )
        }

        if configuration.enableLogging {
            print("🌐 [ExternalServiceMocker] Registered mocks for \(websites.count) websites")
        }
    }

    /// Creates a mock HTML response for a website
    private func createMockHTMLResponse(for url: String) -> String {
        let domain = URL(string: url)?.host ?? "example.com"
        return """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Mock Response - \(domain)</title>
            </head>
            <body>
                <h1>Mock Website Response</h1>
                <p>This is a mocked response for \(url)</p>
                <p>Generated by ExternalServiceMocker for testing purposes.</p>
                <footer>
                    <p>Mock Server - Test Environment</p>
                </footer>
            </body>
            </html>
            """
    }

    /// Registers API endpoint mocks commonly needed for testing
    public func registerCommonAPIMocks() {
        // Generic API success response
        registerMock(
            for: .urlPattern("https://api.*/health"),
            response: .success(
                content: #"{"status": "ok", "timestamp": "\#(ISO8601DateFormatter().string(from: Date()))"}"#,
                headers: ["Content-Type": "application/json"]
            )
        )

        // Generic API endpoints that should return empty arrays
        registerMock(
            for: .urlPattern("https://api.*/v*/users"),
            response: .success(
                content: "[]",
                headers: ["Content-Type": "application/json"]
            )
        )

        if configuration.enableLogging {
            print("🔌 [ExternalServiceMocker] Registered common API mocks")
        }
    }
}

// MARK: - Errors

public enum ExternalServiceMockerError: Error, LocalizedError {
    case noMockRegistered(url: String)
    case invalidRequest(String)
    case mockingDisabled

    public var errorDescription: String? {
        switch self {
        case .noMockRegistered(let url):
            return "No mock registered for URL: \(url)"
        case .invalidRequest(let message):
            return "Invalid request: \(message)"
        case .mockingDisabled:
            return "External service mocking is disabled"
        }
    }
}

// MARK: - String Extensions

extension String {
    /// Checks if string matches a wildcard pattern (supports * wildcards)
    fileprivate func matchesWildcardPattern(_ pattern: String) -> Bool {
        let regexPattern =
            pattern
            .replacingOccurrences(of: "*", with: ".*")
            .replacingOccurrences(of: "?", with: ".")

        guard let regex = try? NSRegularExpression(pattern: "^" + regexPattern + "$", options: []) else {
            return false
        }

        let range = NSRange(location: 0, length: self.count)
        return regex.firstMatch(in: self, options: [], range: range) != nil
    }
}
