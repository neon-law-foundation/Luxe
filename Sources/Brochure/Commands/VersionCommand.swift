import ArgumentParser
import Foundation

/// Command to display version information for the Brochure CLI.
///
/// Provides comprehensive version details including semantic version,
/// git metadata, build information, and platform details.
struct VersionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Display version information for Brochure CLI",
        discussion: """
            Shows detailed version information including:

            • Semantic version number (major.minor.patch)
            • Git commit hash and branch information
            • Build date and platform details
            • Swift compiler version and build configuration

            EXAMPLES:
              # Show standard version information
              swift run Brochure version

              # Show detailed version with build info
              swift run Brochure version --detailed

              # Show only the version number (useful for scripts)
              swift run Brochure version --short
            """
    )

    @Flag(name: .shortAndLong, help: "Show detailed build information")
    var detailed: Bool = false

    @Flag(name: .shortAndLong, help: "Show only the version number")
    var short: Bool = false

    @Flag(name: .long, help: "Output version information in JSON format")
    var json: Bool = false

    func run() throws {
        let version = currentVersion

        if json {
            // Output as JSON for programmatic use
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(version)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print(jsonString)
            }
        } else if short {
            // Just the version number for scripts
            print(version.shortVersion)
        } else if detailed {
            // Comprehensive version information
            print(version.cliOutput)
            print("")
            print("Detailed Build Information:")
            print("  Version: \(version.fullVersion)")
            print("  Git Commit: \(version.gitCommit)")
            if let gitBranch = version.gitBranch {
                print("  Git Branch: \(gitBranch)")
            }
            print("  Git Dirty: \(version.gitDirty ? "Yes" : "No")")
            print("  Build Date: \(version.buildDate)")
            print("  Build Timestamp: \(version.buildTimestamp)")
            print("  Platform: \(version.platform)")
            print("  Architecture: \(version.architecture)")
            print("  Build Configuration: \(version.buildConfiguration)")
            if let swiftVersion = version.swiftVersion {
                print("  Swift Version: \(swiftVersion)")
            }
            if let compiler = version.compiler {
                print("  Compiler: \(compiler)")
            }
        } else {
            // Standard version output
            print(version.cliOutput)
        }
    }
}
