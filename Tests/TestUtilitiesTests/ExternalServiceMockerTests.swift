import Foundation
import Testing

@testable import TestUtilities

@Suite("External Service Mocker Tests")
struct ExternalServiceMockerTests {

    @Test("ExternalServiceMocker can register and match URL patterns")
    @MainActor
    func testURLPatternMatching() async throws {
        let mocker = ExternalServiceMocker(configuration: .fastTests)

        // Register mock for API pattern
        mocker.registerMock(
            for: .urlPattern("https://api.example.com/*"),
            response: .success(content: "API Response", statusCode: 200)
        )

        // Test exact URL matching
        mocker.registerMock(
            for: .exactURL("https://www.neonlaw.com"),
            response: .success(content: "Neon Law Homepage", statusCode: 200)
        )

        // Test domain matching
        mocker.registerMock(
            for: .domain("github.com"),
            response: .success(content: "GitHub Mock", statusCode: 200)
        )

        // Test API pattern match
        let apiURL = URL(string: "https://api.example.com/users/123")!
        let (apiData, apiResponse) = try await mocker.mockURLSessionRequest(for: apiURL)
        let apiContent = String(data: apiData, encoding: .utf8)

        #expect(apiContent == "API Response")
        #expect((apiResponse as? HTTPURLResponse)?.statusCode == 200)

        // Test exact URL match
        let neonlawURL = URL(string: "https://www.neonlaw.com")!
        let (neonlawData, neonlawResponse) = try await mocker.mockURLSessionRequest(for: neonlawURL)
        let neonlawContent = String(data: neonlawData, encoding: .utf8)

        #expect(neonlawContent == "Neon Law Homepage")
        #expect((neonlawResponse as? HTTPURLResponse)?.statusCode == 200)

        // Test domain match
        let githubURL = URL(string: "https://github.com/user/repo")!
        let (githubData, githubResponse) = try await mocker.mockURLSessionRequest(for: githubURL)
        let githubContent = String(data: githubData, encoding: .utf8)

        #expect(githubContent == "GitHub Mock")
        #expect((githubResponse as? HTTPURLResponse)?.statusCode == 200)
    }

