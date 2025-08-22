import Bouncer
import Dali
import Elementary
import TouchMenu
import VaporElementary

struct AdminPersonDetailPage: HTMLDocument {
    let person: Person
    let currentUser: User?

    var title: String { "\(person.name) - Person Details" }

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
                    h1(.class("title is-1 has-text-white")) { person.name }
                    h2(.class("subtitle is-3 has-text-white")) { "Person Details" }
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
                                p(.class("card-header-title")) { "Person Information" }
                            }
                            div(.class("card-content")) {
                                personFields
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

    private var personFields: some HTML {
        div(.class("content")) {
            div(.class("field")) {
                label(.class("label")) { "ID" }
                div(.class("control")) {
                    input(
                        .class("input"),
                        .type(.text),
                        .value((try? person.requireID())?.uuidString ?? "Unknown"),
                        .disabled
                    )
                }
            }

            div(.class("field")) {
                label(.class("label")) { "Name" }
                div(.class("control")) {
                    input(.class("input"), .type(.text), .value(person.name), .disabled)
                }
            }

            div(.class("field")) {
                label(.class("label")) { "Email" }
                div(.class("control")) {
                    input(.class("input"), .type(.email), .value(person.email), .disabled)
                }
            }
        }
    }

    private var actionButtons: some HTML {
        div(.class("content")) {
            a(
                .class("button is-warning is-fullwidth"),
                .href("/admin/people/\((try? person.requireID())?.uuidString ?? "")/edit")
            ) {
                "Edit Person"
            }
            br()
            br()
            a(
                .class("button is-danger is-fullwidth"),
                .href("/admin/people/\((try? person.requireID())?.uuidString ?? "")/delete")
            ) {
                "Delete Person"
            }
            br()
            br()
            a(.class("button is-light is-fullwidth"), .href("/admin/people")) {
                "← Back to People List"
            }
        }
    }
}
