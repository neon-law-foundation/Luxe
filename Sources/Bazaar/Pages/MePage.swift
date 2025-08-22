import Bouncer
import Dali
import Elementary
import TouchMenu
import VaporElementary

struct MePage: HTMLDocument {
    let user: UserInfo
    let person: PersonInfo
    let currentUser: User?

    var title: String { "My Account - Sagebrush" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        heroSection
        accountSection
        FooterComponent.sagebrushFooter()
    }

    private var heroSection: some HTML {
        section(.class("hero is-primary")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { "My Account" }
                    h2(.class("subtitle is-3 has-text-white")) { "Welcome back, \(person.name)!" }
                }
            }
        }
    }

    private var accountSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                div(.class("columns")) {
                    accountInfoCard
                    quickActionsCard
                }
            }
        }
    }

    private var accountInfoCard: some HTML {
        div(.class("column is-8")) {
            div(.class("card")) {
                div(.class("card-header")) {
                    p(.class("card-header-title")) { "Account Information" }
                }
                div(.class("card-content")) {
                    accountFields
                }
            }
        }
    }

    private var accountFields: some HTML {
        div(.class("content")) {
            div(.class("field")) {
                label(.class("label")) { "Name" }
                div(.class("control")) {
                    input(.class("input"), .type(.text), .value(person.name), .disabled)
                }
            }

            div(.class("field")) {
                label(.class("label")) { "Email" }
                div(.class("control")) {
                    input(.class("input"), .type(.email), .value(person.email), .disabled)
                }
            }

            div(.class("field")) {
                label(.class("label")) { "Username" }
                div(.class("control")) {
                    input(.class("input"), .type(.text), .value(user.username), .disabled)
                }
            }

            div(.class("field")) {
                label(.class("label")) { "User ID" }
                div(.class("control")) {
                    input(.class("input"), .type(.text), .value(user.id), .disabled)
                }
            }
        }
    }

    private var quickActionsCard: some HTML {
        div(.class("column is-4")) {
            div(.class("card")) {
                div(.class("card-header")) {
                    p(.class("card-header-title")) { "Quick Actions" }
                }
                div(.class("card-content")) {
                    div(.class("content")) {
                        a(.class("button is-primary is-fullwidth is-rounded"), .href("/app/mailbox")) {
                            "📬 View Mailbox"
                        }
                        br()
                        a(.class("button is-info is-fullwidth is-rounded"), .href("/app/settings")) {
                            "⚙️ Account Settings"
                        }
                        br()
                        if currentUser?.isAdmin() == true {
                            a(.class("button is-danger is-fullwidth is-rounded"), .href("/admin")) {
                                "🔧 Admin Panel"
                            }
                            br()
                        }
                        a(.class("button is-light is-fullwidth is-rounded"), .href("/auth/logout")) {
                            "🚪 Log Out"
                        }
                    }
                }
            }
        }
    }
}
