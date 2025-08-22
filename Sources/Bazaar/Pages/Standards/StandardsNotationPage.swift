import Elementary
import TouchMenu

struct StandardsNotationPage: HTMLDocument {
    let notationPath: String

    var title: String {
        "Notation: \(notationPath) - Sagebrush Standards"
    }

    var head: some HTML {
        meta(.charset("utf-8"))
        meta(.name("viewport"), .content("width=device-width, initial-scale=1"))
        Elementary.title { title }
        link(.rel("stylesheet"), .href("https://cdn.jsdelivr.net/npm/bulma@0.9.4/css/bulma.min.css"))
        StandardsHeaderComponent.standardsTheme()
    }

    var body: some HTML {
        StandardsNavigation()

        section(.class("section")) {
            div(.class("container")) {
                div(.class("columns")) {
                    div(.class("column is-8 is-offset-2")) {
                        article(.class("content")) {
                            h1(.class("title is-1 has-text-primary")) { "Notation: \(notationPath)" }
                            p(.class("subtitle")) { "YAML Configuration File" }

                            StandardsYAMLContent(filepath: notationPath)

                            div(.class("has-text-centered mt-6")) {
                                a(.class("button is-primary is-rounded"), .href("/standards")) {
                                    "Back to Standards Home"
                                }
                                a(.class("button is-info is-rounded"), .href("/standards/spec")) {
                                    "View Specification"
                                }
                            }
                        }
                    }
                }
            }
        }

        StandardsFooterComponent.standardsFooter()
    }
}
