import Elementary
import VaporElementary

public struct BlogCTACard: HTML {
    public init() {}

    public var content: some HTML {
        div(.class("box has-background-light")) {
            h3(.class("title is-4 has-text-primary")) { "Ready to Experience the Benefits?" }
            p {
                "Join thousands of satisfied customers who have made the switch to physical address services. Our Nevada-based service offers all these benefits and more for just $49 per month."
            }
            div(.class("buttons")) {
                a(.class("button is-primary"), .href("/pricing")) { "View Pricing" }
                a(.class("button is-light"), .href("mailto:support@sagebrush.services")) {
                    "Get Started"
                }
            }
        }
    }
}
