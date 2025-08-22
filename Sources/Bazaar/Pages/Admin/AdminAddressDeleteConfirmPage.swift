import Bouncer
import Dali
import Elementary
import TouchMenu
import VaporElementary

struct AdminAddressDeleteConfirmPage: HTMLDocument {
    let address: Address
    let currentUser: User?

    var title: String { "Delete Address" }

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
                    h1(.class("title is-1 has-text-white")) { "Delete Address" }
                    h2(.class("subtitle is-3 has-text-white")) {
                        "This action cannot be undone"
                    }
                }
            }
        }
    }

    private var confirmationSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                div(.class("columns is-centered")) {
                    div(.class("column is-8")) {
                        confirmationCard
                    }
                }
            }
        }
    }

    private var confirmationCard: some HTML {
        div(.class("card")) {
            div(.class("card-header")) {
                p(.class("card-header-title")) { "Confirm Deletion" }
            }
            div(.class("card-content")) {
                warningMessage
                addressSummary
                deleteActions
            }
        }
    }

    private var warningMessage: some HTML {
        div(.class("notification is-warning")) {
            p(.class("has-text-weight-bold")) {
                "Are you sure you want to delete this address?"
            }
            p {
                "This action cannot be undone and will permanently remove the address from the system."
            }
        }
    }

    private var deleteActions: some HTML {
        div(.class("field is-grouped mt-5")) {
            div(.class("control")) {
                deleteForm
            }
            div(.class("control")) {
                cancelButton
            }
        }
    }

    private var deleteForm: some HTML {
        form(
            .method(.post),
            .action("/admin/addresses/\((try? address.requireID())?.uuidString ?? "")")
        ) {
            input(.type(.hidden), .name("_method"), .value("DELETE"))
            button(.class("button is-danger"), .type(.submit)) {
                span(.class("icon")) {
                    i(.class("fas fa-trash")) {}
                }
                span { "Yes, Delete Address" }
            }
        }
    }

    private var cancelButton: some HTML {
        a(
            .class("button is-light"),
            .href("/admin/addresses/\((try? address.requireID())?.uuidString ?? "")")
        ) {
            "Cancel"
        }
    }

    private var addressSummary: some HTML {
        div(.class("box has-background-light")) {
            h4(.class("title is-5")) { "Address to be deleted:" }

            div(.class("content")) {
                p {
                    strong { "Street: " }
                    address.street
                }
                p {
                    strong { "City: " }
                    address.city
                }
                if let state = address.state {
                    p {
                        strong { "State: " }
                        state
                    }
                }
                if let zip = address.zip {
                    p {
                        strong { "ZIP: " }
                        zip
                    }
                }
                p {
                    strong { "Country: " }
                    address.country
                }
                p {
                    strong { "Linked to: " }
                    if let _ = address.$entity.id {
                        span(.class("tag is-info")) { "Entity" }
                    } else if let _ = address.$person.id {
                        span(.class("tag is-success")) { "Person" }
                    } else {
                        span(.class("tag is-warning")) { "Unlinked" }
                    }
                }
                p {
                    strong { "Status: " }
                    if address.isVerified {
                        span(.class("tag is-success")) { "Verified" }
                    } else {
                        span(.class("tag is-warning")) { "Unverified" }
                    }
                }
            }
        }
    }
}
