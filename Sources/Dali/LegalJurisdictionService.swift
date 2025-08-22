import Fluent
import FluentPostgresDriver
import Foundation
import PostgresNIO
import Vapor

/// Service for legal jurisdiction operations
public struct LegalJurisdictionService: Sendable {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    /// Lists all legal jurisdictions
    /// - Parameter limit: Maximum number of results to return (default 100)
    /// - Parameter offset: Number of results to skip (default 0)
    /// - Returns: Array of legal jurisdictions
    public func listJurisdictions(limit: Int = 100, offset: Int = 0) async throws -> [LegalJurisdiction] {
        try await LegalJurisdiction.query(on: database)
            .limit(limit)
            .offset(offset)
            .sort(\.$name, .ascending)
            .all()
    }

    /// Retrieves a legal jurisdiction by ID
    /// - Parameter jurisdictionId: The UUID of the jurisdiction to retrieve
    /// - Returns: The jurisdiction, or nil if not found
    public func getJurisdiction(jurisdictionId: UUID) async throws -> LegalJurisdiction? {
        try await LegalJurisdiction.find(jurisdictionId, on: database)
    }

    /// Lists jurisdictions for API with name and code only
    /// - Returns: Array of dictionaries with name and code
    public func listJurisdictionsForAPI() async throws -> [[String: String]] {
        // Ensure we have a PostgresDatabase for raw SQL access
        guard let postgresDatabase = database as? PostgresDatabase else {
            throw ValidationError("PostgreSQL database required for API operations")
        }

        // Query the database using raw SQL to match existing API behavior
        let results = try await postgresDatabase.sql()
            .raw("SELECT name, code FROM legal.jurisdictions ORDER BY name")
            .all()

        return try results.map { row in
            let name = try row.decode(column: "name", as: String.self)
            let code = try row.decode(column: "code", as: String.self)
            return ["name": name, "code": code]
        }
    }

    /// Searches legal jurisdictions by name
    /// - Parameters:
    ///   - searchTerm: The search term to match against jurisdiction name
    ///   - limit: Maximum number of results to return (default 50)
    ///   - offset: Number of results to skip (default 0)
    /// - Returns: Array of jurisdictions matching the search
    public func searchJurisdictions(
        searchTerm: String = "",
        limit: Int = 50,
        offset: Int = 0
    ) async throws -> [LegalJurisdiction] {
        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedSearchTerm.isEmpty {
            return try await listJurisdictions(limit: limit, offset: offset)
        }

        return try await LegalJurisdiction.query(on: database)
            .filter(\.$name ~~ "%\(trimmedSearchTerm)%")
            .limit(limit)
            .offset(offset)
            .sort(\.$name, .ascending)
            .all()
    }

    /// Counts total jurisdictions matching search criteria
    /// - Parameter searchTerm: The search term to match against jurisdiction name
    /// - Returns: Total count of jurisdictions matching the criteria
    public func countJurisdictions(searchTerm: String = "") async throws -> Int {
        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedSearchTerm.isEmpty {
            return try await LegalJurisdiction.query(on: database).count()
        }

        return try await LegalJurisdiction.query(on: database)
            .filter(\.$name ~~ "%\(trimmedSearchTerm)%")
            .count()
    }
}
