import Dali
import Elementary
import TestUtilities
import Testing
import Vapor
import VaporElementary
import VaporTesting

@testable import Bazaar

@Suite("Onboarding Page Display Tests", .serialized)
struct OnboardingPageTests {
    @Test("Onboarding page displays trademark search and virtual mailbox setup")
    func onboardingPageDisplaysTrademarkAndMailboxServices() async throws {
        try await TestUtilities.withApp { app, database in
            try configureOnboardingApp(app)

            try await app.test(.GET, "/onboarding") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)

                let body = response.body.string

                // Test page title and main content
                #expect(body.contains("Complete Business Setup Services"))
                #expect(body.contains("Nevada address, trademark search &amp; filing, all in one place"))

                // Test trademark search section
                #expect(body.contains("Trademark Search &amp; Filing"))
                #expect(body.contains("Free Trademark Name Search"))
                #expect(body.contains("Professional Trademark Filing - $499 per class"))
                #expect(body.contains("Neon Law"))
                #expect(body.contains("trademark-search-input"))
                #expect(body.contains("searchTrademark()"))
                #expect(body.contains("Why Trademark Protection?"))
                #expect(body.contains("Exclusive Rights"))
                #expect(body.contains("Asset Value"))
                #expect(body.contains("Legal Protection"))

                // Test physical address section
                #expect(body.contains("Physical Address Setup"))
                #expect(body.contains("Get Your Nevada Address in 5 Simple Steps"))
                #expect(body.contains("Required Documents"))
                #expect(body.contains("USPS Form 1583"))
                #expect(body.contains("Photo ID"))
                #expect(body.contains("Step-by-Step Process"))
                #expect(body.contains("Download and Complete USPS Form 1583"))
                #expect(body.contains("Get Form Notarized"))
                #expect(body.contains("Gather Required Documentation"))
                #expect(body.contains("Submit Documentation"))
                #expect(body.contains("Payment Processing"))
                #expect(body.contains("Quick Start"))
                #expect(body.contains("Timeline"))
                #expect(body.contains("Our Guarantee"))
                #expect(body.contains("mailto:support@sagebrush.services"))

                // Test styling and scripts
                #expect(body.contains("bulma"))
                #expect(body.contains("#006400"))
                #expect(body.contains("fetch('/api/trademark/search'"))
            }
        }
    }
}

// MARK: - Helper Functions

private func configureOnboardingApp(_ app: Application) throws {
    // Configure DALI models and database
    try configureDali(app)

    // Configure onboarding page route
    app.get("onboarding") { req in
        HTMLResponse {
            OnboardingPage()
        }
    }
}
