import TestUtilities
import Testing
import VaporTesting

@testable import Destined

@Suite("Scorpio Pages", .serialized)
struct ScorpioPagesTests {
    @Test("ScorpioPage renders with correct title and links")
    func scorpioPageRenderingWorksCorrectly() async throws {
        try await TestUtilities.withWebApp { app in
            try configureApp(app)

            try await app.test(.GET, "/scorpio") { response in
                #expect(response.status == .ok)

                let body = response.body.string

                // Check for page title
                #expect(body.contains("<title>Scorpio - Destined</title>"))

                // Check for link to moon page
                #expect(body.contains("<a href=\"/scorpio/moon\">"))
                #expect(body.contains("Scorpio Moon"))
            }
        }
    }

    @Test("ScorpioMoonPage renders markdown content")
    func scorpioMoonPageRenderingWorksCorrectly() async throws {
        try await TestUtilities.withWebApp { app in
            try configureApp(app)

            try await app.test(.GET, "/scorpio/moon") { response in
                #expect(response.status == .ok)

                let body = response.body.string

                // Check for page title
                #expect(body.contains("<title>Scorpio Moon - Destined</title>"))

                // Check that markdown content is rendered (should contain heading)
                #expect(body.contains("<h1>Scorpio Moon 🌍</h1>") || body.contains("<h1 >Scorpio Moon 🌍</h1>"))

                // Check for some key content about Scorpio Moon
                #expect(body.contains("emotional"))
                #expect(body.contains("intense") || body.contains("intensity"))
                #expect(body.contains("transformation") || body.contains("transformative"))
            }
        }
    }

    @Test("HomePage links to astrology page")
    func homePageLinksToAstrologyCorrectly() async throws {
        try await TestUtilities.withWebApp { app in
            try configureApp(app)

            try await app.test(.GET, "/") { response in
                #expect(response.status == .ok)

                let body = response.body.string

                // Check for link to astrology page
                #expect(body.contains("href=\"/astrology\""))
                #expect(body.contains("Astrology"))
            }
        }
    }
}
