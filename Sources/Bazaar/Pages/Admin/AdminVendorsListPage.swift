import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct AdminVendorsListPage: HTMLDocument {
    let vendors: [Vendor]
    let currentUser: User?

    var title: String { "Vendor Management - Admin" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        breadcrumbSection
        heroSection
        vendorsSection
        FooterComponent.sagebrushFooter()
    }

    private var breadcrumbSection: some HTML {
        section(.class("section is-small")) {
            div(.class("container")) {
                BreadcrumbComponent.adminVendors()
            }
        }
    }

    private var heroSection: some HTML {
        section(.class("hero is-primary")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { "Vendor Management" }
                    h2(.class("subtitle is-3 has-text-white")) {
                        "Manage all accounting vendors in the system"
                    }
                }
            }
        }
    }

    private var vendorsSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                headerSection
                searchSection
                vendorsTable
            }
        }
    }

    private var headerSection: some HTML {
        div(.class("level")) {
            div(.class("level-left")) {
                h2(.class("title is-3")) { "All Vendors" }
            }
            div(.class("level-right")) {
                a(.class("button is-primary"), .href("/admin/vendors/new")) {
                    "Create New Vendor"
                }
            }
        }
    }

    private var searchSection: some HTML {
        div(.class("box")) {
            searchInput
            filterSection
        }
    }

    private var searchInput: some HTML {
        div(.class("field has-addons")) {
            div(.class("control is-expanded")) {
                input(
                    .class("input"),
                    .type(.search),
                    .placeholder("Search vendors by name..."),
                    .id("vendor-search")
                )
            }
            div(.class("control")) {
                button(.class("button is-info"), .type(.button)) {
                    span(.class("icon")) {
                        i(.class("fas fa-search")) {}
                    }
                    span { "Search" }
                }
            }
        }
    }

    private var filterSection: some HTML {
        div(.class("field is-grouped")) {
            div(.class("control")) {
                label(.class("label is-small")) { "Filter by Type:" }
                div(.class("select")) {
                    select(.id("type-filter")) {
                        option(.value("")) { "All Types" }
                        option(.value("entity")) { "Entities" }
                        option(.value("person")) { "People" }
                    }
                }
            }
            div(.class("control")) {
                label(.class("label is-small")) { " " }
                button(.class("button is-light"), .type(.button)) {
                    "Clear Filters"
                }
            }
        }
    }

    private var vendorsTable: some HTML {
        div {
            if vendors.isEmpty {
                div(.class("notification is-info")) {
                    "No vendors found. "
                    a(.href("/admin/vendors/new")) { "Create the first vendor" }
                    "."
                }
            } else {
                div(.class("table-container")) {
                    table(.class("table is-fullwidth is-hoverable")) {
                        thead {
                            tr {
                                th { "Name" }
                                th { "Type" }
                                th { "Reference" }
                                th { "Created" }
                                th { "Actions" }
                            }
                        }
                        tbody {
                            vendorRowsContent
                        }
                    }
                }
            }
        }
    }

    private var vendorRowsContent: some HTML {
        ForEach(vendors) { vendor in
            vendorRow(vendor: vendor)
        }
    }

    private func vendorRow(vendor: Vendor) -> some HTML {
        tr {
            td {
                a(.href("/admin/vendors/\((try? vendor.requireID())?.uuidString ?? "")")) {
                    vendor.name
                }
            }
            td {
                span(.class("tag " + vendorTypeTagClass(vendor))) {
                    vendorTypeDisplay(vendor)
                }
            }
            td {
                vendorReferenceDisplay(vendor)
            }
            td {
                if let createdAt = vendor.createdAt {
                    formatDate(createdAt)
                } else {
                    "—"
                }
            }
            td {
                div(.class("buttons")) {
                    a(
                        .class("button is-small is-info"),
                        .href("/admin/vendors/\((try? vendor.requireID())?.uuidString ?? "")")
                    ) {
                        "View"
                    }
                    a(
                        .class("button is-small is-warning"),
                        .href("/admin/vendors/\((try? vendor.requireID())?.uuidString ?? "")/edit")
                    ) {
                        "Edit"
                    }
                    a(
                        .class("button is-small is-danger"),
                        .href("/admin/vendors/\((try? vendor.requireID())?.uuidString ?? "")/delete")
                    ) {
                        "Delete"
                    }
                }
            }
        }
    }

    private func vendorTypeDisplay(_ vendor: Vendor) -> String {
        if vendor.$entity.id != nil {
            return "Entity"
        } else if vendor.$person.id != nil {
            return "Person"
        } else {
            return "Unknown"
        }
    }

    private func vendorTypeTagClass(_ vendor: Vendor) -> String {
        if vendor.$entity.id != nil {
            return "is-info"
        } else if vendor.$person.id != nil {
            return "is-success"
        } else {
            return "is-warning"
        }
    }

    private func vendorReferenceDisplay(_ vendor: Vendor) -> String {
        if let entityId = vendor.$entity.id {
            return "Entity ID: \(entityId.uuidString.prefix(8))..."
        } else if let personId = vendor.$person.id {
            return "Person ID: \(personId.uuidString.prefix(8))..."
        } else {
            return "—"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
