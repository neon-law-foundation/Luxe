import Elementary
import TouchMenu

struct MarkdownContent: HTML {
    let filename: String

    var content: some HTML {
        TouchMenu.MarkdownContent(filename: filename, directory: "Sources/Bazaar/Markdown")
    }
}
