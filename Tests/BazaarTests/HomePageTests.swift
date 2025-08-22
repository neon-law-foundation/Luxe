import Bouncer
import Dali
import Fluent
import FluentPostgresDriver
import TestUtilities
import Testing
import Vapor
import VaporElementary
import VaporTesting

@testable import Bazaar

@Suite("Home Page Rendering Tests", .serialized)
struct HomePageTests {
    @Test("Home page renders with complete content and pricing information")
    func homePageRendersWithCompleteContentAndPricing() async throws {
        try await TestUtilities.withApp { app, database in
            try configureHomePageApp(app)

            try await app.test(.GET, "/") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)

                let body = response.body.string
                #expect(body.contains("Your all-in-one Nevada entities platform"))
                #expect(body.contains("Sagebrush"))
                #expect(body.contains("Why Choose Sagebrush?"))
                #expect(body.contains("Complete mail management, compliance, and equity services"))
                #expect(body.contains("Nevada Secretary of State filing assistance"))
                #expect(body.contains("Stock issuance and equity tracking"))
                #expect(body.contains("$49"))
                #expect(body.contains("/month"))
                #expect(body.contains("Physical address + license compliance + cap table guidance"))
                #expect(body.contains("Filing fees and legal services billed separately"))
                #expect(body.contains("Cap Table &amp; Stock Issuance Management"))
                #expect(body.contains("Professional cap table updates and tracking"))
                #expect(body.contains("Stock option and RSU administration"))
                #expect(body.contains("Nevada-specific compliance expertise"))
                #expect(body.contains("Learn About Cap Tables"))
                #expect(body.contains("/blog/cap-table-equity"))
                #expect(body.contains("Why Cap Tables Matter"))
                #expect(body.contains("/pricing"))
                #expect(body.contains("/blog"))
                #expect(body.contains("mailto:support@sagebrush.services"))
                #expect(body.contains("/physical-address"))
                #expect(body.contains("bulma"))
                #expect(body.contains("#006400"))
                #expect(body.contains("#DAA520"))
            }
        }
    }

    @Test("Home page includes favicon link in HTML head")
    func homePageIncludesFaviconLink() async throws {
        try await TestUtilities.withApp { app, database in
            try configureHomePageApp(app)

            try await app.test(.GET, "/") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)

                let body = response.body.string
                #expect(body.contains("link rel=\"icon\""))
                #expect(body.contains("favicon.ico"))
            }
        }
    }
}

// MARK: - Test Configuration

/// Configures the Bazaar application for HomePageTests with TestAuthMiddleware.
///
/// This function sets up the minimal configuration needed to test home page routes
/// with TestAuthMiddleware instead of the full OIDC authentication that doesn't work
/// with transaction databases.
///
/// - Parameter app: The Vapor application to configure
/// - Throws: Configuration errors if setup fails
func configureHomePageApp(_ app: Application) throws {
    // Configure DALI models and database (must be done before any database usage)
    try configureDali(app)

    // Configure the home page route that the tests are checking
    app.get { req in
        HTMLResponse {
            HomePage(currentUser: nil)  // No authentication required for home page
        }
    }
}
