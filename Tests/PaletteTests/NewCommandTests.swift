import Foundation
import Testing

@testable import Palette

@Suite struct PaletteNewMigrationTests {
    @Test("Creating a new migration")
    func creatingNewMigrationWorksCorrectly() async throws {
        // Get current date for comparison
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmm"
        let expectedTimestamp = dateFormatter.string(from: Date())

        // Create a test migration
        let testName = "test_migration"
        var command = NewCommand()
        command.name = testName

        // Run the command
        try await command.run()

        // Construct the expected filename
        let expectedFilename = "\(expectedTimestamp)_\(testName).sql"
        let migrationsDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources")
            .appendingPathComponent("Palette")
            .appendingPathComponent("Migrations")
        let fileURL = migrationsDir.appendingPathComponent(expectedFilename)

        // Verify the file exists and contains the expected content
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        // Clean up - delete the test file
        try FileManager.default.removeItem(at: fileURL)
    }
}
