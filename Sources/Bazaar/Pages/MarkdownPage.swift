import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct MarkdownPage: HTMLDocument {
    let post: BlogPost
    let markdownContent: String

    var title: String { "\(post.title) - Sagebrush" }

    var head: some HTML {
        let ogMetadata = TouchMenu.OpenGraphMetadata(
            title: post.title,
            description: post.description,
            image: "https://www.sagebrush.services/sagebrush.png",
            url: "https://www.sagebrush.services/\(post.slug)",
            type: "article"
        )

        HeaderComponent.sagebrushTheme(openGraphMetadata: ogMetadata)
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation()
        MarkdownPageContent(post: post, markdownContent: markdownContent)
        FooterComponent.sagebrushFooter()
    }
}

struct MarkdownPageContent: HTML {
    let post: BlogPost
    let markdownContent: String

    var content: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                MarkdownArticle(post: post, markdownContent: markdownContent)
            }
        }
    }
}

struct MarkdownArticle: HTML {
    let post: BlogPost
    let markdownContent: String

    var content: some HTML {
        div(.class("columns")) {
            div(.class("column is-8 is-offset-2")) {
                article(.class("content")) {
                    h1(.class("title is-1 has-text-primary")) { post.title }

                    // Render the markdown content as HTML using TouchMenu's MarkdownContent
                    TouchMenu.MarkdownContent(markdown: markdownContent, style: .bulma)
                }
            }
        }
    }
}
