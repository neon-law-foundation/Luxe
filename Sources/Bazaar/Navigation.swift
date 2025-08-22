import Bouncer
import Dali
import Elementary
import TouchMenu

struct Navigation: HTML {
    let explicitCurrentUser: User?

    init(currentUser: User? = nil) {
        self.explicitCurrentUser = currentUser
    }

    private var currentUser: User? {
        explicitCurrentUser ?? CurrentUserContext.user
    }

    var content: some HTML {
        ResponsiveNavigation(
            brandName: "Sagebrush",
            brandLogo: "/sagebrush.svg",
            navigationItems: [
                NavigationItem(title: "Home", href: "/"),
                NavigationItem(title: "Blog", href: "/blog"),
                NavigationItem(title: "Pricing", href: "/pricing"),
                NavigationItem(title: "NV Address", href: "/physical-address"),
            ],
            authenticationContent: div(.class("buttons")) {
                authenticationButtons
            },
            themeClass: "is-primary"
        )
    }

    @HTMLBuilder
    private var authenticationButtons: some HTML {
        if let user = currentUser {
            // User is logged in - show username (which is email for admin@neonlaw.com)
            span(.class("navbar-item has-text-white")) {
                "Welcome, \(user.username)"
            }
            a(.class("button is-light is-rounded"), .href("/auth/logout")) { "Log Out" }
        } else {
            // User is not logged in
            a(.class("button is-white is-rounded"), .href("/login")) { "Log In" }
            a(.class("button is-light is-rounded"), .href("mailto:support@sagebrush.services")) { "Get Started" }
        }
    }
}
