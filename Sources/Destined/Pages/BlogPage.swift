import Elementary
import TouchMenu
import VaporElementary

struct BlogPage: HTMLDocument {
    var title: String { "Blog - Destined" }

    var head: some HTML {
        HeaderComponent(primaryColor: "#1e3a8a", secondaryColor: "#10b981").content
        Elementary.title { title }
    }

    var body: some HTML {
        DestinedNavigation().body
        BlogContent()
        customFooter
    }

    private var customFooter: some HTML {
        footer(.class("footer has-background-dark")) {
            div(.class("container has-text-centered")) {
                p(.class("has-text-grey-light")) {
                    "Destined is a Sagebrush Services powered company"
                }
            }
        }
    }
}

struct BlogContent: HTML {
    var content: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                h1(.class("title is-1 has-text-light has-text-centered")) { "Destined Blog" }
                p(.class("subtitle has-text-light has-text-centered")) {
                    "Mystical insights for your spiritual journey"
                }

                div(.class("columns is-multiline")) {
                    NeptuneLineBlogCard()
                }
            }
        }
    }
}

struct NeptuneLineBlogCard: HTML {
    var content: some HTML {
        div(.class("column is-half")) {
            div(.class("card has-background-dark")) {
                div(.class("card-header")) {
                    p(.class("card-header-title has-text-light")) { "Neptune Line" }
                }
                div(.class("card-content")) {
                    div(.class("content has-text-light")) {
                        p {
                            "Discover the spiritual power of living on your Neptune line in astrocartography. Explore how this mystical planetary influence can deepen your intuition, enhance your creativity, and connect you to the divine..."
                        }
                    }
                }
                footer(.class("card-footer")) {
                    a(.class("card-footer-item button is-primary"), .href("/blog/neptune-line")) { "Read More" }
                }
            }
        }
    }
}
