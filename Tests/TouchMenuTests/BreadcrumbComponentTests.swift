import Elementary
import Testing

@testable import TouchMenu

@Suite("Breadcrumb Component", .serialized)
struct BreadcrumbComponentTests {

    @Suite("Single Breadcrumb Item", .serialized)
    struct SingleBreadcrumbItemTests {

        @Test("displays single breadcrumb item without link")
        func displaysSingleBreadcrumbItemWithoutLink() {
            let items = [BreadcrumbItem(title: "Admin", url: nil)]
            let component = BreadcrumbComponent(items: items)
            let html = component.render()

            #expect(html.contains("<nav class=\"breadcrumb\">"))
            #expect(html.contains("<span>Admin</span>"))
            #expect(!html.contains("<a"))
        }

        @Test("displays single breadcrumb item with link")
        func displaysSingleBreadcrumbItemWithLink() {
            let items = [BreadcrumbItem(title: "Admin", url: "/admin")]
            let component = BreadcrumbComponent(items: items)
            let html = component.render()

            #expect(html.contains("<a href=\"/admin\">Admin</a>"))
        }
    }

    @Suite("Multiple Breadcrumb Items", .serialized)
    struct MultipleBreadcrumbItemsTests {

        @Test("displays multiple breadcrumb items with proper separators")
        func displaysMultipleBreadcrumbItemsWithProperSeparators() {
            let items = [
                BreadcrumbItem(title: "Admin", url: "/admin"),
                BreadcrumbItem(title: "Users", url: nil),
            ]
            let component = BreadcrumbComponent(items: items)
            let html = component.render()

            #expect(html.contains("<a href=\"/admin\">Admin</a>"))
            #expect(html.contains("<span>Users</span>"))
            #expect(html.contains("<li class=\"is-active\">"))
        }

        @Test("marks last item as active")
        func marksLastItemAsActive() {
            let items = [
                BreadcrumbItem(title: "Admin", url: "/admin"),
                BreadcrumbItem(title: "Users", url: "/admin/users"),
                BreadcrumbItem(title: "Details", url: nil),
            ]
            let component = BreadcrumbComponent(items: items)
            let html = component.render()

            #expect(html.contains("<li class=\"is-active\"><span>Details</span></li>"))
        }

        @Test("last breadcrumb item displays as active span without link")
        func createsLinksForAllItemsExceptLast() {
            let items = [
                BreadcrumbItem(title: "Admin", url: "/admin"),
                BreadcrumbItem(title: "Users", url: "/admin/users"),
                BreadcrumbItem(title: "Details", url: nil),
            ]
            let component = BreadcrumbComponent(items: items)
            let html = component.render()

            #expect(html.contains("<a href=\"/admin\">Admin</a>"))
            #expect(html.contains("<a href=\"/admin/users\">Users</a>"))
            #expect(html.contains("<span>Details</span>"))
        }
    }

    @Suite("HTML Structure", .serialized)
    struct HTMLStructureTests {

        @Test("uses proper semantic HTML structure")
        func usesProperSemanticHTMLStructure() {
            let items = [BreadcrumbItem(title: "Admin", url: "/admin")]
            let component = BreadcrumbComponent(items: items)
            let html = component.render()

            #expect(html.contains("<nav class=\"breadcrumb\">"))
            #expect(html.contains("<ul>"))
            #expect(html.contains("<li class=\"is-active\">"))
            #expect(html.contains("</li>"))
            #expect(html.contains("</ul>"))
            #expect(html.contains("</nav>"))
        }

        @Test("applies correct Bulma CSS classes")
        func appliesCorrectBulmaCSSClasses() {
            let items = [
                BreadcrumbItem(title: "Admin", url: "/admin"),
                BreadcrumbItem(title: "Users", url: nil),
            ]
            let component = BreadcrumbComponent(items: items)
            let html = component.render()

            #expect(html.contains("class=\"breadcrumb\""))
            #expect(html.contains("class=\"is-active\""))
        }
    }

    @Suite("Accessibility", .serialized)
    struct AccessibilityTests {

        @Test("uses nav element for semantic navigation")
        func usesNavElementForSemanticNavigation() {
            let items = [BreadcrumbItem(title: "Admin", url: "/admin")]
            let component = BreadcrumbComponent(items: items)
            let html = component.render()

            #expect(html.contains("<nav class=\"breadcrumb\">"))
        }

        @Test("marks current page as active for screen readers")
        func marksCurrentPageAsActiveForScreenReaders() {
            let items = [
                BreadcrumbItem(title: "Admin", url: "/admin"),
                BreadcrumbItem(title: "Users", url: nil),
            ]
            let component = BreadcrumbComponent(items: items)
            let html = component.render()

            #expect(html.contains("class=\"is-active\""))
        }
    }

    @Suite("Admin Navigation Convenience", .serialized)
    struct AdminNavigationConvenienceTests {

        @Test("admin users breadcrumb displays admin link and active users span")
        func adminUsersBreadcrumbCreatesCorrectStructure() {
            let component = BreadcrumbComponent.adminUsers()
            let html = component.render()

            #expect(html.contains("<a href=\"/admin\">Admin</a>"))
            #expect(html.contains("<span>Users</span>"))
            #expect(html.contains("class=\"is-active\""))
        }

        @Test("admin people breadcrumb displays admin link and active people span")
        func adminPeopleBreadcrumbCreatesCorrectStructure() {
            let component = BreadcrumbComponent.adminPeople()
            let html = component.render()

            #expect(html.contains("<a href=\"/admin\">Admin</a>"))
            #expect(html.contains("<span>People</span>"))
            #expect(html.contains("class=\"is-active\""))
        }

        @Test("admin legal jurisdictions breadcrumb displays admin link and active legal jurisdictions span")
        func adminLegalJurisdictionsBreadcrumbCreatesCorrectStructure() {
            let component = BreadcrumbComponent.adminLegalJurisdictions()
            let html = component.render()

            #expect(html.contains("<a href=\"/admin\">Admin</a>"))
            #expect(html.contains("<span>Legal Jurisdictions</span>"))
            #expect(html.contains("class=\"is-active\""))
        }
    }
}
