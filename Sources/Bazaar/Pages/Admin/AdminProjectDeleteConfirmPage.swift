import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct AdminProjectDeleteConfirmPage: HTMLDocument {
    let project: Project
    let currentUser: User?

    var title: String { "Delete Project - \(project.codename)" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        breadcrumbSection
        heroSection
        confirmationSection
        FooterComponent.sagebrushFooter()
    }

    private var breadcrumbSection: some HTML {
        section(.class("section is-small")) {
            div(.class("container")) {
                BreadcrumbComponent.adminProjectDelete(
                    projectCodename: project.codename,
                    projectId: (try? project.requireID())?.uuidString ?? ""
                )
            }
        }
    }

    private var heroSection: some HTML {
        section(.class("hero is-danger")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { "Delete Project" }
                    h2(.class("subtitle is-3 has-text-white")) { "Confirm project deletion" }
                }
            }
        }
    }

    private var confirmationSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                div(.class("columns is-centered")) {
                    div(.class("column is-6")) {
                        div(.class("card")) {
                            div(.class("card-header")) {
                                p(.class("card-header-title")) { "Delete Confirmation" }
                            }
                            div(.class("card-content")) {
                                div(.class("content")) {
                                    div(.class("notification is-warning")) {
                                        p(.class("has-text-weight-bold")) {
                                            "⚠️ Are you sure you want to delete this project?"
                                        }
                                        p {
                                            "This action cannot be undone. All associated assigned notations will also be deleted."
                                        }
                                    }

                                    projectSummary
                                    actionButtons
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var projectSummary: some HTML {
        div(.class("box")) {
            h4(.class("title is-5")) { "Project to be deleted:" }
            projectDetails
        }
    }

    private var projectDetails: some HTML {
        div {
            dl {
                dt(.class("has-text-weight-bold")) { "Codename:" }
                dd { project.codename }

                dt(.class("has-text-weight-bold")) { "ID:" }
                dd {
                    code { (try? project.requireID())?.uuidString ?? "N/A" }
                }
            }

            if let createdAt = project.createdAt {
                dl {
                    dt(.class("has-text-weight-bold")) { "Created At:" }
                    dd { DateFormatter.full.string(from: createdAt) }
                }
            }
        }
    }

    private var actionButtons: some HTML {
        div(.class("field is-grouped is-grouped-centered")) {
            div(.class("control")) {
                form(
                    .method(.post),
                    .action("/admin/projects/\((try? project.requireID())?.uuidString ?? "")/delete")
                ) {
                    input(.type(.hidden), .name("_method"), .value("DELETE"))
                    button(.class("button is-danger"), .type(.submit)) {
                        "Yes, Delete Project"
                    }
                }
            }
            div(.class("control")) {
                a(
                    .class("button is-light"),
                    .href("/admin/projects/\((try? project.requireID())?.uuidString ?? "")")
                ) {
                    "Cancel"
                }
            }
        }
    }
}
