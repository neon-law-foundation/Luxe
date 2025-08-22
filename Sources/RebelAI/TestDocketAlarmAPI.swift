import Foundation

/// Test-compatible function for Docket Alarm API searches
///
/// This function provides mock responses for test environments while maintaining
/// the same interface as the production API function. It's designed to be used
/// in place of `searchDocketAlarmCases` when running tests.
///
/// - Parameter query: Search query string
/// - Returns: Formatted search results string
/// - Throws: No errors in mock implementation
public func mockSearchDocketAlarmCases(query: String) async throws -> String {
    // Simulate a brief network delay for realistic testing
    try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

    return MockDocketAlarmAPI.searchCases(query: query)
}
