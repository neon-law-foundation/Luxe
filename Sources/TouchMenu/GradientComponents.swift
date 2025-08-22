import Elementary
import VaporElementary

// MARK: - Gradient Hero Component
public struct GradientHeroComponent: HTML {
    public let title: String
    public let subtitle: String?
    public let ctaText: String?
    public let ctaLink: String?
    public let logoSrc: String?

    public init(
        title: String,
        subtitle: String? = nil,
        ctaText: String? = nil,
        ctaLink: String? = nil,
        logoSrc: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.ctaText = ctaText
        self.ctaLink = ctaLink
        self.logoSrc = logoSrc
    }

    public var content: some HTML {
        section(.class("hero is-primary is-medium")) {
            div(.class("hero-body")) {
                div(.class("container has-text-centered")) {
                    if let logoSrc = logoSrc {
                        figure(.class("image"), .style("max-width: 200px; margin: 0 auto 2rem auto;")) {
                            img(.src(logoSrc), .alt("Logo"), .style("width: 100%; height: auto;"))
                        }
                    }

                    h1(.class("title is-1 has-text-white mb-4")) {
                        title
                    }

                    if let subtitle = subtitle {
                        h2(.class("subtitle is-3 has-text-white-ter mb-6")) {
                            subtitle
                        }
                    }

                    if let ctaText = ctaText, let ctaLink = ctaLink {
                        div(.class("buttons is-centered")) {
                            a(
                                .href(ctaLink),
                                .class("button is-info is-large is-rounded smooth-hover")
                            ) {
                                ctaText
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Gradient Card Component
public struct GradientCardComponent: HTML {
    public let title: String
    public let cardContent: String
    public let cardType: CardType
    public let buttonText: String?
    public let buttonLink: String?

    public enum CardType {
        case feature
        case pricing
        case service
        case contact
        case step
        case standards
    }

    public init(
        title: String,
        content: String,
        cardType: CardType = .feature,
        buttonText: String? = nil,
        buttonLink: String? = nil
    ) {
        self.title = title
        self.cardContent = content
        self.cardType = cardType
        self.buttonText = buttonText
        self.buttonLink = buttonLink
    }

    public var content: some HTML {
        div(.class("card \(cardType.cssClass)")) {
            div(.class("card-content")) {
                h3(.class("title is-4")) {
                    if title.contains("🏢") || title.contains("🔔") || title.contains("📋") || title.contains("💼")
                        || title.contains("🏛️") || title.contains("📈") || title.contains("⚖️") || title.contains("📄")
                        || title.contains("🔄") || title.contains("🔧")
                    {
                        span(.style("font-size: 1.5em; margin-right: 0.5em;")) { String(title.prefix(2)) }
                        span(.class("has-text-primary")) {
                            String(title.dropFirst(2).trimmingCharacters(in: .whitespaces))
                        }
                    } else {
                        span(.class("has-text-primary")) { title }
                    }
                }
                div(.class("content")) {
                    p { cardContent }
                }

                if let buttonText = buttonText, let buttonLink = buttonLink {
                    div(.class("has-text-centered mt-4")) {
                        a(.class("button is-primary is-rounded smooth-hover"), .href(buttonLink)) {
                            buttonText
                        }
                    }
                }
            }
        }
    }
}

extension GradientCardComponent.CardType {
    var cssClass: String {
        switch self {
        case .feature: return "feature-card"
        case .pricing: return "pricing-card"
        case .service: return "service-card"
        case .contact: return "contact-card"
        case .step: return "step-card"
        case .standards: return "standards-card"
        }
    }
}

// MARK: - Gradient Section Component
public struct GradientSectionComponent<Content: HTML>: HTML {
    public let backgroundType: BackgroundType
    public let sectionContent: Content

    public enum BackgroundType {
        case light
        case primaryLight
        case transparent
    }

    public init(backgroundType: BackgroundType = .transparent, @HTMLBuilder content: () -> Content) {
        self.backgroundType = backgroundType
        self.sectionContent = content()
    }

    public var content: some HTML {
        section(.class("section \(backgroundType.cssClass)")) {
            div(.class("container")) {
                sectionContent
            }
        }
    }
}

extension GradientSectionComponent.BackgroundType {
    var cssClass: String {
        switch self {
        case .light: return "has-background-light"
        case .primaryLight: return "has-background-primary-light"
        case .transparent: return ""
        }
    }
}

// MARK: - Gradient Button Component
public struct GradientButtonComponent: HTML {
    public let text: String
    public let link: String
    public let buttonType: ButtonType
    public let size: Size

    public enum ButtonType {
        case primary
        case secondary
        case info
    }

    public enum Size {
        case normal
        case large
        case small
    }

    public init(text: String, link: String, buttonType: ButtonType = .primary, size: Size = .normal) {
        self.text = text
        self.link = link
        self.buttonType = buttonType
        self.size = size
    }

    public var content: some HTML {
        a(.class("button \(buttonType.cssClass) \(size.cssClass) is-rounded smooth-hover"), .href(link)) {
            text
        }
    }
}

extension GradientButtonComponent.ButtonType {
    var cssClass: String {
        switch self {
        case .primary: return "is-primary"
        case .secondary: return "is-light"
        case .info: return "is-info"
        }
    }
}

extension GradientButtonComponent.Size {
    var cssClass: String {
        switch self {
        case .normal: return ""
        case .large: return "is-large"
        case .small: return "is-small"
        }
    }
}

// MARK: - Gradient Feature Grid Component
public struct GradientFeatureGridComponent: HTML {
    public let features: [Feature]

    public struct Feature {
        public let icon: String
        public let title: String
        public let description: String

        public init(icon: String, title: String, description: String) {
            self.icon = icon
            self.title = title
            self.description = description
        }
    }

    public init(features: [Feature]) {
        self.features = features
    }

    public var content: some HTML {
        div(.class("columns is-multiline")) {
            for feature in features {
                div(.class("column is-full-mobile is-full-tablet is-half-desktop")) {
                    GradientCardComponent(
                        title: "\(feature.icon) \(feature.title)",
                        content: feature.description,
                        cardType: .feature
                    )
                }
            }
        }
    }
}
