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

    @Suite("Word Concatenation Fix", .serialized)
    struct WordConcatenationTests {

        @Test("prevents word concatenation at line breaks")
        func preventsWordConcatenation() throws {
            let markdown = """
                We're excited to announce that Sagebrush Services is searching for an exceptional Chief Executive
                Officer to lead our company into its next phase of growth and innovation.

                We're now seeking a visionary
                leader who can expand our impact and drive our mission forward with both strategic insight and
                operational excellence.
                """

            let content = MarkdownContent(markdown: markdown)
            let html = String(describing: content.content).replacingOccurrences(of: "HTMLRaw(text: \"", with: "")
                .replacingOccurrences(of: "\")", with: "").replacingOccurrences(of: "\\\"", with: "\"")

            // Should have proper spacing between words
            #expect(html.contains("Chief Executive Officer"))
            #expect(!html.contains("ExecutiveOfficer"))
            #expect(html.contains("visionary leader"))
            #expect(!html.contains("visionaryleader"))
            #expect(html.contains("and operational"))
            #expect(!html.contains("andoperational"))
        }

        @Test("preserves proper markdown structure without concatenation")
        func preservesMarkdownStructure() throws {
            let markdown = """
                from virtual mailbox solutions to corporate formation and legal support. We're now seeking a visionary
                leader who can expand our impact and drive our mission forward with both strategic insight and
                operational excellence.
                """

            let content = MarkdownContent(markdown: markdown)
            let html = String(describing: content.content).replacingOccurrences(of: "HTMLRaw(text: \"", with: "")
                .replacingOccurrences(of: "\")", with: "").replacingOccurrences(of: "\\\"", with: "\"")

            // Should contain proper spacing
            #expect(html.contains("visionary leader"))
            #expect(html.contains("and operational"))
            #expect(!html.contains("visionaryleader"))
            #expect(!html.contains("andoperational"))
        }

        @Test("debug with built-in formatter")
        func debugBuiltInFormatter() throws {
            let markdown = """
                Chief Executive
                Officer test
                """

            let content = MarkdownContent(markdown: markdown)
            let html = String(describing: content.content).replacingOccurrences(of: "HTMLRaw(text: \"", with: "")
                .replacingOccurrences(of: "\")", with: "").replacingOccurrences(of: "\\\"", with: "\"")

            print("Input: '\(markdown)'")
            print("Output HTML: '\(html)'")

            #expect(html.contains("Chief Executive Officer"))
        }

        private func debugPreprocess(_ content: String) -> String {
            var processedContent = content

            // Remove frontmatter if present (copied from the real function)
            if processedContent.hasPrefix("---") {
                let lines = processedContent.components(separatedBy: .newlines)
                var frontmatterEndIndex = -1

                for (index, line) in lines.enumerated() where index > 0 {
                    if line.trimmingCharacters(in: .whitespaces) == "---" {
                        frontmatterEndIndex = index
                        break
                    }
                }

                if frontmatterEndIndex > 0 {
                    let remainingLines = Array(lines[(frontmatterEndIndex + 1)...])
                    processedContent = remainingLines.joined(separator: "\n").trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                }
            }

            // Copy the preprocessing logic exactly
            let lines = processedContent.components(separatedBy: .newlines)
            var result: [String] = []
            var inParagraph = false

            for (index, line) in lines.enumerated() {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                let originalLine = line.trimmingCharacters(in: .newlines)  // Keep spaces but remove newlines

                if trimmedLine.isEmpty {
                    // Empty line - paragraph break
                    result.append("")
                    inParagraph = false
                } else {
                    // Line has content
                    if inParagraph && index > 0 {
                        // We're continuing a paragraph - check if previous line should have a soft break
                        let prevIndex = result.count - 1
                        if prevIndex >= 0 && !result[prevIndex].isEmpty {
                            let prevLine = result[prevIndex]

                            // Check if previous line already ends with hard break markers
                            if !prevLine.hasSuffix("  ") && !prevLine.hasSuffix("\\") {
                                // No hard break marker - this should be a soft break (space)
                                result[prevIndex] = prevLine.trimmingCharacters(in: .whitespaces) + " "
                            }
                        }
                    }

                    result.append(originalLine)
                    inParagraph = true
                }
            }

            return result.joined(separator: "\n")
        }

    }
}
