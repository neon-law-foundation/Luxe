import Bouncer
import Dali
import Elementary
import TouchMenu
import VaporElementary

struct AdminPersonFormPage: HTMLDocument {
    let person: Person?
    let currentUser: User?

    var isEditing: Bool { person != nil }
    var title: String { isEditing ? "Edit Person" : "Create New Person" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        heroSection
        formSection
        FooterComponent.sagebrushFooter()
    }

    private var heroSection: some HTML {
        section(.class("hero is-primary")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { title }
                    h2(.class("subtitle is-3 has-text-white")) {
                        isEditing ? "Update person information" : "Add a new person to the system"
                    }
                }
            }
        }
    }

    private var formSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                div(.class("columns is-centered")) {
                    div(.class("column is-8")) {
                        div(.class("card")) {
                            div(.class("card-header")) {
                                p(.class("card-header-title")) {
                                    isEditing ? "Edit Person" : "Create New Person"
                                }
                            }
                            div(.class("card-content")) {
                                personForm
                            }
                        }
                    }
                }
            }
        }
    }

    private var personForm: some HTML {
        form(.method(.post), .action(formAction)) {
            if isEditing {
                input(.type(.hidden), .name("_method"), .value("PATCH"))
            }

            div(.class("field")) {
                label(.class("label")) { "Name" }
                div(.class("control")) {
                    input(
                        .class("input"),
                        .type(.text),
                        .name("name"),
                        .value(person?.name ?? ""),
                        .required,
                        .placeholder("Enter full name")
                    )
                }
                p(.class("help")) { "The person's full name" }
            }

            div(.class("field")) {
                label(.class("label")) { "Email" }
                div(.class("control")) {
                    input(
                        .class("input"),
                        .type(.email),
                        .name("email"),
                        .value(person?.email ?? ""),
                        .required,
                        .placeholder("Enter email address")
                    )
                }
                p(.class("help")) { "The person's email address" }
            }

            div(.class("field is-grouped")) {
                div(.class("control")) {
                    button(.class("button is-primary is-rounded"), .type(.submit)) {
                        isEditing ? "Update Person" : "Create Person"
                    }
                }
                div(.class("control")) {
                    a(.class("button is-light is-rounded"), .href(cancelUrl)) {
                        "Cancel"
                    }
                }
            }
        }
    }

    private var formAction: String {
        if let person = person {
            return "/admin/people/\((try? person.requireID())?.uuidString ?? "")"
        } else {
            return "/admin/people"
        }
    }

    private var cancelUrl: String {
        if let person = person {
            return "/admin/people/\((try? person.requireID())?.uuidString ?? "")"
        } else {
            return "/admin/people"
        }
    }
}
