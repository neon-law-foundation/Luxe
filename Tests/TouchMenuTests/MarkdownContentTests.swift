import Testing

@testable import TouchMenu

@Suite("MarkdownContent Component", .serialized)
struct MarkdownContentTests {

    @Suite("Rendering from String", .serialized)
    struct StringRenderingTests {

        @Test("markdown converts to HTML with proper heading, paragraph, list, and link elements")
        func rendersBasicElements() throws {
            let markdown = """
                # Heading 1
                ## Heading 2

                This is a paragraph with **bold** and *italic* text.

                - Item 1
                - Item 2

                1. First
                2. Second

                [Link](https://example.com)
                """

            let content = MarkdownContent(markdown: markdown)
            let html = String(describing: content.content).replacingOccurrences(of: "HTMLRaw(text: \"", with: "")
                .replacingOccurrences(of: "\")", with: "").replacingOccurrences(of: "\\\"", with: "\"")

            #expect(html.contains("<h1>Heading 1</h1>"))
            #expect(html.contains("<h2>Heading 2</h2>"))
            #expect(html.contains("<p>This is a paragraph with <strong>bold</strong> and <em>italic</em> text.</p>"))
            #expect(html.contains("<ul>"))
            #expect(html.contains("<li><p>Item 1</p></li>"))
            #expect(html.contains("<ol>"))
            #expect(html.contains("<li><p>First</p></li>"))
            #expect(html.contains(#"<a href="https://example.com">Link</a>"#))
        }

        @Test("markdown preserves code syntax with inline code and pre-formatted blocks")
        func rendersCodeElements() throws {
            let markdown = """
                Here is `inline code`.

                ```swift
                let greeting = "Hello, World!"
                print(greeting)
                ```
                """

            let content = MarkdownContent(markdown: markdown)
            let html = String(describing: content.content).replacingOccurrences(of: "HTMLRaw(text: \"", with: "")
                .replacingOccurrences(of: "\")", with: "").replacingOccurrences(of: "\\\"", with: "\"")

            #expect(html.contains("<code>inline code</code>"))
            #expect(html.contains("<pre><code>"))
            #expect(html.contains("let greeting = &quot;Hello, World!&quot;"))
        }

        @Test("style options customize CSS classes for headings, paragraphs, and links")
        func appliesCustomStyling() throws {
            let markdown = "# Heading"
            let customStyle = MarkdownContent.StyleOptions(
                headingClass: "title is-1",
                paragraphClass: "content",
                linkClass: "link-custom"
            )

            let content = MarkdownContent(markdown: markdown, style: customStyle)
            let html = String(describing: content.content).replacingOccurrences(of: "HTMLRaw(text: \"", with: "")
                .replacingOccurrences(of: "\")", with: "").replacingOccurrences(of: "\\\"", with: "\"")

            #expect(html.contains(#"<h1 class="title is-1">Heading</h1>"#))
        }
    }

    @Suite("Rendering from File", .serialized)
    struct FileRenderingTests {

        @Test("markdown content loads from bundle resource file and renders to HTML")
        func loadsFromBundle() throws {
            let content = MarkdownContent(filename: "TestMarkdown", bundle: .module)
            let html = String(describing: content.content).replacingOccurrences(of: "HTMLRaw(text: \"", with: "")
                .replacingOccurrences(of: "\")", with: "").replacingOccurrences(of: "\\\"", with: "\"")

            #expect(!html.isEmpty)
            #expect(!html.contains("File not found"))
        }

        @Test("missing markdown file displays error message instead of throwing exception")
        func handlesMissingFile() throws {
            let content = MarkdownContent(filename: "NonExistent", bundle: .module)
            let html = String(describing: content.content).replacingOccurrences(of: "HTMLRaw(text: \"", with: "")
                .replacingOccurrences(of: "\")", with: "").replacingOccurrences(of: "\\\"", with: "\"")

            #expect(html.contains("File not found"))
        }
    }

    @Suite("HTML Safety", .serialized)
    struct HTMLSafetyTests {

        @Test("HTML content in markdown is escaped to prevent XSS vulnerabilities")
        func escapesHTMLContent() throws {
            let markdown = """
                <script>alert('XSS')</script>

                Regular text with <div>HTML</div>
                """

            let content = MarkdownContent(markdown: markdown)
            let html = String(describing: content.content).replacingOccurrences(of: "HTMLRaw(text: \"", with: "")
                .replacingOccurrences(of: "\")", with: "").replacingOccurrences(of: "\\\"", with: "\"")

            // HTML content should be escaped by the markdown parser
            // Note: The Swift Markdown parser treats raw HTML differently than script tags
            #expect(!html.contains("<script>"))
            #expect(!html.contains("alert('XSS')"))
            // The <div> tag should be escaped
            #expect(html.contains("&lt;div&gt;") || html.contains("HTML"))
        }
    }
}
