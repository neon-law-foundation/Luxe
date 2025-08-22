import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct NewsletterPage: HTMLDocument {
    let newsletter: Newsletter
    let currentUser: User?

    var title: String { "\(newsletter.subjectLine) - Newsletter" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }

        // SEO-friendly meta tags and Open Graph data
        meta(.property("og:title"), .content(newsletter.subjectLine))
        meta(.property("og:description"), .content("Newsletter: \(newsletter.subjectLine)"))
        meta(.property("og:type"), .content("article"))
        meta(.name("description"), .content("Newsletter: \(newsletter.subjectLine)"))
        meta(.name("keywords"), .content("newsletter, \(newsletter.name.rawValue)"))

        // Structured data markup
        script(.type("application/ld+json")) {
            """
            {
                "@context": "https://schema.org",
                "@type": "Article",
                "headline": "\(newsletter.subjectLine)",
                "datePublished": "\(formatDate(newsletter.sentAt ?? newsletter.createdAt))",
                "author": {
                    "@type": "Organization",
                    "name": "\(organizationName(for: newsletter.name))"
                },
                "publisher": {
                    "@type": "Organization",
                    "name": "\(organizationName(for: newsletter.name))"
                },
                "articleSection": "Newsletter"
            }
            """
        }
    }

    var body: some HTML {
        Navigation()
        NewsletterContent(newsletter: newsletter, currentUser: currentUser)
        FooterComponent.sagebrushFooter()
    }

    private func organizationName(for name: Newsletter.NewsletterName) -> String {
        switch name {
        case .nvSciTech:
            return "NV Sci Tech"
        case .sagebrush:
            return "Sagebrush"
        case .neonLaw:
            return "Neon Law"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}

struct NewsletterContent: HTML {
    let newsletter: Newsletter
    let currentUser: User?

    var content: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                NewsletterArticle(newsletter: newsletter, currentUser: currentUser)
            }
        }
    }
}

struct NewsletterArticle: HTML {
    let newsletter: Newsletter
    let currentUser: User?

    var content: some HTML {
        div(.class("columns")) {
            div(.class("column is-8 is-offset-2")) {
                article(.class("content")) {
                    NewsletterHeader(newsletter: newsletter)
                    TouchMenu.MarkdownContent(markdown: newsletter.markdownContent, style: .bulma)
                    NewsletterFooter(newsletter: newsletter, currentUser: currentUser)
                }
            }
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
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct NewsletterHeader: HTML {
    let newsletter: Newsletter

    var content: some HTML {
        div(.class("newsletter-header mb-6")) {
            span(.class("tag is-primary is-medium mb-2")) {
                newsletterTypeDisplay(newsletter.name)
            }
            h1(.class("title is-1 has-text-primary")) {
                newsletter.subjectLine
            }

            if let sentAt = newsletter.sentAt {
                p(.class("subtitle is-6 has-text-grey")) {
                    "Published on \(formatDisplayDate(sentAt))"
                }
            }
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
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct NewsletterFooter: HTML {
    let newsletter: Newsletter
    let currentUser: User?

    var content: some HTML {
        div(.class("newsletter-footer mt-6 pt-4 has-background-light p-4")) {
            NewsletterMetadata(newsletter: newsletter)
            NewsletterSubscriptionActions(currentUser: currentUser)
        }
    }
}

struct NewsletterMetadata: HTML {
    let newsletter: Newsletter

    var content: some HTML {
        div(.class("columns is-multiline")) {
            div(.class("column is-half")) {
                p(.class("has-text-grey is-size-7")) {
                    "Newsletter Type: \(newsletterTypeDisplay(newsletter.name))"
                }
                if let sentAt = newsletter.sentAt {
                    p(.class("has-text-grey is-size-7")) {
                        "Sent: \(formatDisplayDate(sentAt))"
                    }
                }
            }
            div(.class("column is-half")) {
                if newsletter.recipientCount > 0 {
                    p(.class("has-text-grey is-size-7")) {
                        "Recipients: \(newsletter.recipientCount)"
                    }
                }
            }
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
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

struct NewsletterSubscriptionActions: HTML {
    let currentUser: User?

    var content: some HTML {
        div(.class("mt-4")) {
            if currentUser != nil {
                a(.class("button is-primary is-small"), .href("/me")) {
                    "Manage Newsletter Subscriptions"
                }
            } else {
                a(.class("button is-primary is-small"), .href("/login")) {
                    "Subscribe to Newsletters"
                }
            }
        }
    }
}
