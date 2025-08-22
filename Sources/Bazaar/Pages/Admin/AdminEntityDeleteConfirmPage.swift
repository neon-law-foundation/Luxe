import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct AdminEntityDeleteConfirmPage: HTMLDocument {
    let entity: Entity
    let currentUser: User?

    var title: String { "Delete Entity - \(entity.name)" }

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
                BreadcrumbComponent.adminEntityDelete(
                    entityName: entity.name,
                    entityId: (try? entity.requireID())?.uuidString ?? ""
                )
            }
        }
    }

    private var heroSection: some HTML {
        section(.class("hero is-danger")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { "Delete Entity" }
                    h2(.class("subtitle is-3 has-text-white")) { "Confirm entity deletion" }
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
                                            "⚠️ Are you sure you want to delete this entity?"
                                        }
                                        p { "This action cannot be undone. All associated data will also be affected." }
                                    }

                                    entitySummary
                                    actionButtons
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var entitySummary: some HTML {
        div(.class("box")) {
            h4(.class("title is-5")) { "Entity to be deleted:" }
            dl {
                dt(.class("has-text-weight-bold")) { "Name:" }
                dd { entity.name }

                dt(.class("has-text-weight-bold")) { "ID:" }
                dd {
                    code { (try? entity.requireID())?.uuidString ?? "N/A" }
                }

                dt(.class("has-text-weight-bold")) { "Legal Entity Type ID:" }
                dd {
                    code { entity.$legalEntityType.id.uuidString }
                }

                if let createdAt = entity.createdAt {
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
                    .action("/admin/entities/\((try? entity.requireID())?.uuidString ?? "")/delete")
                ) {
                    input(.type(.hidden), .name("_method"), .value("DELETE"))
                    button(.class("button is-danger"), .type(.submit)) {
                        "Yes, Delete Entity"
                    }
                }
            }
            div(.class("control")) {
                a(
                    .class("button is-light"),
                    .href("/admin/entities/\((try? entity.requireID())?.uuidString ?? "")")
                ) {
                    "Cancel"
                }
            }
        }
    }
}
