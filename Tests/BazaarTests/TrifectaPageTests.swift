import Dali
import Elementary
import TestUtilities
import Testing
import Vapor
import VaporElementary
import VaporTesting

@testable import Bazaar

@Suite("Trifecta Page", .serialized)
struct TrifectaPageTests {
    @Test("trifecta route returns HTML page")
    func trifectaRoute() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTrifectaApp(app)

            try await app.test(.GET, "/trifecta") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)

                let body = response.body.string
                #expect(body.contains("How the trifecta works"))
                #expect(body.contains("Neon Law"))
                #expect(body.contains("Neon Law Foundation"))
                #expect(body.contains("Sagebrush Services™"))
                #expect(body.contains("support@sagebrush.services"))
                #expect(body.contains("© 2025 Sagebrush. All rights reserved."))
            }
        }
    }

    @Test("trifecta page contains organization descriptions")
    func trifectaPageContainsOrganizationDescriptions() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTrifectaApp(app)

            try await app.test(.GET, "/trifecta") { response in
                #expect(response.status == .ok)
                let body = response.body.string

                // Check for Neon Law description
                #expect(body.contains("Neon Law is a law firm PLLC in Nevada"))
                #expect(body.contains("only lawyers can participate in profit sharing"))

                // Check for Neon Law Foundation description
                #expect(body.contains("Neon Law Foundation is a 501(c)(3) non-profit"))
                #expect(body.contains("OSS repository, Luxe"))
                #expect(body.contains("creating Sagebrush Standards"))

                // Check for Sagebrush Services description
                #expect(body.contains("Sagebrush Services™ is a Nevada corporation"))
                #expect(body.contains("Mailroom: Send your mail here"))
                #expect(body.contains("Entity Management: File and renew"))
                #expect(body.contains("Cap Tables: Manage how to share the pie"))
                #expect(body.contains("Personal Data: Protect your privacy"))
            }
        }
    }

    @Test("trifecta page contains how it works section")
    func trifectaPageContainsHowItWorksSection() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTrifectaApp(app)

            try await app.test(.GET, "/trifecta") { response in
                #expect(response.status == .ok)
                let body = response.body.string

                #expect(body.contains("This repository is licensed from Neon Law Foundation"))
                #expect(body.contains("operations of running the software are managed by Sagebrush Services™"))
                #expect(body.contains("Continuous integration is NLF and continuous deployment is Sagebrush Services™"))
                #expect(body.contains("Sagebrush Services™ is where all non-legal-service work is billed from"))
                #expect(body.contains("Neon Law is where legal advice is billed from"))
                #expect(body.contains("Sagebrush Services™ and Neon Law pledge 10% of gross revenue"))
                #expect(body.contains("Each entity has its own accounting ledger and bank accounts"))
            }
        }
    }
}

// MARK: - Helper Functions

private func configureTrifectaApp(_ app: Application) throws {
    // Configure DALI models and database
    try configureDali(app)

    // Configure trifecta page route
    app.get("trifecta") { req in
        HTMLResponse {
            TrifectaPage()
        }
    }
}
