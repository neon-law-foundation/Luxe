import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct AdminAddressDetailPage: HTMLDocument {
    let address: Address
    let currentUser: User?

    var title: String { "Address Details" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        heroSection
        detailSection
        FooterComponent.sagebrushFooter()
    }

    private var heroSection: some HTML {
        section(.class("hero is-primary")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { "Address Details" }
                    h2(.class("subtitle is-3 has-text-white")) {
                        address.street
                    }
                }
            }
        }
    }

    private var detailSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                detailColumns
                actionButtons
            }
        }
    }

    private var detailColumns: some HTML {
        div(.class("columns")) {
            div(.class("column is-8")) {
                addressInfoCard
            }
            div(.class("column is-4")) {
                linkedEntitySection
                metadataSection
            }
        }
    }

    private var addressInfoCard: some HTML {
        div(.class("card")) {
            addressCardHeader
            div(.class("card-content")) {
                div(.class("content")) {
                    addressInformation
                }
            }
        }
    }

    private var addressCardHeader: some HTML {
        div(.class("card-header")) {
            p(.class("card-header-title")) { "Address Information" }
            div(.class("card-header-icon")) {
                editButton
            }
        }
    }

    private var editButton: some HTML {
        a(
            .class("button is-primary"),
            .href("/admin/addresses/\((try? address.requireID())?.uuidString ?? "")/edit")
        ) {
            span(.class("icon")) {
                i(.class("fas fa-edit")) {}
            }
            span { "Edit" }
        }
    }

    private var actionButtons: some HTML {
        div(.class("level mt-5")) {
            div(.class("level-left")) {
                backButton
            }
            div(.class("level-right")) {
                deleteButton
            }
        }
    }

    private var backButton: some HTML {
        a(.class("button"), .href("/admin/addresses")) {
            span(.class("icon")) {
                i(.class("fas fa-arrow-left")) {}
            }
            span { "Back to Addresses" }
        }
    }

    private var deleteButton: some HTML {
        a(
            .class("button is-danger"),
            .href("/admin/addresses/\((try? address.requireID())?.uuidString ?? "")/delete")
        ) {
            span(.class("icon")) {
                i(.class("fas fa-trash")) {}
            }
            span { "Delete Address" }
        }
    }

    private var addressInformation: some HTML {
        div {
            streetAddressField
            cityStateRow
            zipCountryRow
            verificationStatusField
        }
    }

    private var streetAddressField: some HTML {
        div(.class("field")) {
            label(.class("label")) { "Street Address" }
            p(.class("content")) { address.street }
        }
    }

    private var cityStateRow: some HTML {
        div(.class("columns")) {
            div(.class("column")) {
                div(.class("field")) {
                    label(.class("label")) { "City" }
                    p(.class("content")) { address.city }
                }
            }
            if let state = address.state {
                div(.class("column")) {
                    div(.class("field")) {
                        label(.class("label")) { "State/Province" }
                        p(.class("content")) { state }
                    }
                }
            }
        }
    }

    private var zipCountryRow: some HTML {
        div(.class("columns")) {
            if let zip = address.zip {
                div(.class("column")) {
                    div(.class("field")) {
                        label(.class("label")) { "ZIP/Postal Code" }
                        p(.class("content")) { zip }
                    }
                }
            }
            div(.class("column")) {
                div(.class("field")) {
                    label(.class("label")) { "Country" }
                    p(.class("content")) { address.country }
                }
            }
        }
    }

    private var verificationStatusField: some HTML {
        div(.class("field")) {
            label(.class("label")) { "Verification Status" }
            verificationBadge
        }
    }

    private var verificationBadge: some HTML {
        div {
            if address.isVerified {
                verifiedBadge
            } else {
                unverifiedBadge
            }
        }
    }

    private var verifiedBadge: some HTML {
        span(.class("tag is-success is-medium")) {
            span(.class("icon")) {
                i(.class("fas fa-check")) {}
            }
            span { "Verified" }
        }
    }

    private var unverifiedBadge: some HTML {
        span(.class("tag is-warning is-medium")) {
            span(.class("icon")) {
                i(.class("fas fa-exclamation-triangle")) {}
            }
            span { "Unverified" }
        }
    }

    private var linkedEntitySection: some HTML {
        div(.class("card mb-4")) {
            div(.class("card-header")) {
                p(.class("card-header-title")) { "Linked To" }
            }
            div(.class("card-content")) {
                linkageStatus
            }
        }
    }

    private var linkageStatus: some HTML {
        div {
            if let _ = address.$entity.id {
                entityLinkDisplay
            } else if let _ = address.$person.id {
                personLinkDisplay
            } else {
                unlinkedDisplay
            }
        }
    }

    private var entityLinkDisplay: some HTML {
        div(.class("media")) {
            div(.class("media-left")) {
                span(.class("icon is-large has-text-info")) {
                    i(.class("fas fa-building fa-2x")) {}
                }
            }
            div(.class("media-content")) {
                p(.class("subtitle is-6")) { "Entity" }
                p(.class("content is-small")) { "This address is linked to a business entity." }
            }
        }
    }

    private var personLinkDisplay: some HTML {
        div(.class("media")) {
            div(.class("media-left")) {
                span(.class("icon is-large has-text-success")) {
                    i(.class("fas fa-user fa-2x")) {}
                }
            }
            div(.class("media-content")) {
                p(.class("subtitle is-6")) { "Person" }
                p(.class("content is-small")) { "This address is linked to an individual person." }
            }
        }
    }

    private var unlinkedDisplay: some HTML {
        div(.class("media")) {
            div(.class("media-left")) {
                span(.class("icon is-large has-text-warning")) {
                    i(.class("fas fa-exclamation-triangle fa-2x")) {}
                }
            }
            div(.class("media-content")) {
                p(.class("subtitle is-6")) { "Unlinked" }
                p(.class("content is-small")) { "This address is not linked to any entity or person." }
            }
        }
    }

    private var metadataSection: some HTML {
        div(.class("card")) {
            div(.class("card-header")) {
                p(.class("card-header-title")) { "Metadata" }
            }
            div(.class("card-content")) {
                div(.class("content is-small")) {
                    if let createdAt = address.createdAt {
                        p {
                            strong { "Created: " }
                            DateFormatter.full.string(from: createdAt)
                        }
                    }
                    if let updatedAt = address.updatedAt {
                        p {
                            strong { "Updated: " }
                            DateFormatter.full.string(from: updatedAt)
                        }
                    }
                    p {
                        strong { "ID: " }
                        code { (try? address.requireID())?.uuidString ?? "Unknown" }
                    }
                }
            }
        }
    }
}
