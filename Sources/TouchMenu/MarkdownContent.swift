import Elementary
import Foundation
import Markdown

/// A shared component for rendering Markdown content as HTML across all web targets.
///
/// This component provides a unified way to render Markdown files with customizable styling options.
/// It consolidates the markdown rendering logic that was previously duplicated across SagebrushWeb,
/// Standards, and NeonWeb targets.
///
/// ## Usage
///
/// ### Rendering from String
/// ```swift
/// let content = MarkdownContent(markdown: "# Hello\n\nThis is **bold** text.")
/// ```
///
/// ### Rendering from Bundle Resource
/// ```swift
/// let content = MarkdownContent(filename: "guide", bundle: .module)
/// ```
///
/// ### Custom Styling
/// ```swift
/// let style = MarkdownContent.StyleOptions(
///     headingClass: "title",
///     paragraphClass: "content"
/// )
/// let content = MarkdownContent(markdown: "# Styled", style: style)
/// ```
public struct MarkdownContent: HTML {
    private let htmlContent: String

    /// Creates a MarkdownContent component from a markdown string.
    ///
    /// - Parameters:
    ///   - markdown: The markdown content as a string
    ///   - style: Optional styling configuration for HTML output
    public init(markdown: String, style: StyleOptions = .default) {
        let processedMarkdown = preprocessMarkdown(markdown)
        let document = Document(parsing: processedMarkdown)
        let renderer = HTMLRenderer(style: style)
        self.htmlContent = renderer.render(document)
    }

    /// Creates a MarkdownContent component from a markdown file in a bundle.
    ///
    /// - Parameters:
    ///   - filename: The name of the markdown file (without .md extension)
    ///   - bundle: The bundle containing the markdown file
    ///   - subdirectory: Optional subdirectory within the bundle to search
    ///   - style: Optional styling configuration for HTML output
    public init(filename: String, bundle: Bundle, subdirectory: String? = nil, style: StyleOptions = .default) {
        guard let url = bundle.url(forResource: filename, withExtension: "md", subdirectory: subdirectory),
            let content = try? String(contentsOf: url, encoding: .utf8)
        else {
            self.htmlContent = "<p>File not found: \(filename).md</p>"
            return
        }

        let processedMarkdown = preprocessMarkdown(content)
        let document = Document(parsing: processedMarkdown)
        let renderer = HTMLRenderer(style: style)
        self.htmlContent = renderer.render(document)
    }

    /// Creates a MarkdownContent component from a markdown file in a directory.
    ///
    /// - Parameters:
    ///   - filename: The name of the markdown file (without .md extension)
    ///   - directory: The directory path containing the markdown file
    ///   - style: Optional styling configuration for HTML output
    public init(filename: String, directory: String, style: StyleOptions = .default) {
        let fileURL = URL(fileURLWithPath: directory).appendingPathComponent("\(filename).md")

        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            self.htmlContent = "<p>File not found: \(filename).md at \(fileURL.path)</p>"
            return
        }

        let processedMarkdown = preprocessMarkdown(content)
        let document = Document(parsing: processedMarkdown)
        let renderer = HTMLRenderer(style: style)
        self.htmlContent = renderer.render(document)
    }

    public var content: some HTML {
        HTMLRaw(htmlContent)
    }
}

extension MarkdownContent {
    /// Configuration options for customizing the HTML output styling.
    ///
    /// Use this to apply CSS classes to different markdown elements when rendering to HTML.
    /// This enables consistent styling across different web targets while maintaining flexibility.
    public struct StyleOptions: Sendable {
        public let headingClass: String?
        public let paragraphClass: String?
        public let linkClass: String?
        public let listClass: String?
        public let codeClass: String?
        public let preClass: String?

        public init(
            headingClass: String? = nil,
            paragraphClass: String? = nil,
            linkClass: String? = nil,
            listClass: String? = nil,
            codeClass: String? = nil,
            preClass: String? = nil
        ) {
            self.headingClass = headingClass
            self.paragraphClass = paragraphClass
            self.linkClass = linkClass
            self.listClass = listClass
            self.codeClass = codeClass
            self.preClass = preClass
        }

        public static let `default` = StyleOptions()

        public static let bulma = StyleOptions(
            headingClass: "title",
            paragraphClass: "content",
            linkClass: "has-text-link",
            listClass: "content",
            codeClass: "has-background-grey-lighter has-text-dark",
            preClass: "has-background-light"
        )
    }
}

private struct HTMLRenderer {
    private let style: MarkdownContent.StyleOptions

    init(style: MarkdownContent.StyleOptions) {
        self.style = style
    }

