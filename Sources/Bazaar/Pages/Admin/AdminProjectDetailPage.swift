import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct AdminProjectDetailPage: HTMLDocument {
    let project: Project
    let currentUser: User?

    var title: String { "Project Details - \(project.codename)" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        breadcrumbSection
        heroSection
        detailSection
        FooterComponent.sagebrushFooter()
    }

    private var breadcrumbSection: some HTML {
        section(.class("section is-small")) {
            div(.class("container")) {
                BreadcrumbComponent.adminProjectDetail(projectCodename: project.codename)
            }
        }
    }

    private var heroSection: some HTML {
        section(.class("hero is-info")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { "Project Details" }
                    h2(.class("subtitle is-3 has-text-white")) { project.codename }
                }
            }
        }
    }

    private var detailSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                div(.class("columns")) {
                    div(.class("column is-8")) {
                        projectInfoCard
                    }
                    div(.class("column is-4")) {
                        actionCard
                    }
                }
            }
        }
    }

    private var projectInfoCard: some HTML {
        div(.class("card")) {
            div(.class("card-header")) {
                p(.class("card-header-title")) { "Project Information" }
            }
            div(.class("card-content")) {
                div(.class("content")) {
                    projectBasicInfo
                    projectTimestamps
                }
            }
        }
    }

    private var projectBasicInfo: some HTML {
        dl {
            dt(.class("has-text-weight-bold")) { "Codename:" }
            dd { project.codename }

            dt(.class("has-text-weight-bold")) { "ID:" }
            dd {
                code { (try? project.requireID())?.uuidString ?? "N/A" }
            }
        }
    }

    private var projectTimestamps: some HTML {
        div {
            if let createdAt = project.createdAt, let updatedAt = project.updatedAt {
                dl {
                    dt(.class("has-text-weight-bold")) { "Created At:" }
                    dd { DateFormatter.full.string(from: createdAt) }

                    dt(.class("has-text-weight-bold")) { "Updated At:" }
                    dd { DateFormatter.full.string(from: updatedAt) }
                }
            } else if let createdAt = project.createdAt {
                dl {
                    dt(.class("has-text-weight-bold")) { "Created At:" }
                    dd { DateFormatter.full.string(from: createdAt) }
                }
            } else if let updatedAt = project.updatedAt {
                dl {
                    dt(.class("has-text-weight-bold")) { "Updated At:" }
                    dd { DateFormatter.full.string(from: updatedAt) }
                }
            }
        }
    }

    private var actionCard: some HTML {
        div(.class("card")) {
            div(.class("card-header")) {
                p(.class("card-header-title")) { "Actions" }
            }
            div(.class("card-content")) {
                div(.class("buttons is-grouped is-centered")) {
                    a(
                        .class("button is-warning is-fullwidth"),
                        .href("/admin/projects/\((try? project.requireID())?.uuidString ?? "")/edit")
                    ) {
                        "Edit Project"
                    }
                    a(
                        .class("button is-danger is-fullwidth"),
                        .href("/admin/projects/\((try? project.requireID())?.uuidString ?? "")/delete")
                    ) {
                        "Delete Project"
                    }
                    a(.class("button is-light is-fullwidth"), .href("/admin/projects")) {
                        "Back to Projects"
                    }
                }
            }
        }
    }
}
