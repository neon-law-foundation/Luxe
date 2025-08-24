import Elementary
import VaporElementary

public struct FooterComponent: HTML {
    public let company: String
    public let supportEmail: String

    public init(company: String, supportEmail: String) {
        self.company = company
        self.supportEmail = supportEmail
    }

    public var content: some HTML {
        footer(
            .class("footer has-background-dark has-text-light"),
            .style("background: linear-gradient(135deg, #2C3E50 0%, #34495E 100%) !important;")
        ) {
            div(.class("container")) {
                div(.class("columns")) {
                    div(.class("column is-one-third")) {
                        h4(.class("title is-5 has-text-light")) { "Our Network" }
                        div(.class("content")) {
                            ul {
                                li {
                                    a(.class("has-text-light"), .href("https://www.neonlaw.com"), .target(.blank)) {
                                        "Neon Law®"
                                    }
                                }
                                li {
                                    a(.class("has-text-light"), .href("https://www.neonlaw.org"), .target(.blank)) {
                                        "Neon Law Foundation"
                                    }
                                }
                                li {
                                    a(
                                        .class("has-text-light"),
                                        .href("https://www.sagebrush.services"),
                                        .target(.blank)
                                    ) {
                                        "Sagebrush Services™"
                                    }
                                }
                                li {
                                    a(
                                        .class("has-text-light"),
                                        .href("https://www.sagebrush.services/standards"),
                                        .target(.blank)
                                    ) {
                                        "Sagebrush Standards"
                                    }
                                }
                            }
                        }
                    }
                    div(.class("column is-one-third")) {
                        h4(.class("title is-5 has-text-light")) { "Contact" }
                        div(.class("content")) {
                            p {
                                "Support: "
                                a(.class("has-text-light"), .href("mailto:\(supportEmail)")) {
                                    supportEmail
                                }
                            }
                            p {
                                a(.class("has-text-light"), .href("/privacy")) {
                                    "Privacy Policy"
                                }
                            }
                            p {
                                a(.class("has-text-light"), .href("/mailroom-terms")) {
                                    "Mailroom Terms"
                                }
                            }
                        }
                    }
                    div(.class("column is-one-third")) {
                        h4(.class("title is-5 has-text-light")) { "Follow Us" }
                        div(.class("content")) {
                            p {
                                a(
                                    .class("has-text-light"),
                                    .href("https://linkedin.com/company/sagebrush-services-nv"),
                                    .target(.blank)
                                ) {
                                    "LinkedIn"
                                }
                            }
                        }
                    }
                }
                hr(.class("has-background-grey"))
                div(.class("has-text-centered")) {
                    p(.class("has-text-grey-light")) {
                        "Nothing here is legal advice."
                    }
                    p(.class("has-text-grey-light")) {
                        "© 2025 \(company). All rights reserved."
                    }
                }
            }
        }
    }
}

// Convenience initializers for different companies
extension FooterComponent {
    public static func sagebrushFooter() -> FooterComponent {
        FooterComponent(company: "Sagebrush", supportEmail: "support@sagebrush.services")
    }

    public static func neonLawFooter() -> FooterComponent {
        FooterComponent(company: "Neon Law", supportEmail: "support@neonlaw.com")
    }
}