    func render(_ document: Document) -> String {
        renderMarkup(document)
    }

    private func renderMarkup(_ markup: any Markup) -> String {
        switch markup {
        case let heading as Heading:
            return renderHeading(heading)
        case let paragraph as Paragraph:
            return renderParagraph(paragraph)
        case let text as Text:
            return renderText(text)
        case let strong as Strong:
            return renderStrong(strong)
        case let emphasis as Emphasis:
            return renderEmphasis(emphasis)
        case let link as Link:
            return renderLink(link)
        case let list as UnorderedList:
            return renderUnorderedList(list)
        case let list as OrderedList:
            return renderOrderedList(list)
        case let item as ListItem:
            return renderListItem(item)
        case let codeBlock as CodeBlock:
            return renderCodeBlock(codeBlock)
        case let inlineCode as InlineCode:
            return renderInlineCode(inlineCode)
        case let document as Document:
            return document.children.map { renderMarkup($0) }.joined()
        default:
            return markup.children.map { renderMarkup($0) }.joined()
        }
    }

    private func renderHeading(_ heading: Heading) -> String {
        let level = heading.level
        let className = style.headingClass.map { #" class="\#($0)""# } ?? ""
        let content = heading.children.map { renderMarkup($0) }.joined()
        return "<h\(level)\(className)>\(content)</h\(level)>"
    }

    private func renderParagraph(_ paragraph: Paragraph) -> String {
        let className = style.paragraphClass.map { #" class="\#($0)""# } ?? ""
        let content = paragraph.children.map { renderMarkup($0) }.joined()
        return "<p\(className)>\(content)</p>"
    }

    private func renderText(_ text: Text) -> String {
        text.string.htmlEscaped()
    }

    private func renderStrong(_ strong: Strong) -> String {
        let content = strong.children.map { renderMarkup($0) }.joined()
        return "<strong>\(content)</strong>"
    }

    private func renderEmphasis(_ emphasis: Emphasis) -> String {
        let content = emphasis.children.map { renderMarkup($0) }.joined()
        return "<em>\(content)</em>"
    }

    private func renderLink(_ link: Link) -> String {
        let className = style.linkClass.map { #" class="\#($0)""# } ?? ""
        let destination = link.destination ?? ""
        let content = link.children.map { renderMarkup($0) }.joined()
        return #"<a href="\#(destination)"\#(className)>\#(content)</a>"#
    }

    private func renderUnorderedList(_ list: UnorderedList) -> String {
        let className = style.listClass.map { #" class="\#($0)""# } ?? ""
        let content = list.children.map { renderMarkup($0) }.joined()
        return "<ul\(className)>\(content)</ul>"
    }

    private func renderOrderedList(_ list: OrderedList) -> String {
        let className = style.listClass.map { #" class="\#($0)""# } ?? ""
        let content = list.children.map { renderMarkup($0) }.joined()
        return "<ol\(className)>\(content)</ol>"
    }

    private func renderListItem(_ listItem: ListItem) -> String {
        let content = listItem.children.map { renderMarkup($0) }.joined()
        return "<li>\(content)</li>"
    }

    private func renderCodeBlock(_ codeBlock: CodeBlock) -> String {
        let className = style.preClass.map { #" class="\#($0)""# } ?? ""
        return "<pre\(className)><code>\(codeBlock.code.htmlEscaped())</code></pre>"
    }

    private func renderInlineCode(_ inlineCode: InlineCode) -> String {
        let className = style.codeClass.map { #" class="\#($0)""# } ?? ""
        return "<code\(className)>\(inlineCode.code.htmlEscaped())</code>"
    }
}

/// Preprocesses markdown content to fix line break issues
///
/// This function ensures that lines ending with lowercase letters followed by lines
/// starting with lowercase letters have proper spacing to prevent word concatenation.
private func preprocessMarkdown(_ content: String) -> String {
    let lines = content.components(separatedBy: .newlines)
    var processedLines: [String] = []

    for (index, line) in lines.enumerated() {
        var processedLine = line

        // Check if this line ends with a lowercase letter and the next line starts with a lowercase letter
        if index < lines.count - 1 {
            let nextLine = lines[index + 1]

            // Check if current line ends with lowercase and next line starts with lowercase
            if let lastChar = line.last,
                let firstChar = nextLine.first,
                lastChar.isLowercase && firstChar.isLowercase && !nextLine.isEmpty
            {
                // Add a trailing space to ensure proper word separation
                processedLine = line + " "
            }
        }

        processedLines.append(processedLine)
    }

    return processedLines.joined(separator: "\n")
}

extension String {
    func htmlEscaped() -> String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
