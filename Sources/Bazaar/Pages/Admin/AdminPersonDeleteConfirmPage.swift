import Bouncer
import Dali
import Elementary
import TouchMenu
import VaporElementary

struct AdminPersonDeleteConfirmPage: HTMLDocument {
    let person: Person
    let currentUser: User?

    var title: String { "Delete \(person.name) - Confirm" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        heroSection
        confirmationSection
        FooterComponent.sagebrushFooter()
    }

    private var heroSection: some HTML {
        section(.class("hero is-danger")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { "Delete Person" }
                    h2(.class("subtitle is-3 has-text-white")) { "This action cannot be undone" }
                }
            }
        }
    }

    private var confirmationSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                div(.class("columns is-centered")) {
                    div(.class("column is-half")) {
                        div(.class("card")) {
                            div(.class("card-header")) {
                                p(.class("card-header-title has-text-danger")) {
                                    "⚠️ Confirm Deletion"
                                }
                            }
                            div(.class("card-content")) {
                                div(.class("content")) {
                                    p {
                                        "Are you sure you want to delete this person?"
                                    }
                                    div(.class("box has-background-light")) {
                                        strong { "Name: " }
                                        person.name
                                        br()
                                        strong { "Email: " }
                                        person.email
                                    }
                                    p(.class("has-text-danger has-text-weight-bold")) {
                                        "This action cannot be undone. The person and all associated data will be permanently deleted."
                                    }
                                }
                            }
                            footer(.class("card-footer")) {
                                div(.class("card-footer-item")) {
                                    form(
                                        .method(.post),
                                        .action("/admin/people/\((try? person.requireID())?.uuidString ?? "")")
                                    ) {
                                        input(.type(.hidden), .name("_method"), .value("DELETE"))
                                        button(.class("button is-danger is-fullwidth"), .type(.submit)) {
                                            "Yes, Delete Person"
                                        }
                                    }
                                }
                                div(.class("card-footer-item")) {
                                    a(
                                        .class("button is-light is-fullwidth"),
                                        .href("/admin/people/\((try? person.requireID())?.uuidString ?? "")")
                                    ) {
                                        "Cancel"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
