import Elementary
import TouchMenu

struct StandardsNotationsPage: HTMLDocument {
    var title: String { "Notations - Sagebrush Standards" }

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
                h1(.class("title is-1 has-text-primary has-text-centered")) { "Available Notations" }
                p(.class("subtitle has-text-centered")) { "YAML configuration files for document workflows" }

                div(.class("columns is-multiline")) {
                    StandardsNotationCard(
                        title: "Nevada LLC Registration",
                        description:
                            "Complete questionnaire and workflow for Nevada LLC formation including SoS filings",
                        path: "NVSoS/llc_registration",
                        category: "Nevada Secretary of State"
                    )
                }
            }
        }

        StandardsFooterComponent.standardsFooter()
    }
}

struct StandardsNotationCard: HTML {
    let title: String
    let description: String
    let path: String
    let category: String

    var content: some HTML {
        div(.class("column is-half")) {
            div(.class("card")) {
                div(.class("card-header")) {
                    p(.class("card-header-title")) { title }
                    span(.class("tag is-info")) { category }
                }
                div(.class("card-content")) {
                    div(.class("content")) {
                        p { description }
                        p(.class("is-size-7 has-text-grey")) { "Path: \(path)" }
                    }
                }
                footer(.class("card-footer")) {
                    a(.class("card-footer-item button is-primary is-rounded"), .href("/standards/notations/\(path)")) {
                        "View YAML"
                    }
                }
            }
        }
    }
}
