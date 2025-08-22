import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct UserSettingsPage: HTMLDocument {
    let user: UserInfo
    let person: PersonInfo
    let subscriptionPreferences: UserSubscriptionPreferences
    let currentUser: User?

    var title: String { "Account Settings - Sagebrush" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        heroSection
        settingsSection
        FooterComponent.sagebrushFooter()
    }

    private var heroSection: some HTML {
        section(.class("hero is-primary")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { "Account Settings" }
                    h2(.class("subtitle is-3 has-text-white")) { "Manage your preferences" }
                }
            }
        }
    }

    private var settingsSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                div(.class("columns")) {
                    accountInfoCard
                    newsletterPreferencesCard
                }
            }
        }
    }

    private var accountInfoCard: some HTML {
        div(.class("column is-6")) {
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

            p(.class("help is-info")) {
                "To update your personal information, please contact support."
            }
        }
    }

    private var newsletterPreferencesCard: some HTML {
        div(.class("column is-6")) {
            div(.class("card")) {
                div(.class("card-header")) {
                    p(.class("card-header-title")) { "Newsletter Preferences" }
                }
                div(.class("card-content")) {
                    newsletterPreferencesForm
                }
            }
        }
    }

    private var newsletterPreferencesForm: some HTML {
        form(.method(.post), .action("/app/settings/newsletters")) {
            div(.class("field")) {
                label(.class("label")) { "Subscribe to newsletters:" }
                div(.class("control")) {
                    newsletterCheckboxes
                }
                p(.class("help")) {
                    "Choose which newsletters you'd like to receive. You can change these preferences at any time."
                }
            }

            div(.class("field")) {
                div(.class("control")) {
                    button(.class("button is-primary"), .type(.submit)) {
                        "Save Preferences"
                    }
                }
            }
        }
    }

    private var newsletterCheckboxes: some HTML {
        div(.class("content")) {
            div(.class("field")) {
                label(.class("checkbox")) {
                    if subscriptionPreferences.isSubscribedToSciTech {
                        input(.type(.checkbox), .name("sci_tech"), .value("true"), .checked)
                    } else {
                        input(.type(.checkbox), .name("sci_tech"), .value("true"))
                    }
                    " 🔬 NV Sci Tech Newsletter"
                }
                p(.class("help is-info")) {
                    "Stay updated with the latest in science and technology from Nevada."
                }
            }

            div(.class("field")) {
                label(.class("checkbox")) {
                    if subscriptionPreferences.isSubscribedToSagebrush {
                        input(.type(.checkbox), .name("sagebrush"), .value("true"), .checked)
                    } else {
                        input(.type(.checkbox), .name("sagebrush"), .value("true"))
                    }
                    " 🌾 Sagebrush Newsletter"
                }
                p(.class("help is-info")) {
                    "General updates and news from Sagebrush Services."
                }
            }

            div(.class("field")) {
                label(.class("checkbox")) {
                    if subscriptionPreferences.isSubscribedToNeonLaw {
                        input(.type(.checkbox), .name("neon_law"), .value("true"), .checked)
                    } else {
                        input(.type(.checkbox), .name("neon_law"), .value("true"))
                    }
                    " ⚖️ Neon Law Newsletter"
                }
                p(.class("help is-info")) {
                    "Legal insights and updates from Neon Law."
                }
            }
        }
    }
}
