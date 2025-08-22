import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct AdminVendorDetailPage: HTMLDocument {
    let vendor: Vendor
    let currentUser: User?

    var title: String { "Vendor Details - \(vendor.name)" }

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
                BreadcrumbComponent.adminVendorDetail(vendorName: vendor.name)
            }
        }
    }

    private var heroSection: some HTML {
        section(.class("hero is-info")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { "Vendor Details" }
                    h2(.class("subtitle is-3 has-text-white")) { vendor.name }
                }
            }
        }
    }

    private var detailSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                div(.class("columns")) {
                    div(.class("column is-8")) {
                        vendorDetailCard
                    }
                    div(.class("column is-4")) {
                        actionsCard
                    }
                }
            }
        }
    }

    private var vendorDetailCard: some HTML {
        div(.class("box")) {
            h3(.class("title is-4")) { "Vendor Information" }

            div(.class("field")) {
                label(.class("label")) { "Name" }
                div(.class("control")) {
                    input(.class("input"), .type(.text), .value(vendor.name), .disabled)
                }
            }

            div(.class("field")) {
                label(.class("label")) { "Type" }
                div(.class("control")) {
                    input(.class("input"), .type(.text), .value(vendorTypeDisplay), .disabled)
                }
            }

            if let entityId = vendor.$entity.id {
                div(.class("field")) {
                    label(.class("label")) { "Entity Reference" }
                    div(.class("control")) {
                        input(.class("input"), .type(.text), .value(entityId.uuidString), .disabled)
                    }
                    p(.class("help")) { "This vendor is linked to an entity" }
                }
            }

            if let personId = vendor.$person.id {
                div(.class("field")) {
                    label(.class("label")) { "Person Reference" }
                    div(.class("control")) {
                        input(.class("input"), .type(.text), .value(personId.uuidString), .disabled)
                    }
                    p(.class("help")) { "This vendor is linked to a person" }
                }
            }

            if let createdAt = vendor.createdAt {
                div(.class("field")) {
                    label(.class("label")) { "Created" }
                    div(.class("control")) {
                        input(.class("input"), .type(.text), .value(formatDate(createdAt)), .disabled)
                    }
                }
            }

            if let updatedAt = vendor.updatedAt {
                div(.class("field")) {
                    label(.class("label")) { "Last Updated" }
                    div(.class("control")) {
                        input(.class("input"), .type(.text), .value(formatDate(updatedAt)), .disabled)
                    }
                }
            }
        }
    }

    private var actionsCard: some HTML {
        div(.class("box")) {
            h3(.class("title is-5")) { "Actions" }

            div(.class("buttons is-flex is-flex-direction-column")) {
                a(
                    .class("button is-warning is-fullwidth"),
                    .href("/admin/vendors/\((try? vendor.requireID())?.uuidString ?? "")/edit")
                ) {
                    span(.class("icon")) {
                        i(.class("fas fa-edit")) {}
                    }
                    span { "Edit Vendor" }
                }

                a(
                    .class("button is-danger is-fullwidth"),
                    .href("/admin/vendors/\((try? vendor.requireID())?.uuidString ?? "")/delete")
                ) {
                    span(.class("icon")) {
                        i(.class("fas fa-trash")) {}
                    }
                    span { "Delete Vendor" }
                }

                a(.class("button is-light is-fullwidth"), .href("/admin/vendors")) {
                    span(.class("icon")) {
                        i(.class("fas fa-arrow-left")) {}
                    }
                    span { "Back to Vendors" }
                }
            }
        }
    }

    private var vendorTypeDisplay: String {
        if vendor.$entity.id != nil {
            return "Entity"
        } else if vendor.$person.id != nil {
            return "Person"
        } else {
            return "Unknown"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
