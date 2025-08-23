import Bouncer
import Dali
import Elementary
import TouchMenu
import VaporElementary

struct AdminNewsletterCreatePage: HTMLDocument {
    let currentUser: User?

    var title: String { "Create Newsletter - Admin" }

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
                h1(.class("title")) { "Create Newsletter" }
                p(.class("subtitle")) { "Draft a new newsletter for sending to subscribers" }

                form(.class("card"), .method(.post), .action("/api/admin/newsletters")) {
                    div(.class("card-content")) {
                        div(.class("field")) {
                            label(.class("label")) { "Newsletter Type" }
                            div(.class("control")) {
                                div(.class("select")) {
                                    select(.name("name")) {
                                        option(.value("nv-sci-tech")) { "🔬 NV Sci Tech" }
                                        option(.value("sagebrush")) { "🌾 Sagebrush" }
                                        option(.value("neon-law")) { "⚖️ Neon Law" }
                                    }
                                }
                            }
                        }

                        div(.class("field")) {
                            label(.class("label")) { "Subject Line" }
                            div(.class("control")) {
                                input(
                                    .class("input"),
                                    .type(.text),
                                    .name("subjectLine"),
                                    .placeholder("Enter email subject line...")
                                )
                            }
                        }

                        div(.class("field")) {
                            label(.class("label")) { "Content (Markdown)" }
                            div(.class("control")) {
                                textarea(
                                    .class("textarea"),
                                    .name("markdownContent"),
                                    .placeholder("Write your newsletter content...")
                                ) {
                                    """
                                    # Welcome to Our Newsletter

                                    ## This Week's Highlights

                                    - Feature 1
                                    - Feature 2
                                    - Feature 3

                                    ---

                                    Best regards,
                                    The Team
                                    """
                                }
                            }
                        }
                    }

                    div(.class("card-footer")) {
                        button(.class("button is-primary"), .type(.submit)) {
                            "Save Draft"
                        }
                    }
                }

                div(.class("buttons mt-5")) {
                    a(.class("button"), .href("/admin/newsletters")) {
                        "← Back to Newsletters"
                    }
                }
            }
        }
    }
}
