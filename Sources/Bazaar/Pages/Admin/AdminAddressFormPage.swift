import Bouncer
import Dali
import Elementary
import TouchMenu
import VaporElementary

struct AdminAddressFormPage: HTMLDocument {
    let address: Address?
    let entities: [Entity]
    let people: [Person]
    let currentUser: User?

    var isEditing: Bool { address != nil }
    var title: String { isEditing ? "Edit Address" : "Create New Address" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        heroSection
        formSection
        FooterComponent.sagebrushFooter()
    }

    private var heroSection: some HTML {
        section(.class("hero is-primary")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { title }
                    h2(.class("subtitle is-3 has-text-white")) {
                        isEditing ? "Update address information" : "Add a new address to the system"
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
                                    isEditing ? "Edit Address" : "Create New Address"
                                }
                            }
                            div(.class("card-content")) {
                                addressForm
                            }
                        }
                    }
                }
            }
        }
    }

    private var addressForm: some HTML {
        div {
            form(.method(.post), .action(formAction)) {
                if isEditing {
                    input(.type(.hidden), .name("_method"), .value("PATCH"))
                }

                div(.class("field")) {
                    label(.class("label"), .for("entityOrPersonSelect")) { "Entity or Person" }
                    div(.class("control")) {
                        div(.class("select is-fullwidth")) {
                            select(.id("entityOrPersonSelect"), .name("entityOrPersonSelect"), .required) {
                                option(.value("")) { "Select an entity or person..." }

                                if !entities.isEmpty {
                                    optgroup(.label("Entities")) {
                                        ForEach(entities) { entity in
                                            entityOption(entity)
                                        }
                                    }
                                }

                                if !people.isEmpty {
                                    optgroup(.label("People")) {
                                        ForEach(people) { person in
                                            personOption(person)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    p(.class("help")) { "Select the entity or person this address belongs to" }
                }

                // Hidden fields for entity and person IDs
                input(.type(.hidden), .id("entityId"), .name("entityId"))
                input(.type(.hidden), .id("personId"), .name("personId"))

                div(.class("field")) {
                    label(.class("label")) { "Street Address" }
                    div(.class("control")) {
                        input(
                            .class("input"),
                            .type(.text),
                            .name("street"),
                            .value(address?.street ?? ""),
                            .required,
                            .placeholder("Enter street address")
                        )
                    }
                    p(.class("help")) { "Street number and name" }
                }

                div(.class("columns")) {
                    div(.class("column")) {
                        div(.class("field")) {
                            label(.class("label")) { "City" }
                            div(.class("control")) {
                                input(
                                    .class("input"),
                                    .type(.text),
                                    .name("city"),
                                    .value(address?.city ?? ""),
                                    .required,
                                    .placeholder("Enter city")
                                )
                            }
                        }
                    }
                    div(.class("column")) {
                        div(.class("field")) {
                            label(.class("label")) { "State/Province" }
                            div(.class("control")) {
                                input(
                                    .class("input"),
                                    .type(.text),
                                    .name("state"),
                                    .value(address?.state ?? ""),
                                    .placeholder("Enter state or province (optional)")
                                )
                            }
                        }
                    }
                }

                div(.class("columns")) {
                    div(.class("column")) {
                        div(.class("field")) {
                            label(.class("label")) { "ZIP/Postal Code" }
                            div(.class("control")) {
                                input(
                                    .class("input"),
                                    .type(.text),
                                    .name("zip"),
                                    .value(address?.zip ?? ""),
                                    .placeholder("Enter ZIP or postal code (optional)")
                                )
                            }
                        }
                    }
                    div(.class("column")) {
                        div(.class("field")) {
                            label(.class("label")) { "Country" }
                            div(.class("control")) {
                                input(
                                    .class("input"),
                                    .type(.text),
                                    .name("country"),
                                    .value(address?.country ?? "USA"),
                                    .required,
                                    .placeholder("Enter country")
                                )
                            }
                        }
                    }
                }

                div(.class("field")) {
                    div(.class("control")) {
                        label(.class("checkbox")) {
                            if address?.isVerified == true {
                                input(
                                    .type(.checkbox),
                                    .name("isVerified"),
                                    .value("true"),
                                    .checked
                                )
                            } else {
                                input(
                                    .type(.checkbox),
                                    .name("isVerified"),
                                    .value("true")
                                )
                            }
                            " Address is verified"
                        }
                    }
                    p(.class("help")) { "Check if this address has been verified as accurate" }
                }

                div(.class("field is-grouped")) {
                    div(.class("control")) {
                        button(.class("button is-primary"), .type(.submit)) {
                            isEditing ? "Update Address" : "Create Address"
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
                // JavaScript to handle the dropdown selection
                """
                document.addEventListener('DOMContentLoaded', function() {
                    const select = document.getElementById('entityOrPersonSelect');
                    const entityIdField = document.getElementById('entityId');
                    const personIdField = document.getElementById('personId');

                    select.addEventListener('change', function() {
                        const value = this.value;
                        if (value.startsWith('entity:')) {
                            entityIdField.value = value.replace('entity:', '');
                            personIdField.value = '';
                        } else if (value.startsWith('person:')) {
                            personIdField.value = value.replace('person:', '');
                            entityIdField.value = '';
                        } else {
                            entityIdField.value = '';
                            personIdField.value = '';
                        }
                    });
                });
                """
            }
        }
    }

    private func entityOption(_ entity: Entity) -> some HTML {
        let entityId = (try? entity.requireID())?.uuidString ?? ""
        let isSelected = address?.$entity.id?.uuidString == entityId

        if isSelected {
            return option(.value("entity:\(entityId)"), .selected) { entity.name }
        } else {
            return option(.value("entity:\(entityId)")) { entity.name }
        }
    }

    private func personOption(_ person: Person) -> some HTML {
        let personId = (try? person.requireID())?.uuidString ?? ""
        let isSelected = address?.$person.id?.uuidString == personId

        if isSelected {
            return option(.value("person:\(personId)"), .selected) { "\(person.name) (\(person.email))" }
        } else {
            return option(.value("person:\(personId)")) { "\(person.name) (\(person.email))" }
        }
    }

    private var formAction: String {
        if let address = address {
            return "/admin/addresses/\((try? address.requireID())?.uuidString ?? "")"
        } else {
            return "/admin/addresses"
        }
    }

    private var cancelUrl: String {
        if let address = address {
            return "/admin/addresses/\((try? address.requireID())?.uuidString ?? "")"
        } else {
            return "/admin/addresses"
        }
    }
}
