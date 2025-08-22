import TestUtilities
import Testing
import VaporTesting

@testable import Destined

@Suite("Destined Home Page", .serialized)
struct HomePageTests {
    @Test("Home page loads successfully with OK status")
    func homePageLoadsSuccessfully() async throws {
        try await TestUtilities.withWebApp { app in
            try configureApp(app)

            try await app.test(.GET, "/") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)
            }
        }
    }

    @Test("Home page contains 'Destined' text")
    func homePageContainsDestinedText() async throws {
        try await TestUtilities.withWebApp { app in
            try configureApp(app)

            try await app.test(.GET, "/") { response in
                let body = response.body.string
                #expect(body.contains("Destined"))
            }
        }
    }

    @Test("Home page renders valid HTML")
    func homePageRendersValidHTML() async throws {
        try await TestUtilities.withWebApp { app in
            try configureApp(app)

            try await app.test(.GET, "/") { response in
                let body = response.body.string
                #expect(body.contains("<!DOCTYPE html>"))
                #expect(body.contains("<html"))
                #expect(body.contains("</html>"))
            }
        }
    }
}
