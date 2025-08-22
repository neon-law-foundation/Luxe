import Elementary
import TouchMenu

struct StandardsSpecPage: HTMLDocument {
    var title: String { "Neon Notations Specification" }

    var head: some HTML {
        meta(.charset("utf-8"))
        meta(.name("viewport"), .content("width=device-width, initial-scale=1"))
        Elementary.title { title }
        link(.rel("stylesheet"), .href("https://cdn.jsdelivr.net/npm/bulma@0.9.4/css/bulma.min.css"))
        HeaderComponent.standardsTheme()
    }

    var body: some HTML {
        Navigation()

        section(.class("hero is-primary is-medium")) {
            div(.class("hero-body")) {
                div(.class("container has-text-centered")) {
                    h1(.class("title is-1")) { "Neon Notations Specification" }
                    h2(.class("subtitle is-3")) { "Technical specification for computable document workflows" }
                }
            }
        }

        section(.class("section")) {
            div(.class("container")) {
                div(.class("columns is-centered")) {
                    div(.class("column is-10")) {
                        div(.class("content")) {
                            StandardsMarkdownContent(filename: "standards-spec")
                        }

                        div(.class("has-text-centered mt-6")) {
                            a(.class("button is-primary is-large is-rounded"), .href("/standards")) {
                                "Back to Standards Home"
                            }
                            a(
                                .class("button is-info is-large is-rounded"),
                                .href("mailto:standards@sagebrush.services")
                            ) {
                                "Contact Support"
                            }
                        }
                    }
                }
            }
        }

        FooterComponent.sagebrushFooter()
    }
}
