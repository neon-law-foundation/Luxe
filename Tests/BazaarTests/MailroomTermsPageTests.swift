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

@Suite("Mailroom Terms Page Rendering Tests", .serialized)
struct MailroomTermsPageTests {
    @Test("Mailroom terms page renders with complete content")
    func mailroomTermsPageRendersWithCompleteContent() async throws {
        try await TestUtilities.withApp { app, database in
            try configureMailroomTermsApp(app)

            try await app.test(.GET, "/mailroom-terms") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)

                let body = response.body.string
                #expect(body.contains("Mailroom Terms and Conditions"))
                #expect(body.contains("Sagebrush Services"))
                #expect(body.contains("Service Authorization"))
                #expect(body.contains("Mail Pickup Requirements"))
                #expect(body.contains("Mail Volume Limitations"))
                #expect(body.contains("Additional Fees"))
                #expect(body.contains("PMB"))
                #expect(body.contains("5150 Mae Anne Ave. Ste 405"))
                #expect(body.contains("Reno, NV 89523"))
                #expect(body.contains("support@sagebrush.services"))
            }
        }
    }

    @Test("Mailroom terms page includes proper navigation and footer")
    func mailroomTermsPageIncludesNavigationAndFooter() async throws {
        try await TestUtilities.withApp { app, database in
            try configureMailroomTermsApp(app)

            try await app.test(.GET, "/mailroom-terms") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)

                let body = response.body.string
                #expect(body.contains("footer"))
                #expect(body.contains("Privacy Policy"))
                #expect(body.contains("© 2025 Sagebrush"))
            }
        }
    }
}

// MARK: - Test Configuration

/// Configures the Bazaar application for MailroomTermsPageTests.
///
/// This function sets up the minimal configuration needed to test mailroom terms page routes.
///
/// - Parameter app: The Vapor application to configure
/// - Throws: Configuration errors if setup fails
func configureMailroomTermsApp(_ app: Application) throws {
    // Configure DALI models and database (must be done before any database usage)
    try configureDali(app)

    // Configure the mailroom terms page route that the tests are checking
    app.get("mailroom-terms") { _ in
        HTMLResponse {
            MailroomTermsPage()
        }
    }
}
