import Dali
import Elementary
import TestUtilities
import Testing
import Vapor
import VaporElementary
import VaporTesting

@testable import Bazaar

@Suite("Blog Page Rendering Tests", .serialized)
struct BlogPageTests {
    @Test("Blog page loads and displays expected content and navigation")
    func blogPageLoadsAndDisplaysExpectedContent() async throws {
        try await TestUtilities.withApp { app, database in
            try configureBlogApp(app)

            try await app.test(.GET, "/blog") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)

                let body = response.body.string
                #expect(body.contains("Sagebrush Blog"))
                #expect(body.contains("Why Nevada for Your Virtual Mailbox"))
                #expect(body.contains("Understanding Cap Tables and Equity Sharing in Nevada"))
                #expect(body.contains("Why a16z is Leaving Delaware for Nevada"))
                #expect(body.contains("/blog/why-nevada"))
                #expect(body.contains("/blog/cap-table-equity"))
                #expect(body.contains("/blog/a16z-leaving-delaware"))
                #expect(body.contains("bulma"))
                #expect(body.contains("#006400"))
            }
        }
    }

    @Test("Why Nevada blog post renders with complete content and styling")
    func whyNevadaBlogPostRendersWithCompleteContent() async throws {
        try await TestUtilities.withApp { app, database in
            try configureBlogApp(app)

            try await app.test(.GET, "/blog/why-nevada") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)

                let body = response.body.string
                #expect(body.contains("Why Nevada for Your Virtual Mailbox"))
                #expect(body.contains("Business-Friendly Environment"))
                #expect(body.contains("Strategic Location"))
                #expect(body.contains("Privacy Protection"))
                #expect(body.contains("No State Income Tax"))
                #expect(body.contains("/pricing"))
                #expect(body.contains("mailto:support@sagebrush.services"))
                #expect(body.contains("bulma"))
            }
        }
    }

    @Test("Cap table equity blog post displays comprehensive content sections")
    func capTableEquityBlogPostDisplaysComprehensiveContent() async throws {
        try await TestUtilities.withApp { app, database in
            try configureBlogApp(app)

            try await app.test(.GET, "/blog/cap-table-equity") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)

                let body = response.body.string
                #expect(body.contains("Understanding Cap Tables and Equity Sharing in Nevada"))
                #expect(body.contains("What Is a Cap Table?"))
                #expect(body.contains("Why Cap Tables Matter in Nevada"))
                #expect(body.contains("Fair and Transparent Equity Sharing"))
                #expect(body.contains("Understanding Vesting"))
                #expect(body.contains("Stock Options vs. Restricted Stock"))
                #expect(body.contains("Nevada-Specific Considerations"))
                #expect(body.contains("Ready to Experience the Benefits?"))
                #expect(body.contains("bulma"))
            }
        }
    }

    @Test("A16z leaving Delaware blog post renders with all expected sections")
    func a16zLeavingDelawareBlogPostRendersWithAllSections() async throws {
        try await TestUtilities.withApp { app, database in
            try configureBlogApp(app)

            try await app.test(.GET, "/blog/a16z-leaving-delaware") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)

                let body = response.body.string
                #expect(body.contains("Why a16z is Leaving Delaware for Nevada"))
                #expect(body.contains("The Delaware Doctrine Unravels"))
                #expect(body.contains("Nevada"))
                #expect(body.contains("Superior Framework"))
                #expect(body.contains("Tax Advantages Compound the Benefits"))
                #expect(body.contains("The Venture Capital Seal of Approval"))
                #expect(body.contains("Andreessen Horowitz"))
                #expect(body.contains("Ready to Experience the Benefits?"))
                #expect(body.contains("bulma"))
            }
        }
    }
}

// MARK: - Helper Functions

private func configureBlogApp(_ app: Application) throws {
    // Configure DALI models and database
    try configureDali(app)

    // Configure blog routes
    app.get("blog") { req in
        HTMLResponse {
            BlogPage()
        }
    }

    // Dynamic blog post routing
    app.get("blog", ":slug") { req -> Response in
        guard let slug = req.parameters.get("slug") else {
            throw Abort(.badRequest)
        }

        // Load the markdown file using the app's working directory
        let markdownDirectory = app.directory.workingDirectory + "Sources/Bazaar/Markdown"
        let filePath = "\(markdownDirectory)/\(slug).md"

        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            throw Abort(.notFound, reason: "Blog post not found: \(slug)")
        }

        // Parse the frontmatter to get metadata
        guard let post = BlogPost.parseFrontmatter(from: content, filename: slug) else {
            throw Abort(.internalServerError, reason: "Invalid blog post format")
        }

        // Extract the actual content (after frontmatter)
        let lines = content.components(separatedBy: .newlines)
        var contentStartIndex = 0
        var frontmatterEndFound = false

        for (index, line) in lines.enumerated() {
            if index > 0 && line == "---" && !frontmatterEndFound {
                contentStartIndex = index + 1
                frontmatterEndFound = true
                break
            }
        }

        let markdownBody = lines[contentStartIndex...].joined(separator: "\n")

        return try await HTMLResponse {
            BlogPostPage(post: post, markdownContent: markdownBody)
        }.encodeResponse(for: req)
    }
}
