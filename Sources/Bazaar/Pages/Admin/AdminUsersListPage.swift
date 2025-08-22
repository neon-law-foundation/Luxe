import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct AdminUsersListPage: HTMLDocument {
    let peopleWithUsers: [(person: Person, user: User)]
    let currentUser: User?

    var title: String { "User Management - Admin" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        breadcrumbSection
        heroSection
        usersSection
        FooterComponent.sagebrushFooter()
    }

    private var breadcrumbSection: some HTML {
        section(.class("section is-small")) {
            div(.class("container")) {
                BreadcrumbComponent.adminUsers()
            }
        }
    }

    private var heroSection: some HTML {
        section(.class("hero is-primary")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { "User Management" }
                    h2(.class("subtitle is-3 has-text-white")) {
                        "Manage all users and their associated people in the system"
                    }
                }
            }
        }
    }

    private var usersSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                headerSection
                searchSection
                usersTable
            }
        }
    }

    private var headerSection: some HTML {
        div(.class("level")) {
            div(.class("level-left")) {
                h2(.class("title is-3")) { "All Users" }
            }
            div(.class("level-right")) {
                a(.class("button is-primary is-rounded"), .href("/admin/users/new")) {
                    "Create New User"
                }
            }
        }
    }

    private var searchSection: some HTML {
        div(.class("box")) {
            searchInput
            filterSection
        }
    }

    private var searchInput: some HTML {
        div(.class("field has-addons")) {
            div(.class("control is-expanded")) {
                input(
                    .class("input"),
                    .type(.search),
                    .placeholder("Search users by name, email, or username..."),
                    .id("user-search")
                )
            }
            div(.class("control")) {
                button(.class("button is-info is-rounded"), .type(.button)) {
                    span(.class("icon")) {
                        i(.class("fas fa-search")) {}
                    }
                    span { "Search" }
                }
            }
        }
    }

    private var filterSection: some HTML {
        div(.class("field is-grouped")) {
            div(.class("control")) {
                label(.class("label is-small")) { "Filter by Role:" }
                div(.class("select")) {
                    select(.id("role-filter")) {
                        option(.value("")) { "All Roles" }
                        option(.value("customer")) { "Customers" }
                        option(.value("staff")) { "Staff" }
                        option(.value("admin")) { "Admins" }
                    }
                }
            }
            div(.class("control")) {
                label(.class("label is-small")) { " " }
                button(.class("button is-light is-rounded"), .type(.button)) {
                    "Clear Filters"
                }
            }
        }
    }

    private var usersTable: some HTML {
        div {
            if peopleWithUsers.isEmpty {
                div(.class("notification is-info")) {
                    "No users found. "
                    a(.href("/admin/users/new")) { "Create the first user" }
                    "."
                }
            } else {
                div(.class("table-container")) {
                    table(.class("table is-fullwidth is-hoverable")) {
                        thead {
                            tr {
                                th { "Name" }
                                th { "Email" }
                                th { "Username" }
                                th { "Role" }
                                th { "Created" }
                                th { "Actions" }
                            }
                        }
                        tbody {
                            userRowsContent
                        }
                    }
                }
            }
        }
    }

    private var userRowsContent: some HTML {
        ForEach(peopleWithUsers) { personUserPair in
            userRow(person: personUserPair.person, user: personUserPair.user)
        }
    }

    private func userRow(person: Person, user: User) -> some HTML {
        tr {
            td {
                a(.href("/admin/users/\((try? user.requireID())?.uuidString ?? "")")) {
                    person.name
                }
            }
            td { person.email }
            td { user.username }
            td {
                span(.class("tag " + roleTagClass(user.role))) {
                    user.role.displayName
                }
            }
            td {
                if let createdAt = user.createdAt {
                    formatDate(createdAt)
                } else {
                    "—"
                }
            }
            td {
                div(.class("buttons")) {
                    a(
                        .class("button is-small is-info is-rounded"),
                        .href("/admin/users/\((try? user.requireID())?.uuidString ?? "")")
                    ) {
                        "View"
                    }
                    a(
                        .class("button is-small is-warning is-rounded"),
                        .href("/admin/users/\((try? user.requireID())?.uuidString ?? "")/edit")
                    ) {
                        "Edit Role"
                    }
                    a(
                        .class("button is-small is-danger is-rounded"),
                        .href("/admin/users/\((try? user.requireID())?.uuidString ?? "")/delete")
                    ) {
                        "Delete"
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
