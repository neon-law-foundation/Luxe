import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct AdminProjectFormPage: HTMLDocument {
    let project: Project?
    let currentUser: User?

    private var isEditing: Bool { project != nil }

    var title: String {
        isEditing ? "Edit Project" : "Add New Project"
    }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        breadcrumbSection
        heroSection
        formSection
        FooterComponent.sagebrushFooter()
    }

    private var breadcrumbSection: some HTML {
        section(.class("section is-small")) {
            div(.class("container")) {
                if isEditing {
                    BreadcrumbComponent.adminProjectEdit(
                        projectCodename: project!.codename,
                        projectId: (try? project!.requireID())?.uuidString ?? ""
                    )
                } else {
                    BreadcrumbComponent.adminProjectNew()
                }
            }
        }
    }

    private var heroSection: some HTML {
        section(.class("hero is-success")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { title }
                    h2(.class("subtitle is-3 has-text-white")) {
                        isEditing ? "Update project information" : "Create a new project"
                    }
                }
            }
        }
    }

    private var formSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                div(.class("columns is-centered")) {
                    div(.class("column is-6")) {
                        div(.class("card")) {
                            div(.class("card-header")) {
                                p(.class("card-header-title")) {
                                    isEditing ? "Edit Project" : "Project Details"
                                }
                            }
                            div(.class("card-content")) {
                                projectForm
                            }
                        }
                    }
                }
            }
        }
    }

    private var projectForm: some HTML {
        form(
            .method(.post),
            .action(isEditing ? "/admin/projects/\((try? project!.requireID())?.uuidString ?? "")" : "/admin/projects")
        ) {
            if isEditing {
                input(.type(.hidden), .name("_method"), .value("PATCH"))
            }

            div(.class("field")) {
                label(.class("label"), .for("codename")) { "Codename" }
                div(.class("control")) {
                    input(
                        .class("input"),
                        .type(.text),
                        .id("codename"),
                        .name("codename"),
                        .value(project?.codename ?? ""),
                        .placeholder("Enter project codename"),
                        .required
                    )
                }
                p(.class("help")) { "A unique identifier for the project" }
            }

            div(.class("field is-grouped")) {
                div(.class("control")) {
                    button(.class("button is-primary"), .type(.submit)) {
                        isEditing ? "Update Project" : "Create Project"
                    }
                }
                div(.class("control")) {
                    a(.class("button is-light"), .href(cancelUrl)) {
                        "Cancel"
                    }
                }
            }
        }
    }

    private var cancelUrl: String {
        if isEditing, let projectId = try? project!.requireID() {
            return "/admin/projects/\(projectId.uuidString)"
        }
        return "/admin/projects"
    }
}