    @Test("ExternalServiceMocker handles error responses correctly")
    @MainActor
    func testErrorResponses() async throws {
        let mocker = ExternalServiceMocker(configuration: .fastTests)

        // Register HTTP error mock
        mocker.registerMock(
            for: .exactURL("https://api.example.com/error"),
            response: .httpError(statusCode: 404, data: "Not Found".data(using: .utf8)!)
        )

        // Register network error mock
        enum MockError: Error {
            case networkFailure
        }

        mocker.registerMock(
            for: .exactURL("https://api.example.com/network-error"),
            response: .error(MockError.networkFailure)
        )

        // Test HTTP error
        let errorURL = URL(string: "https://api.example.com/error")!
        let (errorData, errorResponse) = try await mocker.mockURLSessionRequest(for: errorURL)
        let errorContent = String(data: errorData, encoding: .utf8)

        #expect(errorContent == "Not Found")
        #expect((errorResponse as? HTTPURLResponse)?.statusCode == 404)

        // Test network error
        let networkErrorURL = URL(string: "https://api.example.com/network-error")!

        await #expect(throws: MockError.networkFailure) {
            try await mocker.mockURLSessionRequest(for: networkErrorURL)
        }
    }

    @Test("ExternalServiceMocker respects delay configuration")
    @MainActor
    func testDelayConfiguration() async throws {
        let mocker = ExternalServiceMocker(
            configuration: ExternalServiceMocker.Configuration(
                isEnabled: true,
                defaultDelay: 0.05,
                enableLogging: false
            )
        )

        mocker.registerMock(
            for: .exactURL("https://slow.example.com"),
            response: .success(content: "Slow response", delay: 0.1)
        )

        let slowURL = URL(string: "https://slow.example.com")!
        let startTime = Date()

        let (data, response) = try await mocker.mockURLSessionRequest(for: slowURL)

        let elapsed = Date().timeIntervalSince(startTime)
        let content = String(data: data, encoding: .utf8)

        #expect(content == "Slow response")
        #expect(elapsed >= 0.1)  // Should take at least the configured delay
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
    }

    @Test("ExternalServiceMocker website mocks work correctly")
    @MainActor
    func testWebsiteMocks() async throws {
        let mocker = ExternalServiceMocker(configuration: .fastTests)
        mocker.registerWebsiteMocks()

        let testWebsites = [
            "https://www.neonlaw.com",
            "https://www.neonlaw.org",
            "https://www.hoshihoshi.app",
        ]

        for websiteURL in testWebsites {
            let url = URL(string: websiteURL)!
            let (data, response) = try await mocker.mockURLSessionRequest(for: url)
            let content = String(data: data, encoding: .utf8)

            #expect(content?.contains("Mock Website Response") == true)
            #expect(content?.contains(websiteURL) == true)
            #expect((response as? HTTPURLResponse)?.statusCode == 200)

            // Verify HTML structure
            #expect(content?.contains("<!DOCTYPE html>") == true)
            #expect(content?.contains("<title>") == true)
        }
    }

    @Test("ExternalServiceMocker throws error for unregistered URLs")
    @MainActor
    func testUnregisteredURLError() async throws {
        let mocker = ExternalServiceMocker(configuration: .fastTests)

        let unregisteredURL = URL(string: "https://unknown.example.com")!

        await #expect(throws: ExternalServiceMockerError.noMockRegistered(url: "https://unknown.example.com")) {
            try await mocker.mockURLSessionRequest(for: unregisteredURL)
        }
    }

    @Test("ExternalServiceTestUtilities setupStandardMocks works")
    @MainActor
    func testStandardMocksSetup() async throws {
        // Setup standard mocks
        ExternalServiceTestUtilities.setupStandardMocks()

        // Test website mock
        let neonlawURL = URL(string: "https://www.neonlaw.com")!
        let (websiteData, websiteResponse) = try await URLSession.testMocker.mockURLSessionRequest(for: neonlawURL)
        let websiteContent = String(data: websiteData, encoding: .utf8)

        #expect(websiteContent?.contains("Mock Website Response") == true)
        #expect((websiteResponse as? HTTPURLResponse)?.statusCode == 200)

        // Test API health check mock
        let healthURL = URL(string: "https://api.example.com/health")!
        let (healthData, healthResponse) = try await URLSession.testMocker.mockURLSessionRequest(for: healthURL)
        let healthContent = String(data: healthData, encoding: .utf8)

        #expect(healthContent?.contains("\"status\": \"ok\"") == true)
        #expect((healthResponse as? HTTPURLResponse)?.statusCode == 200)

        // Clean up
        ExternalServiceTestUtilities.clearMocks()
    }

    @Test("URLSession.testCompatibleData integrates with mocker")
    @MainActor
    func testURLSessionIntegration() async throws {
        // Setup a mock
        URLSession.testMocker.registerMock(
            for: .exactURL("https://integration.test.com"),
            response: .success(content: "Integration test response")
        )

        let testURL = URL(string: "https://integration.test.com")!
        let (data, response) = try await URLSession.testCompatibleData(from: testURL)
        let content = String(data: data, encoding: .utf8)

        #expect(content == "Integration test response")
        #expect((response as? HTTPURLResponse)?.statusCode == 200)

        // Clean up
        URLSession.testMocker.clearMocks()
    }

    @Test("Wildcard pattern matching works correctly")
    @MainActor
    func testWildcardPatternMatching() async throws {
        let mocker = ExternalServiceMocker(configuration: .fastTests)

        mocker.registerMock(
            for: .urlPattern("https://*.github.com/*"),
            response: .success(content: "GitHub wildcard match")
        )

        let testURLs = [
            "https://api.github.com/users/octocat",
            "https://raw.github.com/user/repo/main/README.md",
            "https://uploads.github.com/repos/user/repo/releases",
        ]

        for urlString in testURLs {
            let url = URL(string: urlString)!
            let (data, response) = try await mocker.mockURLSessionRequest(for: url)
            let content = String(data: data, encoding: .utf8)

            #expect(content == "GitHub wildcard match")
            #expect((response as? HTTPURLResponse)?.statusCode == 200)
        }
    }
}
