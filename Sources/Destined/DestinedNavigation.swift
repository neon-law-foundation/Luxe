import Elementary
import TouchMenu
import VaporElementary

struct DestinedNavigation: HTML {
    var body: some HTML {
        ResponsiveNavigation(
            brandName: "Destined Travel™",
            brandHref: "/",
            navigationItems: [
                NavigationItem(title: "Home", href: "/"),
                NavigationItem(title: "About Astrocartography", href: "/about-astrocartography"),
                NavigationItem(title: "Services", href: "/services"),
                NavigationItem(title: "Blog", href: "/blog"),
            ],
            authenticationContent: a(
                .class("button is-primary is-rounded"),
                .href("mailto:team@hoshihoshi.app?subject=Astrocartography%20Consultation")
            ) {
                span { "✉ Get Started" }
            },
            themeClass: "is-dark"
        ).content
    }
}
