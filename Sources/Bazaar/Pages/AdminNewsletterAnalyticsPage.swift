import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct AdminNewsletterAnalyticsPage: HTMLDocument {
    let overallAnalytics: OverallNewsletterAnalytics
    let recentEvents: [NewsletterAnalyticsEvent]
    let currentUser: User?

    var title: String { "Newsletter Analytics - Admin" }

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
                h1(.class("title")) { "Newsletter Analytics" }
                p(.class("subtitle")) { "Performance metrics and engagement statistics" }

                overviewCards
                analyticsCharts
                recentEventsTable

                div(.class("buttons mt-5")) {
                    a(.class("button"), .href("/admin/newsletters")) {
                        "← Back to Newsletters"
                    }
                }
            }
        }
    }

    private var overviewCards: some HTML {
        div(.class("columns mb-5")) {
            ForEach(Array(overallAnalytics.typeAnalytics.values)) { typeAnalytics in
                div(.class("column is-4")) {
                    div(.class("card")) {
                        div(.class("card-header")) {
                            p(.class("card-header-title")) {
                                newsletterTypeDisplay(typeAnalytics.type)
                            }
                        }
                        div(.class("card-content")) {
                            div(.class("content")) {
                                div(.class("level")) {
                                    div(.class("level-item has-text-centered")) {
                                        div {
                                            p(.class("heading")) { "Newsletters Sent" }
                                            p(.class("title is-4")) { "\(typeAnalytics.newsletterCount)" }
                                        }
                                    }
                                    div(.class("level-item has-text-centered")) {
                                        div {
                                            p(.class("heading")) { "Total Recipients" }
                                            p(.class("title is-4")) { "\(typeAnalytics.totalSent)" }
                                        }
                                    }
                                }
                                div(.class("level")) {
                                    div(.class("level-item has-text-centered")) {
                                        div {
                                            p(.class("heading")) { "Open Rate" }
                                            p(.class("title is-5 has-text-success")) {
                                                "\(String(format: "%.1f", typeAnalytics.averageOpenRate * 100))%"
                                            }
                                        }
                                    }
                                    div(.class("level-item has-text-centered")) {
                                        div {
                                            p(.class("heading")) { "Click Rate" }
                                            p(.class("title is-5 has-text-info")) {
                                                "\(String(format: "%.1f", typeAnalytics.averageClickRate * 100))%"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var analyticsCharts: some HTML {
        div(.class("card mb-5")) {
            div(.class("card-header")) {
                p(.class("card-header-title")) { "Engagement Overview" }
            }
            div(.class("card-content")) {
                div(.class("content")) {
                    p { "Detailed analytics charts and visualizations will be implemented in a future phase." }
                    p(.class("has-text-grey")) {
                        "Current implementation tracks email sends, opens, clicks, and unsubscribes for performance monitoring."
                    }
                }
            }
        }
    }

    private var recentEventsTable: some HTML {
        div(.class("card")) {
            div(.class("card-header")) {
                p(.class("card-header-title")) { "Recent Activity" }
            }
            div(.class("card-content")) {
                if recentEvents.isEmpty {
                    div(.class("notification is-info")) {
                        "No newsletter activity recorded yet."
                    }
                } else {
                    div(.class("table-container")) {
                        table(.class("table is-fullwidth is-striped")) {
                            thead {
                                tr {
                                    th { "Time" }
                                    th { "Newsletter" }
                                    th { "Event" }
                                    th { "Type" }
                                }
                            }
                            tbody {
                                ForEach(recentEvents) { event in
                                    tr {
                                        td { formatDate(event.createdAt) }
                                        td { event.subjectLine }
                                        td { eventTypeDisplay(event.eventType) }
                                        td { newsletterTypeDisplay(event.newsletterType) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func newsletterTypeDisplay(_ type: String) -> String {
        switch type {
        case "nv-sci-tech": return "🔬 NV Sci Tech"
        case "sagebrush": return "🌾 Sagebrush"
        case "neon-law": return "⚖️ Neon Law"
        default: return type
        }
    }

    private func eventTypeDisplay(_ eventType: NewsletterEventType) -> some HTML {
        let (icon, colorClass) = eventTypeStyle(eventType)
        return span(.class("tag \(colorClass) is-small")) {
            "\(icon) \(eventType.rawValue.capitalized)"
        }
    }

    private func eventTypeStyle(_ eventType: NewsletterEventType) -> (String, String) {
        switch eventType {
        case .sent: return ("📧", "is-primary")
        case .opened: return ("👁️", "is-success")
        case .clicked: return ("🖱️", "is-info")
        case .unsubscribed: return ("❌", "is-danger")
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

extension NewsletterTypeAnalytics: Identifiable {
    public var id: String { type }
}

extension NewsletterAnalyticsEvent: Identifiable {
    // id property already exists in the struct
}
