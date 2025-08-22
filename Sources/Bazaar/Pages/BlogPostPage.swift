import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct BlogPostPage: HTMLDocument {
    let post: BlogPost
    let markdownContent: String

    var title: String { "\(post.title) - Sagebrush" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation()
        BlogContent(post: post, markdownContent: markdownContent)
        FooterComponent.sagebrushFooter()
    }
}

struct BlogContent: HTML {
    let post: BlogPost
    let markdownContent: String

    var content: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                BlogArticle(post: post, markdownContent: markdownContent)
            }
        }
    }
}

struct BlogArticle: HTML {
    let post: BlogPost
    let markdownContent: String

    var content: some HTML {
        div(.class("columns")) {
            div(.class("column is-8 is-offset-2")) {
                article(.class("content")) {
                    h1(.class("title is-1 has-text-primary")) { post.title }

                    // Render the markdown content as HTML using TouchMenu's MarkdownContent
                    TouchMenu.MarkdownContent(markdown: markdownContent, style: .bulma)

                    BlogMeta(date: post.createdAt)
                    BlogCTACard()
                }
            }
        }
    }
}

struct BlogMeta: HTML {
    let date: Date

    var content: some HTML {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        let dateString = formatter.string(from: date)

        return p(.class("has-text-grey is-size-7")) {
            "Published: \(dateString)"
        }
    }
}
