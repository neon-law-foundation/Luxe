import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct AdminVendorDeleteConfirmPage: HTMLDocument {
    let vendor: Vendor
    let currentUser: User?

    var title: String { "Delete Vendor - \(vendor.name)" }

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
                BreadcrumbComponent.adminVendorDelete(
                    vendorName: vendor.name,
                    vendorId: (try? vendor.requireID())?.uuidString ?? ""
                )
            }
        }
    }

    private var heroSection: some HTML {
        section(.class("hero is-danger")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { "Delete Vendor" }
                    h2(.class("subtitle is-3 has-text-white")) {
                        "This action cannot be undone"
                    }
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
                                p(.class("card-header-title has-text-danger")) {
                                    "⚠️ Confirm Deletion"
                                }
                            }
                            div(.class("card-content")) {
                                confirmationContent
                            }
                        }
                    }
                }
            }
        }
    }

    private var confirmationContent: some HTML {
        div(.class("content")) {
            div(.class("notification is-warning")) {
                p(.class("has-text-weight-bold")) {
                    "⚠️ Are you sure you want to delete this vendor?"
                }
                p { "This action cannot be undone. All associated data will also be affected." }
            }

            vendorSummary
            actionButtons
        }
    }

    private var vendorSummary: some HTML {
        div(.class("box")) {
            h4(.class("title is-5")) { "Vendor to be deleted:" }
            dl {
                dt(.class("has-text-weight-bold")) { "Name:" }
                dd { vendor.name }

                dt(.class("has-text-weight-bold")) { "ID:" }
                dd {
                    code { (try? vendor.requireID())?.uuidString ?? "N/A" }
                }

                dt(.class("has-text-weight-bold")) { "Type:" }
                dd { vendorTypeDisplay }

                if let entityId = vendor.$entity.id {
                    dt(.class("has-text-weight-bold")) { "Entity Reference:" }
                    dd {
                        code { entityId.uuidString }
                    }
                }

                if let personId = vendor.$person.id {
                    dt(.class("has-text-weight-bold")) { "Person Reference:" }
                    dd {
                        code { personId.uuidString }
                    }
                }

                if let createdAt = vendor.createdAt {
                    dt(.class("has-text-weight-bold")) { "Created At:" }
                    dd { formatDate(createdAt) }
                }
            }
        }
    }

    private var actionButtons: some HTML {
        div(.class("field is-grouped is-grouped-centered")) {
            div(.class("control")) {
                form(.method(.post), .action("/admin/vendors/\((try? vendor.requireID())?.uuidString ?? "")")) {
                    input(.type(.hidden), .name("_method"), .value("DELETE"))
                    button(.class("button is-danger is-large"), .type(.submit)) {
                        span(.class("icon")) {
                            i(.class("fas fa-trash")) {}
                        }
                        span { "Yes, Delete Vendor" }
                    }
                }
            }
            div(.class("control")) {
                a(
                    .class("button is-light is-large"),
                    .href("/admin/vendors/\((try? vendor.requireID())?.uuidString ?? "")")
                ) {
                    span(.class("icon")) {
                        i(.class("fas fa-arrow-left")) {}
                    }
                    span { "Cancel" }
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
