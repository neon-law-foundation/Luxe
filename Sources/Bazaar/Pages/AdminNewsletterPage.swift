import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct AdminNewsletterPage: HTMLDocument {
    let newsletters: [Newsletter]
    let currentUser: User?

    var title: String { "Newsletter Management - Admin Dashboard" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        AdminNewsletterContent(newsletters: newsletters, currentUser: currentUser)
        FooterComponent.sagebrushFooter()
    }
}

struct AdminNewsletterContent: HTML {
    let newsletters: [Newsletter]
    let currentUser: User?

    var content: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                AdminNewsletterHeader()
                AdminNewsletterActions()
                AdminNewsletterList(newsletters: newsletters)
            }
        }
    }
}

struct AdminNewsletterHeader: HTML {
    var content: some HTML {
        div(.class("level mb-6")) {
            AdminHeaderLeft()
            AdminHeaderRight()
        }
    }
}

struct AdminHeaderLeft: HTML {
    var content: some HTML {
        div(.class("level-left")) {
            div(.class("level-item")) {
                div {
                    h1(.class("title is-2")) { "Newsletter Management" }
                    h2(.class("subtitle is-5")) { "Create, edit, and manage newsletters" }
                }
            }
        }
    }
}

struct AdminHeaderRight: HTML {
    var content: some HTML {
        div(.class("level-right")) {
            div(.class("level-item")) {
                a(.class("button is-primary"), .href("/admin/newsletters/create")) {
                    span(.class("icon")) {
                        "📧"
                    }
                    span { "Create Newsletter" }
                }
            }
        }
    }
}

struct AdminNewsletterActions: HTML {
    var content: some HTML {
        div(.class("notification is-info is-light mb-5")) {
            div(.class("columns")) {
                AdminActionColumn()
                AdminTypeColumn()
            }
        }
    }
}

struct AdminActionColumn: HTML {
    var content: some HTML {
        div(.class("column")) {
            h4(.class("title is-6")) { "Quick Actions" }
            div(.class("buttons")) {
                a(.class("button is-primary"), .href("/admin/newsletters/new")) {
                    span(.class("icon")) {
                        "📝"
                    }
                    span { "Create Newsletter" }
                }
                a(.class("button is-link is-outlined"), .href("/admin/newsletters/drafts")) {
                    span(.class("icon")) {
                        "✏️"
                    }
                    span { "View Drafts" }
                }
                a(.class("button is-success is-outlined"), .href("/admin/newsletters/sent")) {
                    span(.class("icon")) {
                        "✈️"
                    }
                    span { "Sent Newsletters" }
                }
                a(.class("button is-info is-outlined"), .href("/admin/newsletters/subscribers")) {
                    span(.class("icon")) {
                        "👥"
                    }
                    span { "Manage Subscribers" }
                }
                a(.class("button is-success is-outlined"), .href("/admin/newsletters/analytics")) {
                    span(.class("icon")) {
                        "📊"
                    }
                    span { "View Analytics" }
                }
            }
        }
    }
}

struct AdminTypeColumn: HTML {
    var content: some HTML {
        div(.class("column")) {
            h4(.class("title is-6")) { "Newsletter Types" }
            div(.class("tags")) {
                span(.class("tag is-primary")) { "NV Sci Tech" }
                span(.class("tag is-info")) { "Sagebrush" }
                span(.class("tag is-warning")) { "Neon Law" }
            }
        }
    }
}

struct AdminNewsletterList: HTML {
    let newsletters: [Newsletter]

    var content: some HTML {
        div(.class("card")) {
            header(.class("card-header")) {
                p(.class("card-header-title")) {
                    "Recent Newsletters"
                }
            }
            div(.class("card-content")) {
                if newsletters.isEmpty {
                    div(.class("has-text-centered py-6")) {
                        p(.class("title is-5 has-text-grey-light")) {
                            "No newsletters found"
                        }
                        p(.class("subtitle is-6 has-text-grey")) {
                            "Create your first newsletter to get started"
                        }
                    }
                } else {
                    div(.class("table-container")) {
                        table(.class("table is-fullwidth is-hoverable")) {
                            thead {
                                tr {
                                    th { "Subject" }
                                    th { "Type" }
                                    th { "Status" }
                                    th { "Created" }
                                    th { "Recipients" }
                                    th { "Actions" }
                                }
                            }
                            tbody {
                                for newsletter in newsletters {
                                    AdminNewsletterRow(newsletter: newsletter)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct AdminNewsletterRow: HTML {
    let newsletter: Newsletter

    var content: some HTML {
        tr {
            td {
                strong { newsletter.subjectLine }
            }
            td {
                span(.class("tag \(getTypeClass(newsletter.name))")) {
                    newsletterTypeDisplay(newsletter.name)
                }
            }
            td {
                NewsletterStatusTag(newsletter: newsletter)
            }
            td {
                small(.class("has-text-grey")) {
                    formatDisplayDate(newsletter.createdAt)
                }
            }
            td {
                NewsletterRecipientCount(newsletter: newsletter)
            }
            td {
                NewsletterActionButtons(newsletter: newsletter)
            }
        }
    }

    private func getTypeClass(_ name: Newsletter.NewsletterName) -> String {
        switch name {
        case .nvSciTech:
            return "is-primary"
        case .sagebrush:
            return "is-info"
        case .neonLaw:
            return "is-warning"
        }
    }

    private func newsletterTypeDisplay(_ name: Newsletter.NewsletterName) -> String {
        switch name {
        case .nvSciTech:
            return "NV Sci Tech"
        case .sagebrush:
            return "Sagebrush"
        case .neonLaw:
            return "Neon Law"
        }
    }

    private func formatDisplayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct NewsletterStatusTag: HTML {
    let newsletter: Newsletter

    var content: some HTML {
        if newsletter.isSent {
            span(.class("tag is-success")) { "Sent" }
        } else {
            span(.class("tag is-warning")) { "Draft" }
        }
    }
}

struct NewsletterRecipientCount: HTML {
    let newsletter: Newsletter

    var content: some HTML {
        if newsletter.isSent {
            span(.class("has-text-weight-semibold")) { "\(newsletter.recipientCount)" }
        } else {
            span(.class("has-text-grey")) { "—" }
        }
    }
}

struct NewsletterActionButtons: HTML {
    let newsletter: Newsletter

    var content: some HTML {
        div(.class("buttons are-small")) {
            a(.class("button is-info is-outlined"), .href("/admin/newsletters/\(newsletter.id)/edit")) {
                span(.class("icon")) {
                    "✏️"
                }
                span { "Edit" }
            }

            if newsletter.isDraft {
                a(.class("button is-success is-outlined"), .href("/admin/newsletters/\(newsletter.id)/send")) {
                    span(.class("icon")) {
                        "✈️"
                    }
                    span { "Send" }
                }

                a(.class("button is-danger is-outlined"), .href("/admin/newsletters/\(newsletter.id)/delete")) {
                    span(.class("icon")) {
                        "🗑️"
                    }
                    span { "Delete" }
                }
            } else if let sentAt = newsletter.sentAt {
                let dateString = formatDateForUrl(sentAt)

                a(.class("button is-link is-outlined"), .href("/newsletters/\(newsletter.name.rawValue)/\(dateString)"))
                {
                    span(.class("icon")) {
                        "👁️"
                    }
                    span { "View" }
                }
            }
        }
    }

    private func formatDateForUrl(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMM"
        return formatter.string(from: date)
    }
}
