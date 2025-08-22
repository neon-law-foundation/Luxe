import Elementary
import TouchMenu
import VaporElementary

struct PrivacyPolicyPage: HTMLDocument {
    var title: String { "Privacy Policy - Destined" }

    var head: some HTML {
        HeaderComponent(primaryColor: "#1e3a8a", secondaryColor: "#10b981").content
        Elementary.title { title }
        style {
            """
            .hero.is-mystical {
                background: linear-gradient(135deg, #1e3a8a 0%, #16213e 50%, #0f3460 100%);
            }
            .has-text-mystical {
                color: #10b981;
            }
            """
        }
    }

    var body: some HTML {
        DestinedNavigation().body
        PrivacyPolicyComponent(companyName: "Destined", supportEmail: "team@destined.travel")
        customFooter
    }

    private var customFooter: some HTML {
        footer(.class("footer has-background-dark")) {
            div(.class("container has-text-centered")) {
                p(.class("has-text-grey-light")) {
                    "Destined is a Sagebrush Services powered company"
                }
            }
        }
    }
}
