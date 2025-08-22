import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct AdminNewsletterSubscribersPage: HTMLDocument {
    let subscribers: [SubscriberInfo]
    let newsletterType: Newsletter.NewsletterName?
    let currentUser: User?

    var title: String { "Newsletter Subscribers - Admin" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        contentSection
        FooterComponent.sagebrushFooter()
    }

    private var contentSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                h1(.class("title")) { "Newsletter Subscribers" }
                p(.class("subtitle")) {
                    if let type = newsletterType {
                        "Showing subscribers for \(newsletterTypeName(type))"
                    } else {
                        "Showing all newsletter subscribers"
                    }
                }

                subscribersList

                div(.class("buttons mt-5")) {
                    a(.class("button"), .href("/admin/newsletters")) {
                        "← Back to Newsletters"
                    }
                }
            }
        }
    }

    private var subscribersList: some HTML {
        div {
            if subscribers.isEmpty {
                div(.class("notification is-info")) {
                    if let type = newsletterType {
                        "No subscribers found for \(newsletterTypeName(type))"
                    } else {
                        "No newsletter subscribers found"
                    }
                }
            } else {
                div(.class("card")) {
                    header(.class("card-header")) {
                        p(.class("card-header-title")) {
                            "Subscribers (\(subscribers.count) total)"
                        }
                    }
                    div(.class("card-content")) {
                        subscribersTable
                    }
                }
            }
        }
    }

    private var subscribersTable: some HTML {
        table(.class("table is-fullwidth is-striped")) {
            thead {
                tr {
                    th { "Email" }
                    th { "Name" }
                    th { "Subscriptions" }
                    th { "Joined" }
                }
            }
            tbody {
                ForEach(subscribers) { subscriber in
                    tr {
                        td { subscriber.email }
                        td { subscriber.name ?? "—" }
                        td { subscriptionTags(subscriber) }
                        td {
                            if let joinedDate = subscriber.createdAt {
                                formatDate(joinedDate)
                            } else {
                                "—"
                            }
                        }
                    }
                }
            }
        }
    }

    private func subscriptionTags(_ subscriber: SubscriberInfo) -> some HTML {
        div(.class("tags")) {
            if subscriber.isSubscribedToSciTech {
                span(.class("tag is-primary is-small")) {
                    "🔬 Sci Tech"
                }
            }
            if subscriber.isSubscribedToSagebrush {
                span(.class("tag is-info is-small")) {
                    "🌾 Sagebrush"
                }
            }
            if subscriber.isSubscribedToNeonLaw {
                span(.class("tag is-warning is-small")) {
                    "⚖️ Neon Law"
                }
            }
        }
    }

    private func newsletterTypeName(_ type: Newsletter.NewsletterName) -> String {
        switch type {
        case .nvSciTech: return "🔬 NV Sci Tech"
        case .sagebrush: return "🌾 Sagebrush"
        case .neonLaw: return "⚖️ Neon Law"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
