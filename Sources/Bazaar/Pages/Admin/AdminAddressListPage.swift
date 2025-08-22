import Bouncer
import Dali
import Elementary
import TouchMenu
import VaporElementary

struct AdminAddressListPage: HTMLDocument {
    let addresses: [Address]
    let currentUser: User?

    var title: String { "Address Management" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        heroSection
        addressesSection
        FooterComponent.sagebrushFooter()
    }

    private var heroSection: some HTML {
        section(.class("hero is-primary")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { "Address Management" }
                    h2(.class("subtitle is-3 has-text-white")) {
                        "Manage address records for entities and people"
                    }
                }
            }
        }
    }

    private var addressesSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                addressHeader
                addressContent
            }
        }
    }

    private var addressHeader: some HTML {
        div(.class("level")) {
            div(.class("level-left")) {
                h2(.class("title is-3")) { "Addresses" }
            }
            div(.class("level-right")) {
                newAddressButton
            }
        }
    }

    private var newAddressButton: some HTML {
        a(.class("button is-primary"), .href("/admin/addresses/new")) {
            span(.class("icon")) {
                i(.class("fas fa-plus")) {}
            }
            span { "New Address" }
        }
    }

    private var addressContent: some HTML {
        div {
            if addresses.isEmpty {
                emptyAddressesNotification
            } else {
                addressTable
            }
        }
    }

    private var emptyAddressesNotification: some HTML {
        div(.class("notification is-info")) {
            p {
                "No addresses found. "
                a(.href("/admin/addresses/new")) { "Create the first address" }
                "."
            }
        }
    }

    private var addressTable: some HTML {
        div(.class("table-container")) {
            table(.class("table is-fullwidth is-striped is-hoverable")) {
                addressTableHead
                addressTableBody
            }
        }
    }

    private var addressTableHead: some HTML {
        thead {
            tr {
                th { "Street" }
                th { "City" }
                th { "State" }
                th { "Country" }
                th { "Linked To" }
                th { "Verified" }
                th { "Actions" }
            }
        }
    }

    private var addressTableBody: some HTML {
        tbody {
            ForEach(addresses) { address in
                addressRow(address)
            }
        }
    }

    private func addressRow(_ address: Address) -> some HTML {
        tr {
            td { address.street }
            td { address.city }
            td { address.state ?? "-" }
            td { address.country }
            td { addressLinkageTag(address) }
            td { addressVerificationTag(address) }
            td { addressActions(address) }
        }
    }

    private func addressLinkageTag(_ address: Address) -> some HTML {
        if let _ = address.$entity.id {
            span(.class("tag is-info")) { "Entity" }
        } else if let _ = address.$person.id {
            span(.class("tag is-success")) { "Person" }
        } else {
            span(.class("tag is-warning")) { "Unlinked" }
        }
    }

    private func addressVerificationTag(_ address: Address) -> some HTML {
        if address.isVerified {
            span(.class("tag is-success")) { "Verified" }
        } else {
            span(.class("tag is-warning")) { "Unverified" }
        }
    }

    private func addressActions(_ address: Address) -> some HTML {
        div(.class("field is-grouped")) {
            p(.class("control")) {
                viewButton(address)
            }
            p(.class("control")) {
                editButton(address)
            }
        }
    }

    private func viewButton(_ address: Address) -> some HTML {
        a(
            .class("button is-small is-info"),
            .href("/admin/addresses/\((try? address.requireID())?.uuidString ?? "")")
        ) {
            span(.class("icon is-small")) {
                i(.class("fas fa-eye")) {}
            }
            span { "View" }
        }
    }

    private func editButton(_ address: Address) -> some HTML {
        a(
            .class("button is-small is-primary"),
            .href("/admin/addresses/\((try? address.requireID())?.uuidString ?? "")/edit")
        ) {
            span(.class("icon is-small")) {
                i(.class("fas fa-edit")) {}
            }
            span { "Edit" }
        }
    }
}
