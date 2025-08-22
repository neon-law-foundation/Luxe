import Foundation
import Testing

@testable import Palette

@Suite("Schema extraction and search path configuration", .serialized)
struct SchemaExtractionTests {

    @Test("Extract all schemas from migration files")
    func extractSchemasFromMigrations() async throws {
        let migrationsDir = URL(fileURLWithPath: "Sources/Palette/Migrations")
        let migrationFiles = try FileManager.default.contentsOfDirectory(
            at: migrationsDir,
            includingPropertiesForKeys: nil
        )
        .filter { $0.pathExtension == "sql" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var extractedSchemas = Set<String>()

        for file in migrationFiles {
            let content = try String(contentsOf: file, encoding: .utf8)
            let schemas = extractSchemasFromSQL(content)
            extractedSchemas.formUnion(schemas)
        }

        // Expected schemas based on migration analysis
        let expectedSchemas: Set<String> = [
            "auth", "directory", "mail", "accounting", "equity", "estates",
            "standards", "legal", "matters", "documents", "service", "admin", "ethereal", "marketing",
        ]

        #expect(extractedSchemas == expectedSchemas, "All schemas should be extracted from migrations")
    }

    @Test("Generate canonical search path")
    func generateCanonicalSearchPath() async throws {
        let schemas = getCanonicalSchemas()
        let searchPath = schemas.joined(separator: ",")

        // Expected search path order: business schemas first, then public
        let expectedSearchPath =
            "auth,directory,mail,accounting,equity,estates,standards,legal,matters,documents,service,admin,ethereal,public"

        #expect(searchPath == expectedSearchPath, "Search path should be in canonical order")
    }

    @Test("Search path contains all required schemas")
    func searchPathContainsAllSchemas() async throws {
        let schemas = getCanonicalSchemas()

        // Verify all expected schemas are present
        let requiredSchemas = [
            "auth", "directory", "mail", "accounting", "equity", "estates",
            "standards", "legal", "matters", "documents", "service", "admin", "ethereal", "public",
        ]

        for schema in requiredSchemas {
            #expect(schemas.contains(schema), "Schema '\(schema)' should be in canonical search path")
        }

        #expect(schemas.count == requiredSchemas.count, "Should have exactly \(requiredSchemas.count) schemas")
    }
}

// Helper functions to extract schemas from SQL content
func extractSchemasFromSQL(_ content: String) -> Set<String> {
    var schemas = Set<String>()
    let lines = content.components(separatedBy: .newlines)

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Look for CREATE SCHEMA statements
        if trimmed.uppercased().contains("CREATE SCHEMA") {
            // Extract schema name from CREATE SCHEMA IF NOT EXISTS schema_name
            let components = trimmed.components(separatedBy: .whitespaces)
            if let schemaIndex = components.firstIndex(where: { $0.uppercased() == "SCHEMA" }) {
                let nextIndex = schemaIndex + 1
                if nextIndex < components.count {
                    var schemaName = components[nextIndex]
                    // Handle "IF NOT EXISTS schema_name" case
                    if schemaName.uppercased() == "IF" && nextIndex + 3 < components.count {
                        schemaName = components[nextIndex + 3]
                    }
                    // Clean up schema name (remove semicolons, quotes, etc.)
                    schemaName = schemaName.replacingOccurrences(of: ";", with: "")
                        .replacingOccurrences(of: "'", with: "")
                        .replacingOccurrences(of: "\"", with: "")
                    schemas.insert(schemaName)
                }
            }
        }
    }

    return schemas
}

// Get canonical list of schemas in proper order
func getCanonicalSchemas() -> [String] {
    [
        "auth", "directory", "mail", "accounting", "equity", "estates",
        "standards", "legal", "matters", "documents", "service", "admin", "ethereal", "public",
    ]
}
