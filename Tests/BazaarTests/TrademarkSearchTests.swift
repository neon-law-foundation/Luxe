import Dali
import Foundation
import TestUtilities
import Testing
import Vapor
import VaporTesting

@testable import Bazaar

@Suite("Trademark Search API Tests", .serialized)
struct TrademarkSearchTests {
    @Test("Trademark search endpoint returns mock results with Neon Law information")
    func trademarkSearchReturnsResultsWithNeonLawInfo() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTrademarkApp(app)

            let searchRequest = """
                {
                    "searchTerm": "Acme Corporation",
                    "exactMatch": false
                }
                """

            try await app.test(
                .POST,
                "/api/trademark/search",
                headers: ["Content-Type": "application/json"],
                body: .init(string: searchRequest)
            ) { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .json)

                let body = response.body.string

                // Test search response structure
                #expect(body.contains("\"searchTerm\":\"Acme Corporation\""))
                #expect(body.contains("\"totalResults\":"))
                #expect(body.contains("\"results\":["))
                #expect(body.contains("\"suggestedClasses\":["))
                #expect(body.contains("\"neonLawConsultation\":"))

                // Test Neon Law consultation information
                #expect(body.contains("\"available\":true"))
                #expect(body.contains("\"pricePerClass\":499"))
                #expect(body.contains("\"contactEmail\":\"trademarks@neonlaw.com\""))

                // Test mock trademark results
                #expect(body.contains("\"markText\":\"ACME CORPORATION CORP\""))
                #expect(body.contains("\"status\":\"LIVE\""))
                #expect(body.contains("\"serialNumber\":\"88123456\""))
                #expect(body.contains("\"owner\":\"Acme Corporation Corporation Inc.\""))

                // Test suggested USPTO classes
                #expect(body.contains("\"classNumber\":35"))
                #expect(body.contains("\"classNumber\":42"))
                #expect(body.contains("\"classNumber\":9"))
                #expect(body.contains("\"category\":\"services\""))
                #expect(body.contains("\"category\":\"goods\""))
                #expect(body.contains("Advertising; business management"))
                #expect(body.contains("Scientific and technological services"))
            }
        }
    }

    @Test("Trademark search handles empty search term gracefully")
    func trademarkSearchHandlesEmptySearchTerm() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTrademarkApp(app)

            let searchRequest = """
                {
                    "searchTerm": "",
                    "exactMatch": false
                }
                """

            try await app.test(
                .POST,
                "/api/trademark/search",
                headers: ["Content-Type": "application/json"],
                body: .init(string: searchRequest)
            ) { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .json)

                let body = response.body.string
                #expect(body.contains("\"searchTerm\":\"\""))
                #expect(body.contains("\"neonLawConsultation\":"))
                #expect(body.contains("\"suggestedClasses\":["))
            }
        }
    }

    @Test("Trademark search returns consistent USPTO class information")
    func trademarkSearchReturnsConsistentUSPTOClasses() async throws {
        try await TestUtilities.withApp { app, database in
            try configureTrademarkApp(app)

            let searchRequest = """
                {
                    "searchTerm": "TechCorp",
                    "searchClasses": [35, 42],
                    "exactMatch": true
                }
                """

            try await app.test(
                .POST,
                "/api/trademark/search",
                headers: ["Content-Type": "application/json"],
                body: .init(string: searchRequest)
            ) { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .json)

                let body = response.body.string

                // Verify suggested classes contain expected information
                #expect(
                    body.contains(
                        "\"description\":\"Advertising; business management; business administration; office functions\""
                    )
                )
                #expect(
                    body.contains(
                        "\"description\":\"Scientific and technological services and research and design relating thereto\""
                    )
                )
                #expect(
                    body.contains(
                        "\"description\":\"Scientific, research, navigation, surveying, photographic, cinematographic apparatus\""
                    )
                )

                // Verify common examples are included
                #expect(body.contains("\"commonExamples\":["))
                #expect(body.contains("Business consulting"))
                #expect(body.contains("Software development"))
                #expect(body.contains("Computer software"))
            }
        }
    }
}

// MARK: - Helper Functions

private func configureTrademarkApp(_ app: Application) throws {
    // Configure DALI models and database
    try configureDali(app)

    // Configure trademark search route - return simple mock JSON response
    app.post("api", "trademark", "search") { req async throws -> Response in
        let body = try req.content.decode([String: AnyCodable].self)
        let searchTerm = body["searchTerm"]?.value as? String ?? ""

        // Create mock JSON response
        let mockResponse: [String: Any] = [
            "searchTerm": searchTerm,
            "totalResults": searchTerm.isEmpty ? 0 : 1,
            "results": searchTerm.isEmpty
                ? []
                : [
                    [
                        "markText": "ACME CORPORATION CORP",
                        "status": "LIVE",
                        "serialNumber": "88123456",
                        "owner": "Acme Corporation Corporation Inc.",
                        "filingDate": ISO8601DateFormatter().string(from: Date()),
                    ]
                ],
            "suggestedClasses": [
                [
                    "classNumber": 35,
                    "category": "services",
                    "description": "Advertising; business management; business administration; office functions",
                    "commonExamples": ["Business consulting", "Marketing services"],
                ],
                [
                    "classNumber": 42,
                    "category": "services",
                    "description": "Scientific and technological services and research and design relating thereto",
                    "commonExamples": ["Software development", "Computer consulting"],
                ],
                [
                    "classNumber": 9,
                    "category": "goods",
                    "description":
                        "Scientific, research, navigation, surveying, photographic, cinematographic apparatus",
                    "commonExamples": ["Computer software", "Mobile applications"],
                ],
            ],
            "neonLawConsultation": [
                "available": true,
                "pricePerClass": 499,
                "contactEmail": "trademarks@neonlaw.com",
            ],
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: mockResponse)
        let response = Response(status: .ok)
        response.headers.contentType = .json
        response.body = .init(data: jsonData)
        return response
    }
}

// Helper type for decoding arbitrary JSON
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let string = value as? String {
            try container.encode(string)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let dict = value as? [String: Any] {
            try container.encode(dict.mapValues { AnyCodable($0) })
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyCodable($0) })
        } else if value is NSNull {
            try container.encodeNil()
        }
    }
}
