import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct AdminVendorFormPage: HTMLDocument {
    let vendor: Vendor?
    let entities: [Entity]
    let people: [Person]
    let currentUser: User?

    private var isEditing: Bool { vendor != nil }

    var title: String {
        isEditing ? "Edit Vendor" : "Add New Vendor"
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
                    BreadcrumbComponent.adminVendorEdit(
                        vendorName: vendor!.name,
                        vendorId: (try? vendor!.requireID())?.uuidString ?? ""
                    )
                } else {
                    BreadcrumbComponent.adminVendorNew()
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
                        isEditing ? "Update vendor information" : "Create a new vendor"
                    }
                }
            }
        }
    }

    private var formSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                div(.class("columns is-centered")) {
                    div(.class("column is-8")) {
                        div(.class("card")) {
                            div(.class("card-header")) {
                                p(.class("card-header-title")) {
                                    isEditing ? "Edit Vendor" : "Vendor Details"
                                }
                            }
                            div(.class("card-content")) {
                                vendorForm
                            }
                        }
                    }
                }
            }
        }
    }

    private var vendorForm: some HTML {
        div {
            form(
                .method(.post),
                .action(isEditing ? "/admin/vendors/\((try? vendor!.requireID())?.uuidString ?? "")" : "/admin/vendors")
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
                            .value(vendor?.name ?? ""),
                            .placeholder("Enter vendor name"),
                            .required
                        )
                    }
                    p(.class("help")) { "The name of the vendor" }
                }

                div(.class("field")) {
                    label(.class("label")) { "Vendor Type" }
                    div(.class("control")) {
                        label(.class("radio")) {
                            if isEditing && vendor!.$entity.id != nil {
                                input(
                                    .type(.radio),
                                    .name("vendorType"),
                                    .value("entity"),
                                    .id("type-entity"),
                                    .checked
                                )
                            } else {
                                input(
                                    .type(.radio),
                                    .name("vendorType"),
                                    .value("entity"),
                                    .id("type-entity")
                                )
                            }
                            " Entity"
                        }
                        " "
                        label(.class("radio")) {
                            if isEditing && vendor!.$person.id != nil {
                                input(
                                    .type(.radio),
                                    .name("vendorType"),
                                    .value("person"),
                                    .id("type-person"),
                                    .checked
                                )
                            } else {
                                input(
                                    .type(.radio),
                                    .name("vendorType"),
                                    .value("person"),
                                    .id("type-person")
                                )
                            }
                            " Person"
                        }
                    }
                    p(.class("help")) { "Select whether this vendor is an entity or person" }
                }

                div(.class("field"), .id("entity-field"), .style(entityFieldDisplay)) {
                    label(.class("label"), .for("entityId")) { "Entity" }
                    div(.class("control")) {
                        div(.class("select is-fullwidth")) {
                            select(.id("entityId"), .name("entityId")) {
                                option(.value("")) { "Select an entity..." }
                                ForEach(entities) { entity in
                                    entityOption(entity)
                                }
                            }
                        }
                    }
                    p(.class("help")) { "Select the entity this vendor represents" }
                }

                div(.class("field"), .id("person-field"), .style(personFieldDisplay)) {
                    label(.class("label"), .for("personId")) { "Person" }
                    div(.class("control")) {
                        div(.class("select is-fullwidth")) {
                            select(.id("personId"), .name("personId")) {
                                option(.value("")) { "Select a person..." }
                                ForEach(people) { person in
                                    personOption(person)
                                }
                            }
                        }
                    }
                    p(.class("help")) { "Select the person this vendor represents" }
                }

                div(.class("field is-grouped")) {
                    div(.class("control")) {
                        button(.class("button is-primary"), .type(.submit)) {
                            isEditing ? "Update Vendor" : "Create Vendor"
                        }
                    }
                    div(.class("control")) {
                        a(.class("button is-light"), .href(cancelUrl)) {
                            "Cancel"
                        }
                    }
                }
            }

            script {
                """
                document.addEventListener('DOMContentLoaded', function() {
                    const entityRadio = document.getElementById('type-entity');
                    const personRadio = document.getElementById('type-person');
                    const entityField = document.getElementById('entity-field');
                    const personField = document.getElementById('person-field');
                    const entitySelect = document.getElementById('entityId');
                    const personSelect = document.getElementById('personId');

                    function toggleFields() {
                        if (entityRadio.checked) {
                            entityField.style.display = 'block';
                            personField.style.display = 'none';
                            personSelect.value = '';
                            entitySelect.required = true;
                            personSelect.required = false;
                        } else if (personRadio.checked) {
                            entityField.style.display = 'none';
                            personField.style.display = 'block';
                            entitySelect.value = '';
                            personSelect.required = true;
                            entitySelect.required = false;
                        } else {
                            entityField.style.display = 'none';
                            personField.style.display = 'none';
                            entitySelect.required = false;
                            personSelect.required = false;
                        }
                    }

                    entityRadio.addEventListener('change', toggleFields);
                    personRadio.addEventListener('change', toggleFields);

                    // Initialize on page load
                    toggleFields();
                });
                """
            }
        }
    }

    private func entityOption(_ entity: Entity) -> some HTML {
        let entityId = (try? entity.requireID())?.uuidString ?? ""
        let isSelected = vendor?.$entity.id?.uuidString == entityId

        if isSelected {
            return option(.value(entityId), .selected) { entity.name }
        } else {
            return option(.value(entityId)) { entity.name }
        }
    }

    private func personOption(_ person: Person) -> some HTML {
        let personId = (try? person.requireID())?.uuidString ?? ""
        let isSelected = vendor?.$person.id?.uuidString == personId

        if isSelected {
            return option(.value(personId), .selected) { person.name }
        } else {
            return option(.value(personId)) { person.name }
        }
    }

    private var entityFieldDisplay: String {
        if isEditing && vendor!.$entity.id != nil {
            return "display: block;"
        } else if !isEditing {
            return "display: none;"
        } else {
            return "display: none;"
        }
    }

    private var personFieldDisplay: String {
        if isEditing && vendor!.$person.id != nil {
            return "display: block;"
        } else if !isEditing {
            return "display: none;"
        } else {
            return "display: none;"
        }
    }

    private var cancelUrl: String {
        if isEditing, let vendorId = try? vendor!.requireID() {
            return "/admin/vendors/\(vendorId.uuidString)"
        }
        return "/admin/vendors"
    }
}
