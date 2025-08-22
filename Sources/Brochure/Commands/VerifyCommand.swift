import ArgumentParser
import Foundation
import Logging

/// Command to verify binary integrity using SHA256 checksums.
///
/// Provides comprehensive binary verification capabilities including local checksum
/// verification, remote checksum validation, and download-and-verify operations.
struct VerifyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "verify",
        abstract: "Verify binary integrity using SHA256 checksums",
        discussion: """
            Verify the integrity of Brochure CLI binaries or other files using SHA256 checksums.
            Supports verification against local checksum files or remote checksum URLs.

            VERIFICATION METHODS:

            • Local Verification: Compare a file against a local checksum file
            • Remote Verification: Download and compare against a remote checksum
            • Download & Verify: Download a binary and verify its integrity in one operation
            • Batch Verification: Verify multiple files simultaneously

            EXAMPLES:

              # Verify current binary against local checksum
              swift run Brochure verify --binary /usr/local/bin/brochure --checksum /tmp/brochure.sha256

              # Verify against remote checksum
              swift run Brochure verify --binary /usr/local/bin/brochure --remote-checksum https://cli.neonlaw.com/brochure/latest/darwin-arm64/brochure.sha256

              # Download and verify in one operation
              swift run Brochure verify --download https://cli.neonlaw.com/brochure/latest/darwin-arm64/brochure --checksum-url https://cli.neonlaw.com/brochure/latest/darwin-arm64/brochure.sha256 --output /tmp/brochure

              # Verify self (current binary)
              swift run Brochure verify --self

              # Verify with JSON output for scripting
              swift run Brochure verify --binary /usr/local/bin/brochure --checksum /tmp/brochure.sha256 --json

            EXIT CODES:
              0 - Verification successful
              1 - Verification failed
              2 - Error (file not found, network error, etc.)
            """,
        subcommands: []
    )

    @Option(name: .shortAndLong, help: "Path to binary file to verify")
    var binary: String?

    @Option(name: .shortAndLong, help: "Path to local checksum file")
    var checksum: String?

    @Option(name: .long, help: "URL to remote checksum file")
    var remoteChecksum: String?

    @Option(name: .long, help: "URL to download binary from")
    var download: String?

    @Option(name: .long, help: "URL to download checksum from (used with --download)")
    var checksumUrl: String?

    @Option(name: .shortAndLong, help: "Output path for downloaded binary")
    var output: String?

    @Flag(name: .long, help: "Verify the currently running binary")
    var `self`: Bool = false

    @Flag(name: .long, help: "Output results in JSON format")
    var json: Bool = false

    @Flag(name: .shortAndLong, help: "Enable verbose output")
    var verbose: Bool = false

    @Flag(name: .shortAndLong, help: "Quiet mode - minimal output")
    var quiet: Bool = false

    func run() async throws {
        var logger = Logger(label: "VerifyCommand")
        logger.logLevel = quiet ? .error : (verbose ? .debug : .info)

        let checker = IntegrityChecker(logger: logger)

        do {
            let result: VerificationResult

            if self.`self` {
                // Verify the currently running binary
                result = try await verifySelf(checker: checker, logger: logger)

            } else if let downloadURL = download {
                // Download and verify
                guard let checksumURL = checksumUrl else {
                    throw CleanExit.message("--checksum-url is required when using --download")
                }

                guard let outputPath = output else {
                    throw CleanExit.message("--output is required when using --download")
                }

                result = try await checker.downloadAndVerify(
                    downloadURL: downloadURL,
                    checksumURL: checksumURL,
                    destinationPath: outputPath
                )

            } else if let binaryPath = binary {
                // Verify existing binary
                if let checksumPath = checksum {
                    // Local verification
                    result = try await checker.verifyFile(
                        binaryPath: binaryPath,
                        checksumPath: checksumPath
                    )

                } else if let checksumURL = remoteChecksum {
                    // Remote verification
                    result = try await checker.verifyFileAgainstRemoteChecksum(
                        binaryPath: binaryPath,
                        checksumURL: checksumURL
                    )

                } else {
                    throw CleanExit.message("Either --checksum or --remote-checksum is required when using --binary")
                }

            } else {
                throw CleanExit.message("Specify --binary, --download, or --self for verification")
            }

            // Output results
            if json {
                try outputJSON(result: result)
            } else {
                outputHuman(result: result, logger: logger)
            }

            // Set exit code based on verification result
            if !result.isValid {
                throw ExitCode(1)
            }

        } catch let error as IntegrityError {
            if json {
                try outputErrorJSON(error: error)
            } else {
                logger.error("❌ Verification error: \(error.localizedDescription)")
                if let suggestion = error.recoverySuggestion {
                    logger.info("💡 \(suggestion)")
                }
            }
            throw ExitCode(2)

        } catch {
            if json {
                try outputErrorJSON(error: error)
            } else {
                logger.error("❌ Unexpected error: \(error.localizedDescription)")
            }
            throw ExitCode(2)
        }
    }

    private func verifySelf(checker: IntegrityChecker, logger: Logger) async throws -> VerificationResult {
        // Get the path to the currently running binary
        let executablePath = ProcessInfo.processInfo.arguments[0]
        let resolvedPath = URL(fileURLWithPath: executablePath).resolvingSymlinksInPath().path

        logger.info("Verifying self: \(resolvedPath)")

        // Try to determine platform for remote checksum
        let platform = detectPlatform()
        let architecture = detectArchitecture()
        let platformArch = "\(platform)-\(architecture)"

        // Try to get version info to construct remote checksum URL
        let version = currentVersion
        let isLatest = version.version.contains("dev") || version.version.contains("unknown")
        let versionPath = isLatest ? "latest" : version.version

        let checksumURL = "https://cli.neonlaw.com/brochure/\(versionPath)/\(platformArch)/brochure.sha256"

        logger.info("Using remote checksum: \(checksumURL)")

        return try await checker.verifyFileAgainstRemoteChecksum(
            binaryPath: resolvedPath,
            checksumURL: checksumURL
        )
    }

    private func detectPlatform() -> String {
        #if os(macOS)
        return "darwin"
        #elseif os(Linux)
        return "linux"
        #else
        return "unknown"
        #endif
    }

    private func detectArchitecture() -> String {
        let architectures = [
            "arm64": "arm64",
            "aarch64": "arm64",
            "x86_64": "x64",
            "amd64": "x64",
        ]

        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x64"
        #else
        // Fallback to runtime detection
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        let platform = String(cString: machine)

        return architectures[platform] ?? "unknown"
        #endif
    }

    private func outputHuman(result: VerificationResult, logger: Logger) {
        if !quiet {
            logger.info("📁 Binary: \(result.binaryPath)")
            logger.info("🔍 Method: \(result.verificationMethod.description)")
            logger.info("📅 Verified: \(formatDate(result.verificationTime))")

            if verbose {
                logger.info("🔢 Expected: \(result.expectedChecksum)")
                logger.info("🔢 Actual:   \(result.actualChecksum)")
            }
        }

        if result.isValid {
            logger.info("✅ Binary integrity verified successfully")
        } else {
            logger.error("❌ Binary integrity verification failed")
            if let errorMessage = result.errorMessage {
                logger.error("   Error: \(errorMessage)")
            }
            logger.warning("   Expected: \(result.expectedChecksum)")
            logger.warning("   Actual:   \(result.actualChecksum)")
        }
    }

    private func outputJSON(result: VerificationResult) throws {
        let jsonResult = JSONVerificationResult(from: result)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonData = try encoder.encode(jsonResult)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }

    private func outputErrorJSON(error: Error) throws {
        let errorResult = JSONErrorResult(
            success: false,
            error: error.localizedDescription,
            errorType: String(describing: type(of: error))
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonData = try encoder.encode(errorResult)
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print(jsonString)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - JSON Output Structures

private struct JSONVerificationResult: Codable {
    let success: Bool
    let binaryPath: String
    let expectedChecksum: String
    let actualChecksum: String
    let verificationMethod: String
    let verificationTime: String
    let errorMessage: String?

    init(from result: VerificationResult) {
        self.success = result.isValid
        self.binaryPath = result.binaryPath
        self.expectedChecksum = result.expectedChecksum
        self.actualChecksum = result.actualChecksum
        self.verificationMethod = result.verificationMethod.description

        let formatter = ISO8601DateFormatter()
        self.verificationTime = formatter.string(from: result.verificationTime)

        self.errorMessage = result.errorMessage
    }
}

private struct JSONErrorResult: Codable {
    let success: Bool
    let error: String
    let errorType: String
}
