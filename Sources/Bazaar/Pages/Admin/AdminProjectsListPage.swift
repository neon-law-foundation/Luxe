import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct AdminProjectsListPage: HTMLDocument {
    let projects: [Project]
    let currentUser: User?

    var title: String { "Projects Management - Admin" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        breadcrumbSection
        heroSection
        projectsSection
        FooterComponent.sagebrushFooter()
    }

    private var breadcrumbSection: some HTML {
        section(.class("section is-small")) {
            div(.class("container")) {
                BreadcrumbComponent.adminProjects()
            }
        }
    }

    private var heroSection: some HTML {
        section(.class("hero is-primary")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { "Projects Management" }
                    h2(.class("subtitle is-3 has-text-white")) { "Manage all projects in the system" }
                }
            }
        }
    }

    private var projectsSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                div(.class("level")) {
                    div(.class("level-left")) {
                        h2(.class("title is-3")) { "All Projects" }
                    }
                    div(.class("level-right")) {
                        a(.class("button is-primary"), .href("/admin/projects/new")) {
                            "Add New Project"
                        }
                    }
                }

                if projects.isEmpty {
                    div(.class("notification is-info")) {
                        "No projects found. "
                        a(.href("/admin/projects/new")) { "Create the first project" }
                        "."
                    }
                } else {
                    div(.class("table-container")) {
                        table(.class("table is-fullwidth is-hoverable")) {
                            thead {
                                tr {
                                    th { "Codename" }
                                    th { "Created At" }
                                    th { "Actions" }
                                }
                            }
                            tbody {
                                projectsRowsContent
                            }
                        }
                    }
                }
            }
        }
    }

    private var projectsRowsContent: some HTML {
        ForEach(projects) { project in
            projectRow(project)
        }
    }

    private func projectRow(_ project: Project) -> some HTML {
        tr {
            td {
                a(.href("/admin/projects/\((try? project.requireID())?.uuidString ?? "")")) {
                    project.codename
                }
            }
            td {
                if let createdAt = project.createdAt {
                    DateFormatter.short.string(from: createdAt)
                } else {
                    "N/A"
                }
            }
            td {
                div(.class("buttons")) {
                    a(
                        .class("button is-small is-info"),
                        .href("/admin/projects/\((try? project.requireID())?.uuidString ?? "")")
                    ) {
                        "View"
                    }
                    a(
                        .class("button is-small is-warning"),
                        .href("/admin/projects/\((try? project.requireID())?.uuidString ?? "")/edit")
                    ) {
                        "Edit"
                    }
                    a(
                        .class("button is-small is-danger"),
                        .href("/admin/projects/\((try? project.requireID())?.uuidString ?? "")/delete")
                    ) {
                        "Delete"
                    }
                }
            }
        }
    }
}
