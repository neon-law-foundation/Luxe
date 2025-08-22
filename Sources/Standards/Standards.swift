import ArgumentParser
import Foundation
import Logging

#if canImport(Darwin)
import Darwin.C
#elseif canImport(Glibc)
import Glibc
#endif

@main
struct Standards: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Validate Sagebrush Standards compliance in markdown files",
        discussion: """
            The Standards CLI validates that markdown files in the Sagebrush ecosystem
            contain proper YAML frontmatter with required fields. It recursively
            searches directories for .md files (excluding README.md and CLAUDE.md)
            and validates their structure.

            REQUIRED YAML FRONTMATTER FIELDS:
            • code: Unique identifier for the standard (e.g., "CORP001", "IND001")
            • title: Human-readable title describing the standard
            • respondant_type: Target audience - "individual", "organization", or "both"

            OPTIONAL YAML FRONTMATTER FIELDS:
            • version: Standard version (e.g., "1.0.0")
            • effective_date: When the standard takes effect (e.g., "2024-01-01")
            • tags: Array of categorization tags (e.g., ["legal", "corporate"])

            USAGE EXAMPLES:
            Validate all standards in the current directory:
              standards validate

            Validate a specific standards directory:
              standards validate ~/sagebrush/standards

            Validate with detailed output showing all files:
              standards validate ~/sagebrush/standards --verbose

            Validate without colored output (for CI/scripts):
              standards validate ~/sagebrush/standards --no-color

            EXAMPLE VALID STANDARD:
            ---
            code: CORP001
            title: "Corporate Formation Standard"
            respondant_type: organization
            version: "1.0.0"
            effective_date: "2024-01-01"
            ---

            Standard content goes here...

            For more examples, see: https://sagebrush.services/standards/examples
            """,
        version: "1.0.0",
        subcommands: [Validate.self]
    )
}

extension Standards {
    struct Validate: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Validate standards files in a directory"
        )

        @Argument(help: "Path to directory containing standards files")
        var path: String = "."

        @Flag(name: .shortAndLong, help: "Show verbose output")
        var verbose: Bool = false

        @Flag(name: .long, help: "Disable colored output")
        var noColor: Bool = false

        func run() throws {
            var logger = Logger(label: "standards.validate")
            logger.logLevel = verbose ? .debug : .info

            logger.info(
                "Starting standards validation",
                metadata: [
                    "path": .string(path)
                ]
            )

            let validator = StandardsValidator()
            let result = validator.validateDirectory(path: path)

            // Use OutputFormatter for clean, colored output
            let formatter = OutputFormatter()
            let useColors = !noColor && isatty(STDOUT_FILENO) == 1
            let formattedOutput = formatter.formatResult(result, useColors: useColors, verbose: verbose)

            print(formattedOutput)

            if !result.isValid {
                Foundation.exit(1)
            }
        }
    }
}
