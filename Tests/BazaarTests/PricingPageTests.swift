import Dali
import Elementary
import TestUtilities
import Testing
import Vapor
import VaporElementary
import VaporTesting

@testable import Bazaar

@Suite("Pricing Page Display Tests", .serialized)
struct PricingPageTests {
    @Test("Pricing page displays service information and pricing details")
    func pricingPageDisplaysServiceInformationAndPricing() async throws {
        try await TestUtilities.withApp { app, database in
            try configurePricingApp(app)

            try await app.test(.GET, "/pricing") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)

                let body = response.body.string
                #expect(body.contains("Simple, Transparent Pricing"))
                #expect(body.contains("Physical address and license compliance services"))
                #expect(body.contains("Physical Address &amp; License Compliance"))
                #expect(body.contains("$49"))
                #expect(body.contains("$49/month"))
                #expect(body.contains("Mail Services"))
                #expect(body.contains("License Compliance"))
                #expect(body.contains("Security &amp; Privacy"))
                #expect(body.contains("Digital Features"))
                #expect(body.contains("Business Benefits"))
                #expect(body.contains("Real Nevada street address"))
                #expect(body.contains("Digital mail scanning"))
                #expect(body.contains("Nevada Secretary of State filings"))
                #expect(body.contains("Important Note About Filing Fees"))
                #expect(body.contains("Mobile app access"))
                #expect(body.contains("Professional business address"))
                #expect(body.contains("Additional Services"))
                #expect(body.contains("Express Forwarding"))
                #expect(body.contains("Document Scanning"))
                #expect(body.contains("Phone Services"))
                #expect(body.contains("Frequently Asked Questions"))
                #expect(body.contains("mailto:support@sagebrush.services"))
                #expect(body.contains("bulma"))
                #expect(body.contains("#006400"))
            }
        }
    }
}

// MARK: - Helper Functions

private func configurePricingApp(_ app: Application) throws {
    // Configure DALI models and database
    try configureDali(app)

    // Configure pricing page route
    app.get("pricing") { req in
        HTMLResponse {
            PricingPage()
        }
    }
}
