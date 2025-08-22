import Foundation

/// Mock implementation of Docket Alarm API for testing purposes
///
/// This mock provides a test-compatible implementation that doesn't require
/// external network calls or API credentials, enabling tests to run in
/// isolated environments without dependencies on external services.
public struct MockDocketAlarmAPI {

    /// Mock search results for different query types
    private static let mockSearchResults: [String: MockSearchResult] = [
        "contract": MockSearchResult(
            totalCount: 50,
            cases: [
                MockCase(
                    title: "Smith v. Jones Construction Co.",
                    court: "U.S. District Court for the District of Nevada",
                    docket: "2:24-cv-00123-JAD-VCF",
                    dateFiled: "2024-01-15",
                    type: "Contract Dispute"
                ),
                MockCase(
                    title: "ABC Corp v. XYZ Services LLC",
                    court: "Nevada Supreme Court",
                    docket: "85432",
                    dateFiled: "2024-02-10",
                    type: "Breach of Contract"
                ),
            ]
        ),
        "employment": MockSearchResult(
            totalCount: 25,
            cases: [
                MockCase(
                    title: "Johnson v. Tech Innovations Inc.",
                    court: "U.S. District Court for the District of Nevada",
                    docket: "2:24-cv-00456-RFB-DJA",
                    dateFiled: "2024-03-01",
                    type: "Employment Discrimination"
                )
            ]
        ),
        "trademark": MockSearchResult(
            totalCount: 15,
            cases: [
                MockCase(
                    title: "Neon Brands LLC v. Bright Signs Co.",
                    court: "U.S. District Court for the District of Nevada",
                    docket: "2:24-cv-00789-GMN-EJY",
                    dateFiled: "2024-04-05",
                    type: "Trademark Infringement"
                )
            ]
        ),
    ]

    /// Searches legal cases using mock data instead of external API
    ///
    /// This function provides predictable responses for testing while maintaining
    /// the same interface as the real Docket Alarm API function.
    ///
    /// - Parameter query: Search query string
    /// - Returns: Formatted search results string matching real API format
    public static func searchCases(query: String) -> String {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Find the best match for the query
        let matchingKey = mockSearchResults.keys.first { key in
            normalizedQuery.contains(key) || key.contains(normalizedQuery)
        }

        guard let key = matchingKey, let result = mockSearchResults[key] else {
            // Return empty results for unrecognized queries
            return """
                Search Results for: '\(query)'

                Source: Docket Alarm API (Mock)

                Found 0 total cases.

                ---
                Search powered by Docket Alarm API
                """
        }

        return formatMockResponse(result, query: query)
    }

    /// Formats mock search results to match real API response format
    private static func formatMockResponse(_ result: MockSearchResult, query: String) -> String {
        var response = """
            Search Results for: '\(query)'

            Source: Docket Alarm API (Mock)

            Found \(result.totalCount) total cases (showing first \(result.cases.count)):

            """

        for (index, case_) in result.cases.enumerated() {
            response += """
                \(index + 1). \(case_.title)
                   Court: \(case_.court)
                   Docket: \(case_.docket)\(case_.type.isEmpty ? "" : " (\(case_.type))")
                   Date Filed: \(case_.dateFiled)

                """
        }

        response += "\n---\nSearch powered by Docket Alarm API"
        return response
    }
}

/// Mock search result structure
private struct MockSearchResult {
    let totalCount: Int
    let cases: [MockCase]
}

/// Mock case data structure
private struct MockCase {
    let title: String
    let court: String
    let docket: String
    let dateFiled: String
    let type: String
}
