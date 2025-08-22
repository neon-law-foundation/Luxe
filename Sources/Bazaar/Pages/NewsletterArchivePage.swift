import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct NewsletterArchivePage: HTMLDocument {
    let newsletters: [Newsletter]
    let pagination: PaginationInfo
    let currentType: Newsletter.NewsletterName?
    let currentUser: User?

    var title: String {
        if let type = currentType {
            return "\(newsletterTypeDisplay(type)) Newsletter Archive - Sagebrush"
        } else {
            return "Newsletter Archive - Sagebrush"
        }
    }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }

        // SEO-friendly meta tags
        meta(
            .name("description"),
            .content("Browse our newsletter archive with articles on technology, law, and business insights")
        )
        meta(.name("keywords"), .content("newsletter, archive, technology, law, business"))

        // Open Graph data
        meta(.property("og:title"), .content(title))
        meta(.property("og:description"), .content("Browse our newsletter archive"))
        meta(.property("og:type"), .content("website"))
    }

    var body: some HTML {
        Navigation()
        NewsletterArchiveContent(
            newsletters: newsletters,
            pagination: pagination,
            currentType: currentType,
            currentUser: currentUser
        )
        FooterComponent.sagebrushFooter()
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
}

struct PaginationInfo {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}

struct NewsletterArchiveContent: HTML {
    let newsletters: [Newsletter]
    let pagination: PaginationInfo
    let currentType: Newsletter.NewsletterName?
    let currentUser: User?

    var content: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                NewsletterArchiveHeader(currentType: currentType)
                NewsletterTypeFilter(currentType: currentType)
                NewsletterList(newsletters: newsletters)
                NewsletterPagination(pagination: pagination, currentType: currentType)
            }
        }
    }
}

struct NewsletterArchiveHeader: HTML {
    let currentType: Newsletter.NewsletterName?

    var content: some HTML {
        div(.class("has-text-centered mb-6")) {
            h1(.class("title is-1 has-text-primary")) {
                if let type = currentType {
                    "\(newsletterTypeDisplay(type)) Newsletter Archive"
                } else {
                    "Newsletter Archive"
                }
            }
            p(.class("subtitle is-4 has-text-grey")) {
                "Browse our collection of newsletters covering technology, law, and business insights"
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
}

struct NewsletterTypeFilter: HTML {
    let currentType: Newsletter.NewsletterName?

    var content: some HTML {
        div(.class("tabs is-centered mb-6")) {
            ul {
                li(.class(currentType == nil ? "is-active" : "")) {
                    a(.href("/newsletters")) { "All Newsletters" }
                }
                li(.class(currentType == .nvSciTech ? "is-active" : "")) {
                    a(.href("/newsletters?type=nv-sci-tech")) { "NV Sci Tech" }
                }
                li(.class(currentType == .sagebrush ? "is-active" : "")) {
                    a(.href("/newsletters?type=sagebrush")) { "Sagebrush" }
                }
                li(.class(currentType == .neonLaw ? "is-active" : "")) {
                    a(.href("/newsletters?type=neon-law")) { "Neon Law" }
                }
            }
        }
    }
}

struct NewsletterList: HTML {
    let newsletters: [Newsletter]

    var content: some HTML {
        if newsletters.isEmpty {
            div(.class("has-text-centered py-6")) {
                p(.class("title is-4 has-text-grey-light")) {
                    "No newsletters found"
                }
                p(.class("subtitle is-6 has-text-grey")) {
                    "Check back soon for new content!"
                }
            }
        } else {
            div(.class("columns is-multiline")) {
                for newsletter in newsletters {
                    NewsletterCard(newsletter: newsletter)
                }
            }
        }
    }
}

struct NewsletterCard: HTML {
    let newsletter: Newsletter

    var content: some HTML {
        div(.class("column is-one-third")) {
            div(.class("card")) {
                div(.class("card-content")) {
                    div(.class("media")) {
                        div(.class("media-content")) {
                            span(.class("tag is-primary mb-2")) {
                                newsletterTypeDisplay(newsletter.name)
                            }
                            p(.class("title is-5")) {
                                newsletter.subjectLine
                            }
                            if let sentAt = newsletter.sentAt {
                                p(.class("subtitle is-6 has-text-grey")) {
                                    formatDisplayDate(sentAt)
                                }
                            }
                        }
                    }

                    div(.class("content")) {
                        // Show a brief excerpt of the markdown content
                        p {
                            String(newsletter.markdownContent.prefix(150))
                                + (newsletter.markdownContent.count > 150 ? "..." : "")
                        }
                    }
                }

                footer(.class("card-footer")) {
                    if let sentAt = newsletter.sentAt {
                        let dateString = formatDateForUrl(sentAt)

                        a(
                            .class("card-footer-item"),
                            .href("/newsletters/\(newsletter.name.rawValue)/\(dateString)")
                        ) {
                            "Read Newsletter"
                        }
                    } else {
                        span(.class("card-footer-item")) {
                            "Draft"
                        }
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

    private func formatDateForUrl(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMM"
        return formatter.string(from: date)
    }
}

struct NewsletterPagination: HTML {
    let pagination: PaginationInfo
    let currentType: Newsletter.NewsletterName?

    var content: some HTML {
        if pagination.totalPages > 1 {
            nav(.class("pagination is-centered"), .role("navigation")) {
                // Previous page link
                if pagination.page > 1 {
                    a(.class("pagination-previous"), .href(buildPageUrl(pagination.page - 1))) {
                        "Previous"
                    }
                } else {
                    span(.class("pagination-previous"), .title("This is the first page")) {
                        "Previous"
                    }
                }

                // Next page link
                if pagination.page < pagination.totalPages {
                    a(.class("pagination-next"), .href(buildPageUrl(pagination.page + 1))) {
                        "Next"
                    }
                } else {
                    span(.class("pagination-next"), .title("This is the last page")) {
                        "Next"
                    }
                }

                // Page numbers
                ul(.class("pagination-list")) {
                    PaginationNumbers(pagination: pagination, currentType: currentType)
                }
            }
        }
    }

    private func buildPageUrl(_ page: Int) -> String {
        var url = "/newsletters?page=\(page)"
        if let type = currentType {
            url += "&type=\(type.rawValue)"
        }
        return url
    }
}

struct PaginationNumbers: HTML {
    let pagination: PaginationInfo
    let currentType: Newsletter.NewsletterName?

    var content: some HTML {
        let startPage = max(1, pagination.page - 2)
        let endPage = min(pagination.totalPages, pagination.page + 2)

        // First page
        if startPage > 1 {
            li {
                a(.class("pagination-link"), .href(buildPageUrl(1))) { "1" }
            }
            if startPage > 2 {
                li {
                    span(.class("pagination-ellipsis")) { "…" }
                }
            }
        }

        // Page range
        for page in startPage...endPage {
            li {
                if page == pagination.page {
                    a(.class("pagination-link is-current")) {
                        "\(page)"
                    }
                } else {
                    a(.class("pagination-link"), .href(buildPageUrl(page))) { "\(page)" }
                }
            }
        }

        // Last page
        if endPage < pagination.totalPages {
            if endPage < pagination.totalPages - 1 {
                li {
                    span(.class("pagination-ellipsis")) { "…" }
                }
            }
            li {
                a(.class("pagination-link"), .href(buildPageUrl(pagination.totalPages))) { "\(pagination.totalPages)" }
            }
        }
    }

    private func buildPageUrl(_ page: Int) -> String {
        var url = "/newsletters?page=\(page)"
        if let type = currentType {
            url += "&type=\(type.rawValue)"
        }
        return url
    }
}
