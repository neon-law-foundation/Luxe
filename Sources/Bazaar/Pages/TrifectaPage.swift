import Dali
import Elementary
import TouchMenu
import VaporElementary

struct TrifectaPage: HTMLDocument {
    let currentUser: User?

    init(currentUser: User? = nil) {
        self.currentUser = currentUser
    }

    var title: String { "How the trifecta works - Neon Law, Neon Law Foundation, and Sagebrush Services™" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)

        section(.class("hero is-primary is-medium")) {
            div(.class("hero-body")) {
                div(.class("container has-text-centered")) {
                    h1(.class("title is-1")) { "How the trifecta works" }
                    h2(.class("subtitle is-3")) {
                        "Understanding the relationship between Neon Law, Neon Law Foundation, and Sagebrush Services™"
                    }
                }
            }
        }

        section(.class("section")) {
            div(.class("container")) {
                div(.class("content")) {
                    h2(.class("title is-2")) { "About Our Organizations" }

                    div(.class("columns is-multiline")) {
                        div(.class("column is-12")) {
                            div(.class("box")) {
                                h3(.class("title is-3")) { "Neon Law" }
                                p {
                                    "Neon Law is a law firm PLLC in Nevada. Neon Law only sells bespoke legal services tailored to the needs of our clients. We choose matters that align with our mission to increase love and respect. Because Neon Law is a law firm only lawyers can participate in profit sharing."
                                }
                            }
                        }

                        div(.class("column is-12")) {
                            div(.class("box")) {
                                h3(.class("title is-3")) { "Neon Law Foundation" }
                                p {
                                    "Neon Law Foundation is a 501(c)(3) non-profit. Our main deliverables are the OSS repository, Luxe, other open-source software development work to maintain our systems in perpetuity, and most importantly, building a community of people who believe in creating Sagebrush Standards to advance access to justice through open source software primarily written in Swift."
                                }
                            }
                        }

                        div(.class("column is-12")) {
                            div(.class("box")) {
                                h3(.class("title is-3")) { "Sagebrush Services™" }
                                p {
                                    "Sagebrush Services™ is a Nevada corporation. Our goal is to be a trusted partner for all the boring but necessary tasks including:"
                                }
                                ul {
                                    li {
                                        "Mailroom: Send your mail here and we will scan it and upload it to our portal."
                                    }
                                    li { "Entity Management: File and renew your Nevada and federal forms on time." }
                                    li {
                                        "Cap Tables: Manage how to share the pie with teammates, advisors, and investors."
                                    }
                                    li {
                                        "Personal Data: Protect your privacy by tracking who requests and retains your information."
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        section(.class("section")) {
            div(.class("container")) {
                div(.class("content")) {
                    h2(.class("title is-2")) { "How the trifecta works" }

                    div(.class("box")) {
                        p {
                            "This repository is licensed from Neon Law Foundation, the act of writing software is also governed by the Foundation."
                        }
                        p {
                            "The operations of running the software are managed by Sagebrush Services™. Continuous integration is NLF and continuous deployment is Sagebrush Services™."
                        }
                        p {
                            "Sagebrush Services™ is where all non-legal-service work is billed from. Neon Law is where legal advice is billed from, such as contract review, estate plan creation, and bespoke litigation."
                        }
                        p {
                            "Sagebrush Services™ and Neon Law pledge 10% of gross revenue to the Neon Law Foundation."
                        }
                        p {
                            "Each entity has its own accounting ledger and bank accounts."
                        }
                    }
                }
            }
        }

        section(.class("section")) {
            div(.class("container")) {
                div(.class("content has-text-centered")) {
                    div(.class("box")) {
                        h3(.class("title is-3")) { "Need assistance?" }
                        p {
                            "Please contact us at "
                            a(.href("mailto:support@sagebrush.services")) { "support@sagebrush.services" }
                        }
                    }
                }
            }
        }

        FooterComponent.sagebrushFooter()
    }
}
