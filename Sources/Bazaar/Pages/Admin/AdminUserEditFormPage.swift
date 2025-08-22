import Bouncer
import Dali
import Elementary
import TouchMenu
import VaporElementary

struct AdminUserEditFormPage: HTMLDocument {
    let user: User
    let currentUser: User?

    var title: String { "Edit User Role - \(user.username)" }

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
                        "Update the role for: \(user.person?.name ?? user.username)"
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
                                    "Edit User Role"
                                }
                            }
                            div(.class("card-content")) {
                                currentInfoSection
                                hr()
                                roleEditForm
                            }
                        }
                    }
                }
            }
        }
    }

    private var currentInfoSection: some HTML {
        div(.class("content")) {
            h4(.class("title is-5")) { "Current User Information" }
            table(.class("table is-fullwidth")) {
                tbody {
                    tr {
                        td { strong { "Name" } }
                        td { user.person?.name ?? "N/A" }
                    }
                    tr {
                        td { strong { "Email" } }
                        td { user.person?.email ?? "N/A" }
                    }
                    tr {
                        td { strong { "Username" } }
                        td { user.username }
                    }
                    tr {
                        td { strong { "Current Role" } }
                        td {
                            span(.class("tag is-medium " + roleTagClass(user.role))) {
                                user.role.displayName
                            }
                        }
                    }
                }
            }
        }
    }

    private var roleEditForm: some HTML {
        form(.method(.post), .action("/admin/users/\((try? user.requireID())?.uuidString ?? "")")) {
            input(.type(.hidden), .name("_method"), .value("PATCH"))

            div(.class("field")) {
                label(.class("label")) { "New User Role" }
                div(.class("control")) {
                    div(.class("select")) {
                        select(.name("role"), .required) {
                            for role in UserRole.allCases {
                                if user.role == role {
                                    option(.value(role.rawValue), .selected) {
                                        "\(role.displayName) - \(roleDescription(role))"
                                    }
                                } else {
                                    option(.value(role.rawValue)) {
                                        "\(role.displayName) - \(roleDescription(role))"
                                    }
                                }
                            }
                        }
                    }
                }
                p(.class("help")) { "Select the new role for this user" }
            }

            roleDescriptions

            div(.class("notification is-warning")) {
                strong { "Warning: " }
                "Changing a user's role will immediately affect their access permissions in the system. "
                "Make sure you understand the implications before proceeding."
            }

            div(.class("field is-grouped")) {
                div(.class("control")) {
                    button(.class("button is-primary"), .type(.submit)) {
                        "Update Role"
                    }
                }
                div(.class("control")) {
                    a(.class("button is-light"), .href("/admin/users/\((try? user.requireID())?.uuidString ?? "")")) {
                        "Cancel"
                    }
                }
            }
        }
    }

    private var roleDescriptions: some HTML {
        div(.class("box has-background-light")) {
            h4(.class("title is-6")) { "Role Descriptions:" }
            div(.class("content")) {
                ul {
                    li {
                        strong { "Customer" }
                        " - Standard users who can access their own data and basic features"
                    }
                    li {
                        strong { "Staff" }
                        " - Employees with elevated access to manage customer data and operations"
                    }
                    li {
                        strong { "Admin" }
                        " - Full system access including user management and system configuration"
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

    private func roleDescription(_ role: UserRole) -> String {
        switch role {
        case .customer: return "Standard user access"
        case .staff: return "Employee access"
        case .admin: return "Full administrative access"
        }
    }
}
