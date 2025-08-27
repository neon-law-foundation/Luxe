import ArgumentParser
import Foundation
import Logging
import Security

@main
struct RouletteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "roulette",
        abstract: "Random code refactoring tool to combat agentic coding effects",
        discussion: """
            Selects random Swift files from git history and provides refactoring suggestions
            to improve code quality after rapid development cycles.
            """
    )

    @Option(name: .shortAndLong, help: "Number of files to select")
    var count: Int = 3

    @Flag(name: .long, help: "Exclude test files from selection")
    var excludeTests: Bool = false

    @Flag(name: .long, help: "Enable verbose logging")
    var verbose: Bool = false

    func run() throws {
        LoggingSystem.bootstrap(StreamLogHandler.standardOutput)
        let logger = Logger(label: "roulette")

        logger.info(
            "Starting Roulette code quality analysis",
            metadata: [
                "fileCount": .stringConvertible(count),
                "excludeTests": .stringConvertible(excludeTests),
            ]
        )

        let selector = FileSelector(logger: logger)
        let analyzer = CodeAnalyzer(logger: logger)

        do {
            let files = try selector.selectRandomFiles(
                count: count,
                excludeTests: excludeTests
            )

            for file in files {
                let analysis = try analyzer.analyze(file: file)
                print(analysis.formatted())
            }
        } catch {
            logger.error("Roulette analysis failed", metadata: ["error": .string(String(describing: error))])
            throw ExitCode.failure
        }
    }
}

enum RouletteError: Error, LocalizedError {
    case gitCommandFailed(String)
    case noSwiftFiles
    case analysisError(String)

    var errorDescription: String? {
        switch self {
        case .gitCommandFailed(let command):
            return "Git command failed: \(command)"
        case .noSwiftFiles:
            return "No Swift files found in repository"
        case .analysisError(let message):
            return "Code analysis error: \(message)"
        }
    }
}

// File selection service with git integration and secure randomization
struct FileSelector {
    let logger: Logger
    private let gitDiscovery: GitFileDiscovery
    private let duplicateStore: DuplicatePreventionStore

    init(logger: Logger) {
        self.logger = logger
        self.gitDiscovery = GitFileDiscovery(logger: logger)
        self.duplicateStore = DuplicatePreventionStore(logger: logger)
    }

    func selectRandomFiles(count: Int, excludeTests: Bool) throws -> [String] {
        logger.info(
            "Starting file selection",
            metadata: [
                "requestedCount": .stringConvertible(count),
                "excludeTests": .stringConvertible(excludeTests),
            ]
        )

        // Discover all available Swift files
        let discoveredFiles = try gitDiscovery.discoverSwiftFiles(excludeTests: excludeTests)

        // Filter out recently selected files to prevent duplicates
        let availableFiles = try duplicateStore.filterRecentlySelected(discoveredFiles)

        guard !availableFiles.isEmpty else {
            // If all files were recently selected, fall back to original list
            logger.warning("All files were recently selected, ignoring duplicate prevention")
            let fallbackFiles = discoveredFiles

            guard !fallbackFiles.isEmpty else {
                throw RouletteError.noSwiftFiles
            }

            return try performSelection(from: fallbackFiles, count: count, recordSelection: true)
        }

        // Perform selection on filtered files
        let selectedFiles = try performSelection(from: availableFiles, count: count, recordSelection: true)

        logger.info(
            "File selection complete",
            metadata: [
                "selectedCount": .stringConvertible(selectedFiles.count),
                "files": .array(selectedFiles.map { .string($0) }),
            ]
        )

        return selectedFiles
    }

    /// Performs the actual file selection with optional recording
    private func performSelection(from availableFiles: [String], count: Int, recordSelection: Bool) throws -> [String] {
        // If we have fewer files than requested, return all
        let actualCount = min(count, availableFiles.count)
        logger.debug(
            "Selecting files",
            metadata: [
                "availableFiles": .stringConvertible(availableFiles.count),
                "actualCount": .stringConvertible(actualCount),
            ]
        )

        // Get file info for weighted selection
        let fileInfos: [FileInfo]
        do {
            fileInfos = try availableFiles.map { try gitDiscovery.getFileInfo($0) }
        } catch {
            logger.warning(
                "Failed to get file weights, using uniform selection",
                metadata: [
                    "error": .string(String(describing: error))
                ]
            )
            // Fallback to uniform selection if weight calculation fails
            var rng = SecureRandomNumberGenerator()
            let selectedFiles = Array(availableFiles.shuffled(using: &rng).prefix(actualCount))

            // Record selection if requested
            if recordSelection {
                try duplicateStore.recordSelection(selectedFiles)
            }

            return selectedFiles
        }

        // Perform weighted selection
        let selectedFiles = performWeightedSelection(from: fileInfos, count: actualCount)

        // Record selection if requested
        if recordSelection {
            try duplicateStore.recordSelection(selectedFiles)
        }

        return selectedFiles
    }

