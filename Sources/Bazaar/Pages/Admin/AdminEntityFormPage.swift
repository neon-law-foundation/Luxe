import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct AdminEntityFormPage: HTMLDocument {
    let entity: Entity?
    let entityTypes: [EntityType]
    let currentUser: User?

    private var isEditing: Bool { entity != nil }

    var title: String {
        isEditing ? "Edit Entity" : "Add New Entity"
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
                    BreadcrumbComponent.adminEntityEdit(
                        entityName: entity!.name,
                        entityId: (try? entity!.requireID())?.uuidString ?? ""
                    )
                } else {
                    BreadcrumbComponent.adminEntityNew()
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
                        isEditing ? "Update entity information" : "Create a new entity"
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
                                    isEditing ? "Edit Entity" : "Entity Details"
                                }
                            }
                            div(.class("card-content")) {
                                entityForm
                            }
                        }
                    }
                }
            }
        }
    }

    private var entityForm: some HTML {
        form(
            .method(.post),
            .action(isEditing ? "/admin/entities/\((try? entity!.requireID())?.uuidString ?? "")" : "/admin/entities")
        ) {
            if isEditing {
                input(.type(.hidden), .name("_method"), .value("PATCH"))
            }

            div(.class("field")) {
                label(.class("label"), .for("name")) { "Name" }
                div(.class("control")) {
                    input(
                        .class("input"),
                        .type(.text),
                        .id("name"),
                        .name("name"),
                        .value(entity?.name ?? ""),
                        .placeholder("Enter entity name"),
                        .required
                    )
                }
                p(.class("help")) { "The name of the entity" }
            }

            div(.class("field")) {
                label(.class("label"), .for("legalEntityTypeId")) { "Legal Entity Type" }
                div(.class("control")) {
                    div(.class("select is-fullwidth")) {
                        select(.id("legalEntityTypeId"), .name("legalEntityTypeId"), .required) {
                            option(.value("")) { "Select an entity type..." }
                            ForEach(entityTypes) { entityType in
                                entityTypeOption(entityType)
                            }
                        }
                    }
                }
                p(.class("help")) { "Select the legal entity type" }
            }

            div(.class("field is-grouped")) {
                div(.class("control")) {
                    button(.class("button is-primary"), .type(.submit)) {
                        isEditing ? "Update Entity" : "Create Entity"
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

    private func entityTypeOption(_ entityType: EntityType) -> some HTML {
        let entityTypeId = (try? entityType.requireID())?.uuidString ?? ""
        let isSelected = entity?.$legalEntityType.id.uuidString == entityTypeId

        if isSelected {
            return option(.value(entityTypeId), .selected) { entityType.name }
        } else {
            return option(.value(entityTypeId)) { entityType.name }
        }
    }

    private var cancelUrl: String {
        if isEditing, let entityId = try? entity!.requireID() {
            return "/admin/entities/\(entityId.uuidString)"
        }
        return "/admin/entities"
    }
}
