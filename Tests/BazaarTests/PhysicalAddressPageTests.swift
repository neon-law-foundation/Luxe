import Dali
import Elementary
import TestUtilities
import Testing
import Vapor
import VaporElementary
import VaporTesting

@testable import Bazaar

@Suite("Physical Address Page Display Tests", .serialized)
struct PhysicalAddressPageTests {
    @Test("Physical address page displays service information and signup steps")
    func physicalAddressPageDisplaysServiceInformation() async throws {
        try await TestUtilities.withApp { app, database in
            try configurePhysicalAddressApp(app)

            try await app.test(.GET, "/physical-address") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)

                let body = response.body.string
                #expect(body.contains("Nevada Physical Address Service"))
                #expect(body.contains("How to Sign Up"))
                #expect(body.contains("Step 1: Contact Us"))
                #expect(body.contains("Step 2: Complete Application"))
                #expect(body.contains("Step 3: Payment"))
                #expect(body.contains("Step 4: Notarization"))
                #expect(body.contains("Service Guarantee"))
                #expect(body.contains("One business day mail delivery"))
                #expect(body.contains("mailto:support@sagebrush.services"))
                #expect(body.contains("bulma"))
                #expect(body.contains("#006400"))
            }
        }
    }
}

// MARK: - Helper Functions

private func configurePhysicalAddressApp(_ app: Application) throws {
    // Configure DALI models and database
    try configureDali(app)

    // Configure physical address page route
    app.get("physical-address") { req in
        HTMLResponse {
            PhysicalAddressPage()
        }
    }
}
