import Dali
import Elementary
import TouchMenu
import VaporElementary

struct PricingPage: HTMLDocument {
    let currentUser: User?

    init(currentUser: User? = nil) {
        self.currentUser = currentUser
    }

    var title: String { "Pricing - Sagebrush Physical Address" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)

        GradientHeroComponent(
            title: "Simple, Transparent Pricing",
            subtitle: "Physical address and license compliance services"
        )

        GradientSectionComponent(backgroundType: .transparent) {
            div(.class("columns is-centered")) {
                div(.class("column is-6")) {
                    GradientCardComponent(
                        title: "Physical Address & License Compliance - $49/month",
                        content:
                            "Complete physical address and Nevada license compliance services. Billed monthly • Cancel anytime",
                        cardType: .pricing,
                        buttonText: "Get Started Today",
                        buttonLink: "mailto:support@sagebrush.services"
                    )
                }
            }

            div(.class("notification is-info")) {
                p(.class("has-text-weight-bold")) { "Important Note About Filing Fees" }
                p {
                    "Your $49/month subscription includes all compliance management services. Actual government filing fees (such as the $425 LLC registration fee) are billed separately. We'll invoice you 30 days before fees are due and require payment at least 1 business day in advance to guarantee filing. If payment is missed, we'll make best efforts to file within 3 days."
                }
            }

            GradientFeatureGridComponent(features: [
                GradientFeatureGridComponent.Feature(
                    icon: "✉️",
                    title: "Mail Services",
                    description:
                        "Real Nevada street address • Digital mail scanning • Secure storage • Worldwide forwarding • Package receiving • Check deposit services"
                ),
                GradientFeatureGridComponent.Feature(
                    icon: "📋",
                    title: "License Compliance",
                    description:
                        "Nevada Secretary of State filings • Tax form handling • City of Reno forms • Annual report reminders • Compliance tracking • Document assistance"
                ),
                GradientFeatureGridComponent.Feature(
                    icon: "🔒",
                    title: "Security & Privacy",
                    description:
                        "USPS Form 1583 compliance • Secure document shredding • Privacy protection • Professional handling • Secure portal • Two-factor authentication"
                ),
                GradientFeatureGridComponent.Feature(
                    icon: "📱",
                    title: "Digital Features",
                    description:
                        "Mobile app access • Email notifications • SMS alerts • Cloud storage • Advanced search • Export options"
                ),
                GradientFeatureGridComponent.Feature(
                    icon: "🎯",
                    title: "Business Benefits",
                    description:
                        "Professional business address • Enhanced credibility • Global accessibility • Cost-effective • No contracts • Dedicated support"
                ),
            ])
        }

        GradientSectionComponent(backgroundType: .light) {
            div(.class("has-text-centered")) {
                div(.class("box has-background-light")) {
                    div(.class("has-text-centered")) {
                        h3(.class("title is-3 has-text-primary")) { "Additional Services" }
                        p(.class("subtitle")) { "Optional add-ons available" }

                        div(.class("columns")) {
                            div(.class("column")) {
                                h4(.class("title is-5")) { "Express Forwarding" }
                                p { "Next-day delivery: $15 per package" }
                            }
                            div(.class("column")) {
                                h4(.class("title is-5")) { "Document Scanning" }
                                p { "Premium scanning: $5 per document" }
                            }
                            div(.class("column")) {
                                h4(.class("title is-5")) { "Phone Services" }
                                p { "Virtual phone number: $20/month" }
                            }
                        }
                    }
                }

                div(.class("has-text-centered")) {
                    h2(.class("title is-2 has-text-primary")) { "Frequently Asked Questions" }

                    div(.class("columns")) {
                        div(.class("column")) {
                            div(.class("box")) {
                                h4(.class("title is-5")) { "Can I use this address for business registration?" }
                                p {
                                    "Yes! Our Nevada addresses are perfect for business registration, banking, and all official correspondence."
                                }
                            }
                        }
                        div(.class("column")) {
                            div(.class("box")) {
                                h4(.class("title is-5")) { "How quickly will I receive mail notifications?" }
                                p {
                                    "Mail is scanned and notifications sent within 24 hours of receipt, often much sooner during business hours."
                                }
                            }
                        }
                    }

                    div(.class("columns")) {
                        div(.class("column")) {
                            div(.class("box")) {
                                h4(.class("title is-5")) { "What happens if I cancel?" }
                                p {
                                    "You can cancel anytime. We'll forward any remaining mail to your preferred address at no additional cost."
                                }
                            }
                        }
                        div(.class("column")) {
                            div(.class("box")) {
                                h4(.class("title is-5")) { "Is there a setup fee?" }
                                p {
                                    "No setup fees! Just $49/month for complete physical address service. Start immediately after verification."
                                }
                            }
                        }
                    }
                }

                div(.class("has-text-centered")) {
                    GradientButtonComponent(
                        text: "Start Your Nevada Entity Today",
                        link: "mailto:support@sagebrush.services",
                        buttonType: .primary,
                        size: .large
                    )
                }
            }
        }

        FooterComponent.sagebrushFooter()
    }
}
