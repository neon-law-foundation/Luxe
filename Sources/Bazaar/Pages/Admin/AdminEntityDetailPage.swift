import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct AdminEntityDetailPage: HTMLDocument {
    let entity: Entity
    let currentUser: User?

    var title: String { "Entity Details - \(entity.name)" }

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
                BreadcrumbComponent.adminEntityDetail(entityName: entity.name)
            }
        }
    }

    private var heroSection: some HTML {
        section(.class("hero is-info")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { "Entity Details" }
                    h2(.class("subtitle is-3 has-text-white")) { entity.name }
                }
            }
        }
    }

    private var detailSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                div(.class("columns")) {
                    div(.class("column is-8")) {
                        entityInfoCard
                    }
                    div(.class("column is-4")) {
                        actionCard
                    }
                }
            }
        }
    }

    private var entityInfoCard: some HTML {
        div(.class("card")) {
            div(.class("card-header")) {
                p(.class("card-header-title")) { "Entity Information" }
            }
            div(.class("card-content")) {
                div(.class("content")) {
                    entityBasicInfo
                    entityTimestamps
                }
            }
        }
    }

    private var entityBasicInfo: some HTML {
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
        }
    }

    private var entityTimestamps: some HTML {
        div {
            if let createdAt = entity.createdAt, let updatedAt = entity.updatedAt {
                dl {
                    dt(.class("has-text-weight-bold")) { "Created At:" }
                    dd { DateFormatter.full.string(from: createdAt) }

                    dt(.class("has-text-weight-bold")) { "Updated At:" }
                    dd { DateFormatter.full.string(from: updatedAt) }
                }
            } else if let createdAt = entity.createdAt {
                dl {
                    dt(.class("has-text-weight-bold")) { "Created At:" }
                    dd { DateFormatter.full.string(from: createdAt) }
                }
            } else if let updatedAt = entity.updatedAt {
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
                        .class("button is-warning is-fullwidth is-rounded"),
                        .href("/admin/entities/\((try? entity.requireID())?.uuidString ?? "")/edit")
                    ) {
                        "Edit Entity"
                    }
                    a(
                        .class("button is-danger is-fullwidth is-rounded"),
                        .href("/admin/entities/\((try? entity.requireID())?.uuidString ?? "")/delete")
                    ) {
                        "Delete Entity"
                    }
                    a(.class("button is-light is-fullwidth is-rounded"), .href("/admin/entities")) {
                        "Back to Entities"
                    }
                }
            }
        }
    }
}
