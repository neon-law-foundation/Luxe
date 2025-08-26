import Dali
import Elementary
import TouchMenu
import VaporElementary

struct HomePage: HTMLDocument {
    let currentUser: User?

    init(currentUser: User? = nil) {
        self.currentUser = currentUser
    }

    var title: String { "Sagebrush Physical Address - Nevada's Premier Mail Service" }

    var head: some HTML {
        let ogMetadata = TouchMenu.OpenGraphMetadata(
            title: "Sagebrush Physical Address - Nevada's Premier Mail Service",
            description:
                "Complete mail management, compliance, and equity services for Nevada businesses and individuals. Physical address + license compliance + cap table guidance.",
            image: "https://www.sagebrush.services/sagebrush.svg",
            url: "https://www.sagebrush.services"
        )

        HeaderComponent.sagebrushTheme(openGraphMetadata: ogMetadata)
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)

        GradientHeroComponent(
            title: "Your all-in-one Nevada entities platform",
            subtitle: "Physical address, license compliance, and cap table management services in Nevada",
            ctaText: "Get Started - $49/month",
            ctaLink: "mailto:support@sagebrush.services",
            logoSrc: "/sagebrush.svg"
        )

        GradientSectionComponent(backgroundType: .transparent) {
            div(.class("columns is-vcentered")) {
                div(.class("column is-half")) {
                    h2(.class("title is-2 has-text-primary")) { "Why Choose Sagebrush?" }
                    div(.class("content is-large")) {
                        p {
                            "Complete mail management, compliance, and equity services for Nevada businesses and individuals."
                        }

                        GradientFeatureGridComponent(features: [
                            GradientFeatureGridComponent.Feature(
                                icon: "🏢",
                                title: "NV Address",
                                description: "Incorporate in Nevada with an an address"
                            ),
                            GradientFeatureGridComponent.Feature(
                                icon: "🔔",
                                title: "Digital Notifications",
                                description: "Instant notifications when mail arrives"
                            ),
                            GradientFeatureGridComponent.Feature(
                                icon: "📋",
                                title: "State Filings",
                                description: "Nevada Secretary of State filing assistance"
                            ),
                            GradientFeatureGridComponent.Feature(
                                icon: "💼",
                                title: "Cap Table",
                                description: "Stock issuance and equity tracking"
                            ),
                        ])
                    }
                }
                div(.class("column is-half has-text-centered")) {
                    figure(.class("image"), .style("max-width: 400px; margin: 0 auto;")) {
                        img(
                            .src("/sagebrush.svg"),
                            .alt("Sagebrush Physical Address Services"),
                            .style("width: 100%; height: auto; max-height: 300px;")
                        )
                    }
                }
            }
        }

        GradientSectionComponent(backgroundType: .light) {
            div(.class("has-text-centered")) {
                h2(.class("title is-2 has-text-primary")) { "Simple Pricing" }
                div(.class("columns is-centered")) {
                    div(.class("column is-one-third")) {
                        GradientCardComponent(
                            title: "$49/month",
                            content:
                                "Physical address + license compliance + cap table guidance. Filing fees and legal services billed separately.",
                            cardType: .pricing,
                            buttonText: "Get Started Today",
                            buttonLink: "mailto:support@sagebrush.services"
                        )
                    }
                }
            }
        }

        GradientSectionComponent(backgroundType: .primaryLight) {
            div(.class("columns is-vcentered")) {
                div(.class("column is-two-thirds")) {
                    h2(.class("title is-2 has-text-primary")) { "Cap Table & Stock Issuance Management" }
                    div(.class("content is-large")) {
                        p {
                            "Managing equity for your Nevada LLC or C-Corp? We help you maintain accurate cap tables and handle stock issuances with proper legal guidance."
                        }

                        GradientFeatureGridComponent(features: [
                            GradientFeatureGridComponent.Feature(
                                icon: "🏛️",
                                title: "Nevada Compliance",
                                description: "Nevada-specific compliance expertise"
                            ),
                            GradientFeatureGridComponent.Feature(
                                icon: "📋",
                                title: "Cap Table Maintenance",
                                description: "Professional cap table updates and tracking"
                            ),
                            GradientFeatureGridComponent.Feature(
                                icon: "📈",
                                title: "Stock Administration",
                                description: "Stock option and RSU administration"
                            ),
                            GradientFeatureGridComponent.Feature(
                                icon: "⚖️",
                                title: "Legal Coordination",
                                description: "Coordinated with qualified attorneys"
                            ),
                        ])

                        div(.class("buttons mt-5")) {
                            GradientButtonComponent(
                                text: "Learn About Cap Tables",
                                link: "/blog/cap-table-equity",
                                buttonType: .primary
                            )
                            GradientButtonComponent(
                                text: "Get Cap Table Help",
                                link: "mailto:support@sagebrush.services?subject=Cap Table Services",
                                buttonType: .info
                            )
                        }
                    }
                }
                div(.class("column is-one-third")) {
                    div(.class("notification is-info is-light")) {
                        h4(.class("title is-4")) { "Why Cap Tables Matter" }
                        p(.class("content")) {
                            "Accurate cap tables are essential for fundraising, employee compensation, and eventual exits. Let us help you maintain transparency and compliance from day one."
                        }
                    }
                }
            }
        }

        GradientSectionComponent(backgroundType: .light) {
            div(.class("columns is-vcentered")) {
                div(.class("column is-half")) {
                    h2(.class("title is-2 has-text-primary")) { "Sagebrush Standards" }
                    div(.class("content is-large")) {
                        p {
                            "Computable document workflows that combine documents, questionnaires, and automated workflows to create a seamless experience for organizations."
                        }
                        p {
                            "Our standards provide a framework for building efficient document generation and management systems with:"
                        }

                        GradientFeatureGridComponent(features: [
                            GradientFeatureGridComponent.Feature(
                                icon: "📄",
                                title: "PDF Overlays",
                                description: "Precise document mapping and overlay systems"
                            ),
                            GradientFeatureGridComponent.Feature(
                                icon: "🔄",
                                title: "Client Flows",
                                description: "Interactive questionnaires for clients"
                            ),
                            GradientFeatureGridComponent.Feature(
                                icon: "📋",
                                title: "Staff Alignments",
                                description: "Review processes for staff workflows"
                            ),
                            GradientFeatureGridComponent.Feature(
                                icon: "🔧",
                                title: "Reusable Notations",
                                description: "Document patterns for efficiency"
                            ),
                        ])
                    }
                }
                div(.class("column is-half has-text-centered")) {
                    h3(.class("title is-3 has-text-primary")) { "Explore Standards" }
                    div(.class("buttons is-centered")) {
                        GradientButtonComponent(
                            text: "View Standards Home",
                            link: "/standards",
                            buttonType: .primary,
                            size: .large
                        )
                        GradientButtonComponent(
                            text: "Read Specification",
                            link: "/standards/spec",
                            buttonType: .info,
                            size: .large
                        )
                    }
                    p(.class("mt-4")) {
                        "Build efficient document workflows with our open standards framework"
                    }
                }
            }
        }

        GradientSectionComponent(backgroundType: .transparent) {
            div(.class("has-text-centered")) {
                h2(.class("title is-2 has-text-primary")) { "Ready to Get Started?" }
                p(.class("subtitle")) {
                    "Join hundreds of satisfied customers who trust Sagebrush with their business needs"
                }
                GradientButtonComponent(
                    text: "Start Onboarding",
                    link: "mailto:support@sagebrush.services",
                    buttonType: .primary,
                    size: .large
                )
            }
        }

        FooterComponent.sagebrushFooter()
    }
}
