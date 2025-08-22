import Elementary
import TouchMenu
import VaporElementary

struct AboutAstrocartographyPage: HTMLDocument {
    var title: String { "About Astrocartography - Destined" }

    var head: some HTML {
        HeaderComponent(primaryColor: "#1e3a8a", secondaryColor: "#10b981").content
        Elementary.title { title }
    }

    var body: some HTML {
        DestinedNavigation().body
        main {
            section(.class("section")) {
                div(.class("container")) {
                    div(.class("column is-8 is-offset-2")) {
                        article(.class("content has-text-light")) {
                            MarkdownContent(filename: "about-astrocartography")
                        }
                    }
                }
            }
        }
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
