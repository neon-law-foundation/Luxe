import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct AdminEntitiesListPage: HTMLDocument {
    let entities: [Entity]
    let currentUser: User?

    var title: String { "Entities Management - Admin" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        breadcrumbSection
        heroSection
        entitiesSection
        FooterComponent.sagebrushFooter()
    }

    private var breadcrumbSection: some HTML {
        section(.class("section is-small")) {
            div(.class("container")) {
                BreadcrumbComponent.adminEntities()
            }
        }
    }

    private var heroSection: some HTML {
        section(.class("hero is-primary")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { "Entities Management" }
                    h2(.class("subtitle is-3 has-text-white")) { "Manage all entities in the system" }
                }
            }
        }
    }

    private var entitiesSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                div(.class("level")) {
                    div(.class("level-left")) {
                        h2(.class("title is-3")) { "All Entities" }
                    }
                    div(.class("level-right")) {
                        a(.class("button is-primary"), .href("/admin/entities/new")) {
                            "Add New Entity"
                        }
                    }
                }

                if entities.isEmpty {
                    div(.class("notification is-info")) {
                        "No entities found. "
                        a(.href("/admin/entities/new")) { "Create the first entity" }
                        "."
                    }
                } else {
                    div(.class("table-container")) {
                        table(.class("table is-fullwidth is-hoverable")) {
                            thead {
                                tr {
                                    th { "Name" }
                                    th { "Legal Entity Type" }
                                    th { "Created At" }
                                    th { "Actions" }
                                }
                            }
                            tbody {
                                entitiesRowsContent
                            }
                        }
                    }
                }
            }
        }
    }

    private var entitiesRowsContent: some HTML {
        ForEach(entities) { entity in
            entityRow(entity)
        }
    }

    private func entityRow(_ entity: Entity) -> some HTML {
        tr {
            td {
                a(.href("/admin/entities/\((try? entity.requireID())?.uuidString ?? "")")) {
                    entity.name
                }
            }
            td {
                // Note: The entity type name would need to be loaded via eager loading
                "Entity Type"  // Placeholder - will be populated when we load the relationship
            }
            td {
                if let createdAt = entity.createdAt {
                    DateFormatter.short.string(from: createdAt)
                } else {
                    "N/A"
                }
            }
            td {
                div(.class("buttons")) {
                    a(
                        .class("button is-small is-info"),
                        .href("/admin/entities/\((try? entity.requireID())?.uuidString ?? "")")
                    ) {
                        "View"
                    }
                    a(
                        .class("button is-small is-warning"),
                        .href("/admin/entities/\((try? entity.requireID())?.uuidString ?? "")/edit")
                    ) {
                        "Edit"
                    }
                    a(
                        .class("button is-small is-danger"),
                        .href("/admin/entities/\((try? entity.requireID())?.uuidString ?? "")/delete")
                    ) {
                        "Delete"
                    }
                }
            }
        }
    }
}
