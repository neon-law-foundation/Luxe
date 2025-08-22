import Bouncer
import Dali
import Elementary
import TouchMenu
import VaporElementary

struct AdminLegalJurisdictionDetailPage: HTMLDocument {
    let jurisdiction: LegalJurisdiction
    let currentUser: User?

    var title: String { "\(jurisdiction.name) - Legal Jurisdiction Details" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        heroSection
        detailSection
        FooterComponent.sagebrushFooter()
    }

    private var heroSection: some HTML {
        section(.class("hero is-primary")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { jurisdiction.name }
                    h2(.class("subtitle is-3 has-text-white")) { "Legal Jurisdiction Details" }
                }
            }
        }
    }

    private var detailSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                div(.class("columns")) {
                    div(.class("column is-8")) {
                        div(.class("card")) {
                            div(.class("card-header")) {
                                p(.class("card-header-title")) { "Legal Jurisdiction Information" }
                            }
                            div(.class("card-content")) {
                                jurisdictionFields
                            }
                        }
                    }
                    div(.class("column is-4")) {
                        div(.class("card")) {
                            div(.class("card-header")) {
                                p(.class("card-header-title")) { "Actions" }
                            }
                            div(.class("card-content")) {
                                actionButtons
                            }
                        }
                    }
                }
            }
        }
    }

    private var jurisdictionFields: some HTML {
        div(.class("content")) {
            div(.class("field")) {
                label(.class("label")) { "ID" }
                div(.class("control")) {
                    input(
                        .class("input"),
                        .type(.text),
                        .value((try? jurisdiction.requireID())?.uuidString ?? "Unknown"),
                        .disabled
                    )
                }
            }

            div(.class("field")) {
                label(.class("label")) { "Name" }
                div(.class("control")) {
                    input(.class("input"), .type(.text), .value(jurisdiction.name), .disabled)
                }
            }

            div(.class("field")) {
                label(.class("label")) { "Code" }
                div(.class("control")) {
                    input(.class("input"), .type(.text), .value(jurisdiction.code), .disabled)
                }
            }
        }
    }

    private var actionButtons: some HTML {
        div(.class("content")) {
            a(.class("button is-light is-fullwidth"), .href("/admin/legal-jurisdictions")) {
                "← Back to Legal Jurisdictions List"
            }
        }
    }
}
