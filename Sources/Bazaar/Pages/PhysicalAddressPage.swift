import Elementary
import TouchMenu
import VaporElementary

struct PhysicalAddressPage: HTMLDocument {
    var title: String { "Nevada Physical Address Service - Sagebrush" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation()

        section(.class("hero is-primary")) {
            div(.class("hero-body")) {
                div(.class("container has-text-centered")) {
                    h1(.class("title is-1")) { "Nevada Physical Address Service" }
                    h2(.class("subtitle is-3")) {
                        "Professional physical location with mail handling and coworking space"
                    }
                }
            }
        }

        section(.class("section")) {
            div(.class("container")) {
                div(.class("columns is-vcentered")) {
                    div(.class("column is-two-thirds")) {
                        div(.class("content is-large")) {
                            h2(.class("title is-2 has-text-primary")) { "How to Sign Up" }

                            div(.class("box")) {
                                h3(.class("title is-4")) { "📞 Step 1: Contact Us" }
                                p { "Contact us at " }
                                a(.href("mailto:support@sagebrush.services")) { "support@sagebrush.services" }
                                p { " and we will send you an application form." }
                            }

                            div(.class("box")) {
                                h3(.class("title is-4")) { "📋 Step 2: Complete Application" }
                                p {
                                    "Fill out the application form we send you with your business and personal details."
                                }
                            }

                            div(.class("box")) {
                                h3(.class("title is-4")) { "💳 Step 3: Payment" }
                                p {
                                    "After submitting your application, we'll send you the setup fee and first month's bill via Xero."
                                }
                            }

                            div(.class("box")) {
                                h3(.class("title is-4")) { "📝 Step 4: Notarization" }
                                p {
                                    "Once payment is complete, we'll send you information on getting your USPS Form 1583 notarized."
                                }
                            }
                        }
                    }

                    div(.class("column is-one-third")) {
                        div(.class("card")) {
                            div(.class("card-content has-text-centered")) {
                                h3(.class("title is-3 has-text-primary")) { "Service Guarantee" }
                                div(.class("content")) {
                                    p(.class("has-text-weight-bold")) { "✅ One business day mail delivery via email" }
                                    p(.class("has-text-weight-bold")) { "✅ Response within one business day" }
                                    p(.class("has-text-weight-bold")) { "✅ Professional customer support" }
                                    p(.class("has-text-weight-bold")) { "✅ Secure mail handling" }
                                }
                                a(
                                    .class("button is-primary is-large is-fullwidth is-rounded"),
                                    .href("mailto:support@sagebrush.services")
                                ) { "Get Started" }
                            }
                        }
                    }
                }
            }
        }

        section(.class("section has-background-light")) {
            div(.class("container has-text-centered")) {
                h2(.class("title is-2 has-text-primary")) { "What Happens Next?" }
                div(.class("columns")) {
                    div(.class("column")) {
                        div(.class("notification is-light")) {
                            h4(.class("title is-4")) { "📬 Mail Delivery" }
                            p {
                                "We'll email you scanned copies of all mail received to your name and box number within one business day."
                            }
                        }
                    }
                    div(.class("column")) {
                        div(.class("notification is-light")) {
                            h4(.class("title is-4")) { "📞 Ongoing Support" }
                            p {
                                "Contact us anytime at support@sagebrush.services for mail forwarding, special requests, or questions."
                            }
                        }
                    }
                    div(.class("column")) {
                        div(.class("notification is-light")) {
                            h4(.class("title is-4")) { "🔒 Privacy Protection" }
                            p {
                                "Your mail is handled securely and confidentially."
                            }
                        }
                    }
                }
            }
        }

        section(.class("section")) {
            div(.class("container has-text-centered")) {
                h2(.class("title is-2 has-text-primary")) { "Ready to Get Your Nevada Address?" }
                p(.class("subtitle")) { "Join our satisfied customers and get professional mail service today" }
                div(.class("buttons is-centered")) {
                    a(.class("button is-primary is-large is-rounded"), .href("mailto:support@sagebrush.services")) {
                        "Contact Support"
                    }
                    a(.class("button is-light is-large is-rounded"), .href("/pricing")) { "View Pricing" }
                }
            }
        }

        FooterComponent.sagebrushFooter()
    }
}
