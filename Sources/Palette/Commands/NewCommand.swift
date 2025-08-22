import ArgumentParser
import Foundation

struct NewCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "new",
        abstract: "Create a new migration file"
    )

    @Argument(help: "Name of the migration")
    var name: String

    func run() async throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmm"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "\(timestamp)_\(name).sql"

        // Get the project root directory
        let currentDirectory = FileManager.default.currentDirectoryPath
        let migrationsDir = URL(fileURLWithPath: currentDirectory)
            .appendingPathComponent("Sources")
            .appendingPathComponent("Palette")
            .appendingPathComponent("Migrations")

        try FileManager.default.createDirectory(at: migrationsDir, withIntermediateDirectories: true)

        let fileURL = migrationsDir.appendingPathComponent(filename)
        try "".write(to: fileURL, atomically: true, encoding: .utf8)

        print("Created migration file: \(filename)")
    }
}
