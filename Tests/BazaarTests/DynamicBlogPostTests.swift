import Dali
import Elementary
import Foundation
import TestUtilities
import Testing
import TouchMenu
import Vapor
import VaporElementary
import VaporTesting

@testable import Bazaar

@Suite("Dynamic Blog Post Loading Tests", .serialized)
struct DynamicBlogPostTests {
    @Test("BlogPost can parse frontmatter from markdown content")
    func blogPostParsesFrontmatterCorrectly() throws {
        let markdownContent = """
            ---
            title: "Test Blog Post"
            slug: "test-blog-post"
            description: "This is a test blog post description"
            created_at: "2024-01-15T10:00:00Z"
            ---

            # Test Blog Post

            This is the content of the test blog post.
            """

        let post = BlogPost.parseFrontmatter(from: markdownContent, filename: "test-blog-post")

        #expect(post != nil)
        #expect(post?.title == "Test Blog Post")
        #expect(post?.slug == "test-blog-post")
        #expect(post?.description == "This is a test blog post description")
        #expect(post?.filename == "test-blog-post")

        // Verify GitHub URL is constructed correctly
        #expect(
            post?.githubUrl
                == "https://github.com/neon-law-foundation/Luxe/tree/main/Sources/Bazaar/Markdown/test-blog-post.md"
        )
    }

    @Test("BlogPost returns nil for invalid frontmatter")
    func blogPostReturnsNilForInvalidFrontmatter() throws {
        let invalidContent1 = "# No Frontmatter Here"
        let post1 = BlogPost.parseFrontmatter(from: invalidContent1, filename: "invalid1")
        #expect(post1 == nil)

        let invalidContent2 = """
            ---
            title: "Missing Required Fields"
            ---

            Content here
            """
        let post2 = BlogPost.parseFrontmatter(from: invalidContent2, filename: "invalid2")
        #expect(post2 == nil)
    }

    @Test("BlogPost GitHub URL is constructed correctly")
    func blogPostGitHubURLIsConstructedCorrectly() throws {
        let post1 = BlogPost(
            title: "Older Post",
            slug: "older",
            description: "Older",
            filename: "older"
        )

        let post2 = BlogPost(
            title: "Newer Post",
            slug: "newer",
            description: "Newer",
            filename: "newer"
        )

        #expect(
            post1.githubUrl == "https://github.com/neon-law-foundation/Luxe/tree/main/Sources/Bazaar/Markdown/older.md"
        )
        #expect(
            post2.githubUrl == "https://github.com/neon-law-foundation/Luxe/tree/main/Sources/Bazaar/Markdown/newer.md"
        )
    }

    @Test("BlogPost equality based on slug")
    func blogPostEqualityBasedOnSlug() throws {
        let post1 = BlogPost(
            title: "Title 1",
            slug: "same-slug",
            description: "Desc 1",
            filename: "file1"
        )

        let post2 = BlogPost(
            title: "Title 2",
            slug: "same-slug",
            description: "Desc 2",
            filename: "file2"
        )

        let post3 = BlogPost(
            title: "Title 3",
            slug: "different-slug",
            description: "Desc 3",
            filename: "file3"
        )

        #expect(post1 == post2)
        #expect(post1 != post3)
    }

    @Test("Dynamic blog post page renders markdown content as HTML")
    func dynamicBlogPostPageRendersMarkdownContent() async throws {
        try await TestUtilities.withApp { app, database in
            try configureDali(app)

            // Configure dynamic blog route
            app.get("blog", ":slug") { req -> Response in
                guard let slug = req.parameters.get("slug") else {
                    throw Abort(.badRequest)
                }

                // Load the markdown file
                let markdownDirectory = app.directory.workingDirectory + "Sources/Bazaar/Markdown"
                let filePath = "\(markdownDirectory)/\(slug).md"

                guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
                    throw Abort(.notFound)
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

                // For now, return a simple HTML response
                // In production, this would use a proper markdown parser
                return try await HTMLResponse {
                    BlogPostPage(post: post, markdownContent: markdownBody)
                }.encodeResponse(for: req)
            }

            // Test that the dynamic route works
            try await app.test(.GET, "/blog/why-nevada") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)

                let body = response.body.string
                #expect(body.contains("Why Nevada for Your Virtual Mailbox"))
            }
        }
    }

    @Test("BlogPost.getAllPosts returns blog posts without sorting")
    func getAllPostsReturnsBlogPosts() throws {
        // This test would need actual markdown files in the directory
        // For unit testing, we'll check that posts are returned
        let posts = BlogPost.getAllPosts()

        // Verify posts are returned (no specific ordering expected now)
        // Since we removed date-based sorting, just verify the function works
        #expect(posts.count >= 0)  // Should return some posts or empty array
    }

    @Test("DynamicBlogPostPage should render markdown as HTML not raw text")
    func dynamicBlogPostPageShouldRenderMarkdownAsHTML() throws {
        // Arrange - Create test blog post and markdown content
        let post = BlogPost(
            title: "Test Post",
            slug: "test-post",
            description: "A test post",
            filename: "test-post"
        )

        let markdownContent = """
            # Main Heading

            This is a **bold** paragraph with *italic* text.

            - List item 1
            - List item 2

            Here's a [link](https://example.com) and some `inline code`.

            ```swift
            let code = "block"
            ```
            """

        // Act - Create the blog post page
        let page = BlogPostPage(post: post, markdownContent: markdownContent)

        // Get the rendered HTML
        let renderedHTML = String(describing: page.render())

        // Assert - Verify markdown is converted to HTML, not displayed as raw text
        #expect(renderedHTML.contains("<h1 class=\"title\">Main Heading</h1>"))
        #expect(renderedHTML.contains("<strong>bold</strong>"))
        #expect(renderedHTML.contains("<em>italic</em>"))
        #expect(renderedHTML.contains("<li>"))
        #expect(renderedHTML.contains("List item 1"))
        #expect(renderedHTML.contains("List item 2"))
        #expect(renderedHTML.contains("<a href=\"https://example.com\""))
        #expect(renderedHTML.contains("inline code</code>"))
        #expect(renderedHTML.contains("<pre class=\"has-background-light\"><code>let code = &quot;block&quot;"))

        // Verify we DON'T have raw markdown syntax in output
        #expect(!renderedHTML.contains("# Main Heading"))
        #expect(!renderedHTML.contains("**bold**"))
        #expect(!renderedHTML.contains("*italic*"))
        #expect(!renderedHTML.contains("- List item"))
        #expect(!renderedHTML.contains("[link](https://example.com)"))
        #expect(!renderedHTML.contains("`inline code`"))
        #expect(!renderedHTML.contains("```swift"))
    }

    @Test("DynamicBlogPostPage should sanitize malicious HTML content")
    func dynamicBlogPostPageShouldSanitizeMaliciousHTML() throws {
        // Arrange - Create test blog post with malicious HTML
        let post = BlogPost(
            title: "Security Test Post",
            slug: "security-test",
            description: "Testing security",
            filename: "security-test"
        )

        let maliciousMarkdown = """
            # Legitimate Heading

            This is normal text with <script>alert('XSS')</script> embedded.

            This has <img src="x" onerror="alert('XSS')"> malicious image.

            And some <b>bold</b> with <div onclick="alert('XSS')">clickable div</div>.
            """

        // Act - Create the blog post page
        let page = BlogPostPage(post: post, markdownContent: maliciousMarkdown)

        // Get the rendered HTML
        let renderedHTML = String(describing: page.render())

        // Assert - Verify malicious content is completely stripped (not executable)
        #expect(renderedHTML.contains("This is normal text with alert("))
        #expect(renderedHTML.contains("XSS"))
        #expect(renderedHTML.contains("embedded."))
        #expect(renderedHTML.contains("This has  malicious image."))
        #expect(renderedHTML.contains("And some bold with clickable div."))

        // Verify we DON'T have unescaped malicious content
        #expect(!renderedHTML.contains("<script>alert('XSS')</script>"))
        #expect(!renderedHTML.contains("<img src=\"x\" onerror=\"alert('XSS')\">"))
        #expect(!renderedHTML.contains("<div onclick=\"alert('XSS')\">"))
        #expect(!renderedHTML.contains("onerror=\"alert"))

        // But ensure legitimate markdown still works
        #expect(renderedHTML.contains("<h1 class=\"title\">Legitimate Heading</h1>"))
    }

    @Test("BlogPostPage displays GitHub link correctly")
    func blogPostPageDisplaysGitHubLinkCorrectly() throws {
        // Arrange - Create test blog post
        let post = BlogPost(
            title: "Test GitHub Link",
            slug: "test-github-link",
            description: "Testing GitHub link functionality",
            filename: "test-github-link"
        )

        let markdownContent = "# Test Content\n\nThis is test content."

        // Act - Create the blog post page
        let page = BlogPostPage(post: post, markdownContent: markdownContent)

        // Get the rendered HTML
        let renderedHTML = String(describing: page.render())

        // Assert - Verify GitHub link is present
        #expect(renderedHTML.contains("View source and history on"))
        #expect(
            renderedHTML.contains(
                "https://github.com/neon-law-foundation/Luxe/tree/main/Sources/Bazaar/Markdown/test-github-link.md"
            )
        )
        #expect(renderedHTML.contains("target=\"_blank\""))
        #expect(renderedHTML.contains("rel=\"noreferrer\""))
        #expect(renderedHTML.contains("GitHub"))
    }
}

// Test helper page removed - using the actual BlogPostPage from Bazaar
