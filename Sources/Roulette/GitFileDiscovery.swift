import Foundation
import Logging

/// Service for discovering Swift files in a Git repository using git commands
public struct GitFileDiscovery {
    private let logger: Logger

    public init(logger: Logger) {
        self.logger = logger
    }

    /// Discovers all Swift files tracked by git in the repository
    /// - Parameter excludeTests: Whether to exclude test files from the results
    /// - Returns: Array of file paths relative to repository root
    /// - Throws: RouletteError.gitCommandFailed if git commands fail
    public func discoverSwiftFiles(excludeTests: Bool = false) throws -> [String] {
        logger.debug("Starting Swift file discovery", metadata: ["excludeTests": .stringConvertible(excludeTests)])

        // First, verify we're in a git repository
        try verifyGitRepository()

        // Get all tracked Swift files
        let allFiles = try executeGitCommand(arguments: ["ls-files", "*.swift"])
        logger.debug("Found Swift files", metadata: ["count": .stringConvertible(allFiles.count)])

        // Apply filtering
        let filteredFiles = filterFiles(allFiles, excludeTests: excludeTests)

        guard !filteredFiles.isEmpty else {
            logger.error("No Swift files found after filtering")
            throw RouletteError.noSwiftFiles
        }

        logger.info(
            "Swift file discovery complete",
            metadata: [
                "totalFiles": .stringConvertible(allFiles.count),
                "filteredFiles": .stringConvertible(filteredFiles.count),
                "excludeTests": .stringConvertible(excludeTests),
            ]
        )

        return filteredFiles
    }

    /// Gets file modification info for weighting purposes
    /// - Parameter filePath: Path to the file relative to repository root
    /// - Returns: FileInfo with size and modification data
    /// - Throws: RouletteError.gitCommandFailed if git or file operations fail
    public func getFileInfo(_ filePath: String) throws -> FileInfo {
        logger.debug("Getting file info", metadata: ["file": .string(filePath)])

        // Get file size using FileManager
        let fileURL = URL(fileURLWithPath: filePath)
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        // Get last modification date from git log
        let lastModifiedOutput = try executeGitCommand(arguments: [
            "log", "-1", "--format=%ct", "--", filePath,
        ])

        let lastModified: Date
        if let timestamp = lastModifiedOutput.first, let timeInterval = TimeInterval(timestamp) {
            lastModified = Date(timeIntervalSince1970: timeInterval)
        } else {
            // Fallback to file system modification date
            lastModified = attributes[.modificationDate] as? Date ?? Date()
            logger.debug("Using filesystem date as fallback", metadata: ["file": .string(filePath)])
        }

        return FileInfo(
            path: filePath,
            size: fileSize,
            lastModified: lastModified
        )
    }

    // MARK: - Private Methods

    /// Verifies that the current directory is a git repository
    private func verifyGitRepository() throws {
        logger.debug("Verifying git repository status")

        do {
            _ = try executeGitCommand(arguments: ["rev-parse", "--git-dir"])
            logger.debug("Git repository verified")
        } catch {
            logger.error("Not in a git repository")
            throw RouletteError.gitCommandFailed("git rev-parse --git-dir")
        }
    }

    /// Executes a git command with the given arguments
    /// - Parameter arguments: Command line arguments for git
    /// - Returns: Array of non-empty output lines
    /// - Throws: RouletteError.gitCommandFailed if the command fails
    private func executeGitCommand(arguments: [String]) throws -> [String] {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        logger.debug("Executing git command", metadata: ["args": .array(arguments.map { .string($0) })])

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            logger.error(
                "Failed to execute git command",
                metadata: [
                    "args": .array(arguments.map { .string($0) }),
                    "error": .string(String(describing: error)),
                ]
            )
            throw RouletteError.gitCommandFailed("git \(arguments.joined(separator: " "))")
        }

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"

            logger.error(
                "Git command failed",
                metadata: [
                    "args": .array(arguments.map { .string($0) }),
                    "exitCode": .stringConvertible(process.terminationStatus),
                    "stderr": .string(errorOutput),
                ]
            )

            throw RouletteError.gitCommandFailed("git \(arguments.joined(separator: " ")): \(errorOutput)")
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        let lines = output.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        logger.debug(
            "Git command completed",
            metadata: [
                "args": .array(arguments.map { .string($0) }),
                "outputLines": .stringConvertible(lines.count),
            ]
        )

        return lines
    }

    /// Filters the list of Swift files based on exclusion patterns
    /// - Parameters:
    ///   - files: Array of file paths to filter
    ///   - excludeTests: Whether to exclude test files
    /// - Returns: Filtered array of file paths
    private func filterFiles(_ files: [String], excludeTests: Bool) -> [String] {
        var filtered = files

        // Always exclude generated files and common non-source patterns
        let exclusionPatterns = [
            ".build/",  // Swift Package Manager build directory
            "Package.swift",  // Package manifests
            ".generated.",  // Generated files
            "Generated/",  // Generated directories
            "Derived/",  // Xcode derived data
            "/.build/",  // Hidden build directories
        ]

        // Add test exclusions if requested
        var testPatterns: [String] = []
        if excludeTests {
            testPatterns = [
                "Tests/",  // Swift Package Manager test directories
                "Test.swift",  // Files ending with Test.swift
                "Tests.swift",  // Files ending with Tests.swift
                "Spec.swift",  // Spec files
                "Mock.swift",  // Mock files
                "Stub.swift",  // Stub files
                "TestCase.swift",  // TestCase files
            ]
        }

        let allPatterns = exclusionPatterns + testPatterns

        for pattern in allPatterns {
            let beforeCount = filtered.count
            filtered = filtered.filter { filePath in
                if pattern.hasSuffix("/") {
                    // Directory pattern - check if path contains directory
                    return !filePath.contains(pattern)
                } else {
                    // File pattern - check if filename contains pattern
                    return !filePath.contains(pattern)
                }
            }

            let filteredCount = beforeCount - filtered.count
            if filteredCount > 0 {
                logger.debug(
                    "Filtered files",
                    metadata: [
                        "pattern": .string(pattern),
                        "filtered": .stringConvertible(filteredCount),
                    ]
                )
            }
        }

        return filtered
    }
}

/// Information about a file for weighting and selection purposes
public struct FileInfo {
    /// Path to the file relative to repository root
    public let path: String

    /// Size of the file in bytes
    public let size: Int64

    /// Last modification date from git history
    public let lastModified: Date

    /// Age of the file in days from current date
    public var ageInDays: Double {
        Date().timeIntervalSince(lastModified) / (24 * 60 * 60)
    }

    /// Weight factor for random selection based on age and size
    /// Newer and larger files get higher weight (more likely to be selected)
    public var selectionWeight: Double {
        let sizeWeight = max(1.0, log10(Double(max(size, 1))))  // Logarithmic size scaling
        let ageWeight = max(0.1, 1.0 / (1.0 + ageInDays / 30.0))  // Decay over ~30 days
        return sizeWeight * ageWeight
    }
}
