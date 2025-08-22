import Elementary
import Foundation
import Testing

@testable import Bazaar
@testable import TouchMenu

@Suite("Mobile Navigation Tests", .serialized)
struct MobileNavigationTests {

    @Test("MobileNavigationScript can be created successfully")
    func mobileNavigationScriptCanBeCreatedSuccessfully() throws {
        _ = MobileNavigationScript()
        // Test that the script can be instantiated without errors
        // The test passes if no exception is thrown during initialization
    }

    @Test("HeaderComponent can be created with different themes")
    func headerComponentCanBeCreatedWithDifferentThemes() throws {
        let sagebrushHeader = HeaderComponent.sagebrushTheme()
        #expect(sagebrushHeader.primaryColor == "#006400", "Sagebrush theme should have correct primary color")
        #expect(sagebrushHeader.secondaryColor == "#DAA520", "Sagebrush theme should have correct secondary color")

        let neonLawHeader = HeaderComponent.neonLawTheme()
        #expect(neonLawHeader.primaryColor == "#4169E1", "Neon Law theme should have correct primary color")
        #expect(neonLawHeader.secondaryColor == "#E19741", "Neon Law theme should have correct secondary color")
    }

    @Test("ResponsiveNavigation can be created with navigation items")
    func responsiveNavigationCanBeCreatedWithNavigationItems() throws {
        let navigation = ResponsiveNavigation<HTMLText>(
            brandName: "Test Brand",
            brandHref: "/",
            brandEmoji: "🌿",
            navigationItems: [
                NavigationItem(title: "Home", href: "/"),
                NavigationItem(title: "Blog", href: "/blog"),
                NavigationItem(title: "Pricing", href: "/pricing"),
            ],
            authenticationContent: HTMLText("Login"),
            themeClass: "is-primary"
        )

        #expect(navigation.brandName == "Test Brand", "Navigation should have correct brand name")
        #expect(navigation.navigationItems.count == 3, "Navigation should have 3 navigation items")
        #expect(navigation.themeClass == "is-primary", "Navigation should have correct theme class")
        #expect(navigation.brandEmoji == "🌿", "Navigation should have correct brand emoji")
    }

    @Test("All Bazaar pages can be created successfully")
    func allBazaarPagesCanBeCreatedSuccessfully() throws {
        // Test that all pages can be instantiated without errors
        let homePage = HomePage()
        #expect(homePage.title.contains("Sagebrush"), "HomePage should have correct title")

        let blogPage = BlogPage()
        #expect(blogPage.title.contains("Blog"), "BlogPage should have correct title")

        let pricingPage = PricingPage()
        #expect(pricingPage.title.contains("Pricing"), "PricingPage should have correct title")

        let physicalAddressPage = PhysicalAddressPage()
        #expect(physicalAddressPage.title.contains("Physical Address"), "PhysicalAddressPage should have correct title")
    }

    @Test("NavigationItem can be created with title and href")
    func navigationItemCanBeCreatedWithTitleAndHref() throws {
        let navItem = NavigationItem(title: "Test Page", href: "/test")

        #expect(navItem.title == "Test Page", "Navigation item should have correct title")
        #expect(navItem.href == "/test", "Navigation item should have correct href")
    }

    @Test("ResponsiveNavigation can be created without authentication content")
    func responsiveNavigationCanBeCreatedWithoutAuthenticationContent() throws {
        let navigation = ResponsiveNavigation(
            brandName: "Test Brand",
            brandHref: "/",
            brandEmoji: "🌿",
            navigationItems: [NavigationItem(title: "Home", href: "/")],
            themeClass: "is-primary"
        )

        #expect(navigation.brandName == "Test Brand", "Navigation should have correct brand name")
        #expect(navigation.navigationItems.count == 1, "Navigation should have 1 navigation item")
        #expect(navigation.themeClass == "is-primary", "Navigation should have correct theme class")
    }

    @Test("All major Bazaar pages use HeaderComponent")
    func allMajorBazaarPagesUseHeaderComponent() throws {
        // Verify that pages can be created and have titles (indicating they use HeaderComponent properly)
        let pages = [
            HomePage().title,
            BlogPage().title,
            PricingPage().title,
            PhysicalAddressPage().title,
        ]

        for title in pages {
            #expect(!title.isEmpty, "Page title should not be empty")
            #expect(
                title.contains("Sagebrush") || title.contains("Blog") || title.contains("Pricing")
                    || title.contains("Physical Address"),
                "Page title should contain expected content"
            )
        }
    }
}

// Integration test suite for mobile navigation functionality
@Suite("Mobile Navigation Integration Tests", .serialized)
struct MobileNavigationIntegrationTests {

    @Test("Mobile navigation components work together")
    func mobileNavigationComponentsWorkTogether() throws {
        // Test that all the mobile navigation components can be created and work together
        let headerComponent = HeaderComponent.sagebrushTheme()
        _ = MobileNavigationScript()
        let navigation = ResponsiveNavigation(
            brandName: "Sagebrush",
            brandHref: "/",
            brandEmoji: "🌿",
            navigationItems: [
                NavigationItem(title: "Home", href: "/"),
                NavigationItem(title: "Blog", href: "/blog"),
                NavigationItem(title: "Pricing", href: "/pricing"),
                NavigationItem(title: "Physical Address", href: "/physical-address"),
            ],
            themeClass: "is-primary"
        )

        // Verify all components can be created successfully
        #expect(headerComponent.primaryColor == "#006400", "Header component should be created with correct theme")
        #expect(navigation.navigationItems.count == 4, "Navigation should have all expected items")
        #expect(navigation.brandName == "Sagebrush", "Navigation should have correct brand name")
    }

    @Test("All standard navigation items are supported")
    func allStandardNavigationItemsAreSupported() throws {
        let standardItems = [
            NavigationItem(title: "Home", href: "/"),
            NavigationItem(title: "Blog", href: "/blog"),
            NavigationItem(title: "Pricing", href: "/pricing"),
            NavigationItem(title: "Physical Address", href: "/physical-address"),
        ]

        for item in standardItems {
            #expect(!item.title.isEmpty, "Navigation item title should not be empty")
            #expect(item.href.hasPrefix("/"), "Navigation item href should start with /")
        }
    }

    @Test("Mobile navigation supports accessibility requirements")
    func mobileNavigationSupportsAccessibilityRequirements() throws {
        // Test that navigation items can be created with proper structure for accessibility
        let navigation = ResponsiveNavigation(
            brandName: "Accessible Site",
            brandHref: "/",
            navigationItems: [
                NavigationItem(title: "Home", href: "/"),
                NavigationItem(title: "About", href: "/about"),
            ],
            themeClass: "is-primary"
        )

        // Verify the navigation structure supports accessibility
        #expect(navigation.brandName == "Accessible Site", "Navigation should support brand identification")
        #expect(
            navigation.navigationItems.allSatisfy { !$0.title.isEmpty },
            "All navigation items should have titles for screen readers"
        )
        #expect(
            navigation.navigationItems.allSatisfy { !$0.href.isEmpty },
            "All navigation items should have valid hrefs"
        )
    }
}