    /// Performs weighted random selection based on file age and size
    private func performWeightedSelection(from fileInfos: [FileInfo], count: Int) -> [String] {
        logger.debug(
            "Performing weighted selection",
            metadata: [
                "totalFiles": .stringConvertible(fileInfos.count),
                "requestedCount": .stringConvertible(count),
            ]
        )

        // Calculate total weight
        let totalWeight = fileInfos.reduce(0.0) { $0 + $1.selectionWeight }
        guard totalWeight > 0 else {
            // Fallback to uniform if weights are zero
            var rng = SecureRandomNumberGenerator()
            return Array(fileInfos.map(\.path).shuffled(using: &rng).prefix(count))
        }

        var selectedFiles: [String] = []
        var availableInfos = fileInfos
        var rng = SecureRandomNumberGenerator()

        // Select files using weighted sampling without replacement
        for _ in 0..<count {
            guard !availableInfos.isEmpty else { break }

            // Calculate current total weight
            let currentTotalWeight = availableInfos.reduce(0.0) { $0 + $1.selectionWeight }

            // Generate random value between 0 and total weight
            let randomValue = Double.random(in: 0..<currentTotalWeight, using: &rng)

            // Find the selected file using cumulative weights
            var cumulativeWeight = 0.0
            for (index, fileInfo) in availableInfos.enumerated() {
                cumulativeWeight += fileInfo.selectionWeight
                if randomValue < cumulativeWeight {
                    selectedFiles.append(fileInfo.path)
                    availableInfos.remove(at: index)

                    logger.debug(
                        "Selected file",
                        metadata: [
                            "file": .string(fileInfo.path),
                            "weight": .stringConvertible(fileInfo.selectionWeight),
                            "ageInDays": .stringConvertible(fileInfo.ageInDays),
                            "sizeKB": .stringConvertible(Double(fileInfo.size) / 1024.0),
                        ]
                    )
                    break
                }
            }
        }

        return selectedFiles
    }
}

/// Cryptographically secure random number generator for fair file selection
public struct SecureRandomNumberGenerator: RandomNumberGenerator {
    public func next() -> UInt64 {
        var randomBytes = Data(count: 8)
        let result = randomBytes.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 8, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }

        guard result == errSecSuccess else {
            // Fallback to system random if SecRandomCopyBytes fails
            return UInt64.random(in: UInt64.min...UInt64.max)
        }

        return randomBytes.withUnsafeBytes { bytes in
            bytes.bindMemory(to: UInt64.self)[0]
        }
    }
}

struct CodeAnalyzer {
    let logger: Logger

    func analyze(file: String) throws -> CodeMetrics {
        logger.info("Code analysis not yet implemented - returning placeholder")
        return CodeMetrics(
            filePath: file,
            lineCount: 0,
            functionCount: 0,
            typeCount: 0,
            complexity: 0,
            maintainabilityIndex: 100.0,
            suggestions: []
        )
    }
}

struct CodeMetrics {
    let filePath: String
    let lineCount: Int
    let functionCount: Int
    let typeCount: Int
    let complexity: Int
    let maintainabilityIndex: Double
    let suggestions: [RefactoringSuggestion]

    func formatted() -> String {
        """
        📊 Code Analysis: \(filePath)
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        📈 Metrics:
        • Lines of Code: \(lineCount)
        • Functions: \(functionCount)
        • Types: \(typeCount)
        • Complexity: \(complexity)
        • Maintainability Index: \(String(format: "%.1f", maintainabilityIndex))/100

        ✅ Phase 1: Basic CLI structure ready for implementation

        """
    }
}

struct RefactoringSuggestion {
    let type: SuggestionType
    let description: String
    let severity: Severity
    let lineRange: ClosedRange<Int>?

    enum SuggestionType: String, CaseIterable {
        case extractFunction = "Extract Function"
        case reduceComplexity = "Reduce Complexity"
        case improveNaming = "Improve Naming"
        case addDocumentation = "Add Documentation"
        case splitClass = "Split Type"
        case removeDeadCode = "Remove Dead Code"
    }

    enum Severity: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"
    }
}
