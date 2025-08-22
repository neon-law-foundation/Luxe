import TestUtilities
import Testing
import VaporTesting

@testable import Destined

@Suite("Astrocartography Pages", .serialized)
struct AstrocartographyPagesTests {
    @Test("About Astrocartography page loads successfully")
    func aboutAstrocartographyPageLoads() async throws {
        try await TestUtilities.withWebApp { app in
            try configureApp(app)

            try await app.test(.GET, "/about-astrocartography") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)
            }
        }
    }

    @Test("About Astrocartography page contains expected content")
    func aboutAstrocartographyPageContent() async throws {
        try await TestUtilities.withWebApp { app in
            try configureApp(app)

            try await app.test(.GET, "/about-astrocartography") { response in
                let body = response.body.string

                // Check for page title
                #expect(body.contains("<title>About Astrocartography - Destined</title>"))

                // Check for key astrocartography concepts
                #expect(body.contains("astrocartography") || body.contains("Astrocartography"))
                #expect(body.contains("location") || body.contains("Location"))
                #expect(body.contains("planetary") || body.contains("Planetary"))
            }
        }
    }

    @Test("Services page loads successfully")
    func servicesPageLoads() async throws {
        try await TestUtilities.withWebApp { app in
            try configureApp(app)

            try await app.test(.GET, "/services") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)
            }
        }
    }

    @Test("Services page contains expected services")
    func servicesPageContent() async throws {
        try await TestUtilities.withWebApp { app in
            try configureApp(app)

            try await app.test(.GET, "/services") { response in
                let body = response.body.string

                // Check for page title
                #expect(body.contains("<title>Services - Destined</title>"))

                // Check for services list
                #expect(body.contains("astrocartography") || body.contains("Astrocartography"))
                #expect(body.contains("tarot") || body.contains("Tarot"))
                #expect(body.contains("spirituality") || body.contains("Spirituality"))
            }
        }
    }

    @Test("Blog page loads successfully")
    func blogPageLoads() async throws {
        try await TestUtilities.withWebApp { app in
            try configureApp(app)

            try await app.test(.GET, "/blog") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)
            }
        }
    }

    @Test("Blog page contains Neptune Line post")
    func blogPageContainsNeptuneLinePost() async throws {
        try await TestUtilities.withWebApp { app in
            try configureApp(app)

            try await app.test(.GET, "/blog") { response in
                let body = response.body.string

                // Check for page title
                #expect(body.contains("<title>Blog - Destined</title>"))

                // Check for Neptune Line blog post
                #expect(body.contains("Neptune Line"))
                #expect(body.contains("spiritual") || body.contains("Spiritual"))
            }
        }
    }

    @Test("Neptune Line blog post loads successfully")
    func neptuneLineBlogPostLoads() async throws {
        try await TestUtilities.withWebApp { app in
            try configureApp(app)

            try await app.test(.GET, "/blog/neptune-line") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)
            }
        }
    }

    @Test("Neptune Line blog post contains expected content")
    func neptuneLineBlogPostContent() async throws {
        try await TestUtilities.withWebApp { app in
            try configureApp(app)

            try await app.test(.GET, "/blog/neptune-line") { response in
                let body = response.body.string

                // Check for page title
                #expect(body.contains("<title>Neptune Line - Destined</title>"))

                // Check for Neptune-related content
                #expect(body.contains("Neptune"))
                #expect(body.contains("spiritual") || body.contains("Spiritual"))
                #expect(body.contains("astrocartography") || body.contains("Astrocartography"))
                #expect(body.contains("intuition") || body.contains("Intuition"))
            }
        }
    }
}
