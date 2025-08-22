import Bouncer
import Dali
import Elementary
import TouchMenu
import VaporElementary

struct AdminUserDeleteConfirmPage: HTMLDocument {
    let user: User
    let currentUser: User?

    var title: String { "Delete \(user.person?.name ?? user.username) - Confirm" }

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
                    h1(.class("title is-1 has-text-white")) { "Delete User" }
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
                                        "Are you sure you want to delete this user?"
                                    }
                                    div(.class("box has-background-light")) {
                                        strong { "Name: " }
                                        user.person?.name ?? "N/A"
                                        br()
                                        strong { "Username: " }
                                        user.username
                                        br()
                                        strong { "Email: " }
                                        user.person?.email ?? "N/A"
                                        br()
                                        strong { "Role: " }
                                        span(.class("tag " + roleTagClass(user.role))) {
                                            user.role.displayName
                                        }
                                    }
                                    p(.class("has-text-danger has-text-weight-bold")) {
                                        "This action cannot be undone. The user account and all associated data will be permanently deleted."
                                    }
                                }
                            }
                            footer(.class("card-footer")) {
                                div(.class("card-footer-item")) {
                                    form(
                                        .method(.post),
                                        .action("/admin/users/\((try? user.requireID())?.uuidString ?? "")")
                                    ) {
                                        input(.type(.hidden), .name("_method"), .value("DELETE"))
                                        button(.class("button is-danger is-fullwidth is-rounded"), .type(.submit)) {
                                            "Yes, Delete User"
                                        }
                                    }
                                }
                                div(.class("card-footer-item")) {
                                    a(
                                        .class("button is-light is-fullwidth is-rounded"),
                                        .href("/admin/users/\((try? user.requireID())?.uuidString ?? "")")
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

    private func roleTagClass(_ role: UserRole) -> String {
        switch role {
        case .customer: return "is-info"
        case .staff: return "is-warning"
        case .admin: return "is-danger"
        }
    }
}
