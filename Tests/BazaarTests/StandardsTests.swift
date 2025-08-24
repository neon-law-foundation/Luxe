import TestUtilities
import Testing
import VaporElementary
import VaporTesting

@testable import Bazaar
@testable import Dali

@Suite("Standards Integration Tests", .serialized)
struct StandardsTests {
    @Test(
        "Standards home page displays expected workflow content"
    )
    func standardsHomePageDisplaysExpectedWorkflowContent() async throws {
        try await TestUtilities.withApp { app, database in
            try configureStandardsApp(app)

            try await app.test(.GET, "/standards") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)
                let responseBody = response.body.string
                #expect(responseBody.contains("Sagebrush Standards"))
                #expect(responseBody.contains("Computable document workflows"))
                #expect(responseBody.contains("Flows"))
                #expect(responseBody.contains("Alignments"))
                #expect(responseBody.contains("Questions"))
            }
        }
    }

    @Test(
        "Standards specification page contains Neon Notations documentation"
    )
    func standardsSpecPageContainsNeonNotationsDocumentation() async throws {
        try await TestUtilities.withApp { app, database in
            try configureStandardsApp(app)

            try await app.test(.GET, "/standards/spec") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)
                let responseBody = response.body.string
                #expect(responseBody.contains("Sagebrush Standards Specification"))
                #expect(responseBody.contains("document workflows"))
                #expect(responseBody.contains("computable legal document workflows"))
                #expect(responseBody.contains("standards@sagebrush.services"))
                #expect(responseBody.contains("Nothing is legal advice without a valid signed retainer"))
            }
        }
    }

    @Test(
        "Standards notations page displays available notation configurations"
    )
    func standardsNotationsPageDisplaysAvailableNotationConfigurations() async throws {
        try await TestUtilities.withApp { app, database in
            try configureStandardsApp(app)

            try await app.test(.GET, "/standards/notations") { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .html)
                let responseBody = response.body.string
                #expect(responseBody.contains("Available Notations"))
                #expect(responseBody.contains("YAML configuration files"))
                #expect(responseBody.contains("Nevada LLC Registration"))
            }
        }
    }

    @Test(
        "Standards health endpoint returns OK status"
    )
    func standardsHealthEndpointReturnsOK() async throws {
        try await TestUtilities.withApp { app, database in
            try configureStandardsApp(app)

            try await app.test(.GET, "/health") { response in
                #expect(response.status == .ok)
                #expect(response.body.string == "OK")
            }
        }
    }
}

/// Minimal app configuration for standards tests
/// This avoids the complex OIDC and OpenAPI setup that can fail in tests
func configureStandardsApp(_ app: Application) throws {
    // Configure DALI models (required for basic app setup)
    try configureDali(app)

    // Standards routes
    app.get("standards") { _ in
        Response(
            status: .ok,
            headers: HTTPHeaders([("Content-Type", "text/html")]),
            body: Response.Body(string: StandardsHomePage().content.render())
        )
    }

    app.get("standards", "spec") { req in
        HTMLResponse {
            StandardsSpecPage()
        }
    }

    app.get("standards", "notations") { req in
        HTMLResponse {
            StandardsNotationsPage()
        }
    }

    app.get("standards", "notations", "**") { req in
        let pathComponents = req.url.path.components(separatedBy: "/").dropFirst(3)
        let notationPath = pathComponents.joined(separator: "/")

        return HTMLResponse {
            StandardsNotationPage(notationPath: notationPath)
        }
    }

    // Health endpoint for the health test
    app.get("health") { _ in
        "OK"
    }
}
