import ArgumentParser
import Foundation

@main
struct Wayne: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Generate standalone Xcode projects for macOS/iOS targets from Swift Package Manager",
        discussion: """
            Wayne creates standalone Xcode projects for individual targets from your Swift Package Manager project.
            This allows you to open and build specific macOS or iOS targets in Xcode without the complexity
            of the entire monorepo.

            Generated projects are placed in your Downloads folder and configured to reference the original
            source files, so changes made in Xcode will be reflected in your main project.
            """
    )

    @Argument(help: "The name of the target to generate an Xcode project for")
    var targetName: String?

    @Flag(name: .long, help: "List all available macOS/iOS targets")
    var list: Bool = false

    @Option(name: .long, help: "Output directory for the generated project")
    var outputDirectory: String?

    func run() throws {
        let parser = PackageParser()
        let targets = try parser.parsePackageFile()

        if list {
            listTargets(targets)
            return
        }

        guard let targetName = targetName else {
            print("Error: Target name is required. Use --list to see available targets.")
            throw ExitCode.failure
        }

        guard let target = targets.first(where: { $0.name == targetName }) else {
            print("Error: Target '\(targetName)' not found.")
            print("Available targets:")
            for target in targets {
                print("  - \(target.name)")
            }
            throw ExitCode.failure
        }

        let outputDir = outputDirectory ?? defaultOutputDirectory()
        let generator = XcodeProjectGenerator()

        do {
            let projectPath = try generator.generateProject(for: target, in: outputDir)
            print("✅ Generated Xcode project: \(projectPath)")
            print("📁 Open with: open \(projectPath)")

            // Optionally open the project automatically
            if ProcessInfo.processInfo.environment["WAYNE_AUTO_OPEN"] == "true" {
                let task = Process()
                task.launchPath = "/usr/bin/open"
                task.arguments = [projectPath]
                task.launch()
                task.waitUntilExit()
            }
        } catch {
            print("❌ Failed to generate project: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }

    private func listTargets(_ targets: [TargetInfo]) {
        print("Available macOS/iOS targets:")
        print("============================")

        if targets.isEmpty {
            print("No executable targets found.")
            return
        }

        for target in targets.sorted(by: { $0.name < $1.name }) {
            print("📱 \(target.name)")
            if !target.dependencies.isEmpty {
                print("   Dependencies: \(target.dependencies.joined(separator: ", "))")
            }
            if !target.sourceFiles.isEmpty {
                print("   Source files: \(target.sourceFiles.count)")
            }
            print("")
        }

        print("Usage: swift run Wayne <target-name>")
        print("Example: swift run Wayne Concierge")
    }

    private func defaultOutputDirectory() -> String {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent("Downloads").path
    }
}
