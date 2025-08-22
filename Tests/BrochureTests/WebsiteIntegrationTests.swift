import Foundation
import Testing

@testable import Brochure
@testable import TestUtilities

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// import WebDriver

@Suite("Website Integration Tests")
struct WebsiteIntegrationTests {

    private static let websites = [
        ("Neon Law", "https://www.neonlaw.com"),
        ("Neon Law Foundation", "https://www.neonlaw.org"),
        ("Hoshi Hoshi", "https://www.hoshihoshi.app"),
        ("Tarot Swift", "https://www.tarotswift.me"),
        ("1337 Lawyers", "https://www.1337lawyers.com"),
    ]

    @Test("Neon Law website responds successfully", .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil))
    @MainActor
    func neonLawWebsiteResponds() async throws {
        try await validateWebsiteWithURLSession(name: "Neon Law", url: "https://www.neonlaw.com")
    }

    @Test(
        "Neon Law Foundation website responds successfully",
        .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil)
    )
    @MainActor
    func neonLawFoundationWebsiteResponds() async throws {
        try await validateWebsiteWithURLSession(name: "Neon Law Foundation", url: "https://www.neonlaw.org")
    }

    @Test("Hoshi Hoshi website responds successfully", .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil))
    @MainActor
    func hoshiHoshiWebsiteResponds() async throws {
        try await validateWebsiteWithURLSession(name: "Hoshi Hoshi", url: "https://www.hoshihoshi.app")
    }

    @Test("Tarot Swift website responds successfully", .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil))
    @MainActor
    func tarotSwiftWebsiteResponds() async throws {
        try await validateWebsiteWithURLSession(name: "Tarot Swift", url: "https://www.tarotswift.me")
    }

    @Test(
        "1337 Lawyers website responds successfully",
        .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil)
    )
    @MainActor
    func lawyers1337WebsiteResponds() async throws {
        try await validateWebsiteWithURLSession(name: "1337 Lawyers", url: "https://www.1337lawyers.com")
    }

    @Test("All websites return valid HTTP responses", .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil))
    @MainActor
    func allWebsitesReturnValidResponses() async throws {
        for (name, url) in Self.websites {
            try await validateWebsiteWithURLSession(name: name, url: url)
        }
    }

    // MARK: - Helper Methods

    @MainActor
    private func validateWebsiteWithURLSession(name: String, url: String) async throws {
        print("🔍 Starting validation for \(name) at \(url)")

        guard let requestURL = URL(string: url) else {
            print("❌ Invalid URL: \(url)")
            throw ValidationError.invalidURL(url)
        }

        // Setup standard mocks for external services
        URLSession.testMocker.clearMocks()
        URLSession.testMocker.registerWebsiteMocks()

        var request = URLRequest(url: requestURL)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.timeoutInterval = 30.0

        print("🌐 Making HTTP request to \(url)...")
        // Use the test mocker directly since we're in a test environment
        let (data, response) = try await URLSession.testMocker.mockURLSessionRequest(for: request)

        // Verify HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Non-HTTP response for \(name)")
            throw ValidationError.invalidResponse("Non-HTTP response for \(name)")
        }

        print("📊 HTTP Status: \(httpResponse.statusCode)")
        print("📄 Content-Length: \(data.count) bytes")

        #expect(
            httpResponse.statusCode == 200,
            "Website '\(name)' at \(url) should return HTTP 200, got \(httpResponse.statusCode)"
        )

        // Convert data to string and verify basic HTML structure
        guard let htmlContent = String(data: data, encoding: .utf8) else {
            print("❌ Unable to decode HTML content for \(name)")
            throw ValidationError.invalidContent("Unable to decode HTML content for \(name)")
        }

        print("✅ Successfully decoded HTML content (\(htmlContent.count) characters)")

        // Verify basic HTML structure
        let hasHtml = htmlContent.lowercased().contains("<html")
        let hasHead = htmlContent.lowercased().contains("<head")
        let hasBody = htmlContent.lowercased().contains("<body")

        print(
            "🏗️  HTML Structure - HTML tag: \(hasHtml ? "✅" : "❌"), Head tag: \(hasHead ? "✅" : "❌"), Body tag: \(hasBody ? "✅" : "❌")"
        )

        #expect(hasHtml, "Website '\(name)' should contain HTML tag")
        #expect(hasHead, "Website '\(name)' should contain head tag")
        #expect(hasBody, "Website '\(name)' should contain body tag")

        // Verify the page has a title
        let titleRegex = try NSRegularExpression(pattern: "<title[^>]*>([^<]+)</title>", options: .caseInsensitive)
        let titleRange = NSRange(location: 0, length: htmlContent.count)
        let titleMatch = titleRegex.firstMatch(in: htmlContent, options: [], range: titleRange)

        if let titleMatch = titleMatch,
            let titleRange = Range(titleMatch.range(at: 1), in: htmlContent)
        {
            let title = String(htmlContent[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            print("📝 Page title: '\(title)'")
            #expect(!title.isEmpty, "Website '\(name)' should have a non-empty title")
            #expect(!title.lowercased().contains("error"), "Website '\(name)' title should not contain error text")
            #expect(!title.lowercased().contains("404"), "Website '\(name)' title should not contain 404 text")
            #expect(
                !title.lowercased().contains("not found"),
                "Website '\(name)' title should not contain 'not found' text"
            )
        } else {
            print("❌ No title tag found")
            #expect(Bool(false), "Website '\(name)' should have a valid title tag")
        }

        // Check for meta viewport tag (mobile responsiveness)
        let viewportRegex = try NSRegularExpression(
            pattern: "<meta[^>]+name=[\"']viewport[\"'][^>]*>",
            options: .caseInsensitive
        )
        let viewportRange = NSRange(location: 0, length: htmlContent.count)
        let hasViewport = viewportRegex.firstMatch(in: htmlContent, options: [], range: viewportRange) != nil

        print("📱 Viewport meta tag: \(hasViewport ? "✅ Found" : "❌ Missing")")
        #expect(hasViewport, "Website '\(name)' should have a viewport meta tag for mobile responsiveness")

        // Verify content type
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
        print("🎭 Content-Type: \(contentType)")
        #expect(contentType.lowercased().contains("text/html"), "Website '\(name)' should return HTML content type")

        print("✅ \(name) validation completed successfully!\n")
    }
}

enum ValidationError: Error {
    case invalidURL(String)
    case invalidResponse(String)
    case invalidContent(String)
}
