import Elementary

public struct ResponsiveNavigation<AuthContent: HTML>: HTML {
    public let brandName: String
    public let brandHref: String
    public let brandEmoji: String?
    public let brandLogo: String?
    public let navigationItems: [NavigationItem]
    public let authenticationContent: AuthContent?
    public let themeClass: String

    public init(
        brandName: String,
        brandHref: String = "/",
        brandEmoji: String? = nil,
        brandLogo: String? = nil,
        navigationItems: [NavigationItem] = [],
        authenticationContent: AuthContent? = nil,
        themeClass: String = "is-primary"
    ) {
        self.brandName = brandName
        self.brandHref = brandHref
        self.brandEmoji = brandEmoji
        self.brandLogo = brandLogo
        self.navigationItems = navigationItems
        self.authenticationContent = authenticationContent
        self.themeClass = themeClass
    }

    public var content: some HTML {
        nav(.class("navbar \(themeClass)"), .role("navigation")) {
            div(.class("navbar-brand")) {
                a(.class("navbar-item has-text-weight-bold"), .href(brandHref)) {
                    if let logo = brandLogo {
                        img(
                            .src(logo),
                            .alt("\(brandName) Logo"),
                            .style("height: 28px; width: auto; margin-right: 8px; vertical-align: middle;")
                        )
                        brandName
                    } else if let emoji = brandEmoji {
                        "\(emoji) \(brandName)"
                    } else {
                        brandName
                    }
                }

                // Mobile burger menu button
                a(.class("navbar-burger"), .role("button"), .data("target", value: "navbarMenu")) {
                    span {}
                    span {}
                    span {}
                    span {}
                }
            }

            div(.id("navbarMenu"), .class("navbar-menu")) {
                div(.class("navbar-start")) {
                    for item in navigationItems {
                        a(.class("navbar-item"), .href(item.href)) {
                            item.title
                        }
                    }
                }

                if let authContent = authenticationContent {
                    div(.class("navbar-end")) {
                        div(.class("navbar-item")) {
                            authContent
                        }
                    }
                }
            }
        }
    }
}

// Convenience extension for no authentication content
extension ResponsiveNavigation where AuthContent == HTMLText {
    public init(
        brandName: String,
        brandHref: String = "/",
        brandEmoji: String? = nil,
        brandLogo: String? = nil,
        navigationItems: [NavigationItem] = [],
        themeClass: String = "is-primary"
    ) {
        self.init(
            brandName: brandName,
            brandHref: brandHref,
            brandEmoji: brandEmoji,
            brandLogo: brandLogo,
            navigationItems: navigationItems,
            authenticationContent: nil,
            themeClass: themeClass
        )
    }
}

public struct NavigationItem: Sendable {
    public let title: String
    public let href: String

    public init(title: String, href: String) {
        self.title = title
        self.href = href
    }
}
