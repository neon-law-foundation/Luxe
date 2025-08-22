import Bouncer
import Dali
import Elementary
import TouchMenu
import VaporElementary

struct AdminLegalJurisdictionsListPage: HTMLDocument {
    let jurisdictions: [LegalJurisdiction]
    let currentUser: User?

    var title: String { "Legal Jurisdictions Management - Admin" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        breadcrumbSection
        heroSection
        jurisdictionsSection
        FooterComponent.sagebrushFooter()
    }

    private var breadcrumbSection: some HTML {
        section(.class("section is-small")) {
            div(.class("container")) {
                BreadcrumbComponent.adminLegalJurisdictions()
            }
        }
    }

    private var heroSection: some HTML {
        section(.class("hero is-primary")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { "Legal Jurisdictions Management" }
                    h2(.class("subtitle is-3 has-text-white")) { "Manage all legal jurisdictions in the system" }
                }
            }
        }
    }

    private var jurisdictionsSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                h2(.class("title is-3")) { "All Legal Jurisdictions" }

                if jurisdictions.isEmpty {
                    div(.class("notification is-info")) {
                        "No legal jurisdictions found."
                    }
                } else {
                    div(.class("table-container")) {
                        table(.class("table is-fullwidth is-hoverable")) {
                            thead {
                                tr {
                                    th { "Name" }
                                    th { "Code" }
                                    th { "Actions" }
                                }
                            }
                            tbody {
                                jurisdictionsRowsContent
                            }
                        }
                    }
                }
            }
        }
    }

    private var jurisdictionsRowsContent: some HTML {
        ForEach(jurisdictions) { jurisdiction in
            jurisdictionRow(jurisdiction)
        }
    }

    private func jurisdictionRow(_ jurisdiction: LegalJurisdiction) -> some HTML {
        tr {
            td {
                a(.href("/admin/legal-jurisdictions/\((try? jurisdiction.requireID())?.uuidString ?? "")")) {
                    jurisdiction.name
                }
            }
            td { jurisdiction.code }
            td {
                div(.class("buttons")) {
                    a(
                        .class("button is-small is-info"),
                        .href("/admin/legal-jurisdictions/\((try? jurisdiction.requireID())?.uuidString ?? "")")
                    ) {
                        "View"
                    }
                }
            }
        }
    }
}
