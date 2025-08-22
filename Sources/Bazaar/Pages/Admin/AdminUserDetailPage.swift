import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct AdminUserDetailPage: HTMLDocument {
    let user: User
    let currentUser: User?

    var title: String { "User Details - \(user.username)" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        heroSection
        detailsSection
        FooterComponent.sagebrushFooter()
    }

    private var heroSection: some HTML {
        section(.class("hero is-primary")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) {
                        user.person?.name ?? "User Details"
                    }
                    h2(.class("subtitle is-3 has-text-white")) {
                        "User ID: \(user.id?.uuidString ?? "Unknown")"
                    }
                }
            }
        }
    }

    private var detailsSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                div(.class("level")) {
                    div(.class("level-left")) {
                        h2(.class("title is-3")) { "User Information" }
                    }
                    div(.class("level-right")) {
                        a(
                            .class("button is-warning is-rounded"),
                            .href("/admin/users/\((try? user.requireID())?.uuidString ?? "")/edit")
                        ) {
                            "Edit Role"
                        }
                        a(
                            .class("button is-danger is-rounded"),
                            .href("/admin/users/\((try? user.requireID())?.uuidString ?? "")/delete")
                        ) {
                            "Delete User"
                        }
                        a(.class("button is-light is-rounded"), .href("/admin/users")) {
                            "Back to Users"
                        }
                    }
                }

                div(.class("columns")) {
                    div(.class("column is-8")) {
                        userInfoCard
                    }
                    div(.class("column is-4")) {
                        systemInfoCard
                    }
                }
            }
        }
    }

    private var userInfoCard: some HTML {
        div(.class("card")) {
            div(.class("card-header")) {
                p(.class("card-header-title")) {
                    "User & Person Information"
                }
            }
            div(.class("card-content")) {
                div(.class("content")) {
                    table(.class("table is-fullwidth")) {
                        tbody {
                            tr {
                                td { strong { "Full Name" } }
                                td { user.person?.name ?? "N/A" }
                            }
                            tr {
                                td { strong { "Email" } }
                                td {
                                    if let email = user.person?.email {
                                        a(.href("mailto:\(email)")) { email }
                                    } else {
                                        "N/A"
                                    }
                                }
                            }
                            tr {
                                td { strong { "Username" } }
                                td { user.username }
                            }
                            tr {
                                td { strong { "Role" } }
                                td {
                                    span(.class("tag is-medium " + roleTagClass(user.role))) {
                                        user.role.displayName
                                    }
                                }
                            }
                            tr {
                                td { strong { "Access Level" } }
                                td { "\(user.role.accessLevel)" }
                            }
                        }
                    }
                }
            }
        }
    }

    private var systemInfoCard: some HTML {
        div(.class("card")) {
            systemInfoCardHeader
            systemInfoCardContent
        }
    }

    private var systemInfoCardHeader: some HTML {
        div(.class("card-header")) {
            p(.class("card-header-title")) {
                "System Information"
            }
        }
    }

    private var systemInfoCardContent: some HTML {
        div(.class("card-content")) {
            div(.class("content")) {
                systemInfoTable
            }
        }
    }

    private var systemInfoTable: some HTML {
        table(.class("table is-fullwidth")) {
            tbody {
                userIdRow
                personIdRow
                createdAtRow
                updatedAtRow
            }
        }
    }

    private var userIdRow: some HTML {
        tr {
            td { strong { "User ID" } }
            td {
                code(.class("is-size-7")) {
                    user.id?.uuidString ?? "N/A"
                }
            }
        }
    }

    private var personIdRow: some HTML {
        tr {
            td { strong { "Person ID" } }
            td {
                code(.class("is-size-7")) {
                    user.person?.id?.uuidString ?? "N/A"
                }
            }
        }
    }

    private var createdAtRow: some HTML {
        tr {
            td { strong { "Created" } }
            td {
                if let createdAt = user.createdAt {
                    formatDateTime(createdAt)
                } else {
                    "N/A"
                }
            }
        }
    }

    private var updatedAtRow: some HTML {
        tr {
            td { strong { "Last Updated" } }
            td {
                if let updatedAt = user.updatedAt {
                    formatDateTime(updatedAt)
                } else {
                    "N/A"
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

    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
