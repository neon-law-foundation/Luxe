import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct BlogPage: HTMLDocument {
    var title: String { "Blog - Sagebrush Physical Address" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation()
        BlogIndexContent()
        FooterComponent.sagebrushFooter()
    }
}

struct BlogIndexContent: HTML {
    var content: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                h1(.class("title is-1 has-text-primary has-text-centered")) { "Sagebrush Blog" }
                p(.class("subtitle has-text-centered")) { "Insights and tips for physical address services" }

                div(.class("columns is-multiline")) {
                    DynamicBlogCards()
                }
            }
        }
    }
}

struct DynamicBlogCards: HTML {
    var content: some HTML {
        ForEach(BlogPost.getAllPosts()) { post in
            BlogCard(post: post)
        }
    }
}

struct BlogCard: HTML {
    let post: BlogPost

    var content: some HTML {
        div(.class("column is-half")) {
            div(.class("card")) {
                div(.class("card-header")) {
                    p(.class("card-header-title")) { post.title }
                }
                div(.class("card-content")) {
                    div(.class("content")) {
                        p { post.description }
                        a(
                            .href(post.githubUrl),
                            .target("_blank"),
                            .rel("noreferrer"),
                            .class("has-text-primary is-size-7")
                        ) {
                            "View on GitHub"
                        }
                    }
                }
                footer(.class("card-footer")) {
                    a(.class("card-footer-item button is-primary"), .href("/blog/\(post.slug)")) {
                        "Read More"
                    }
                }
            }
        }
    }
}
