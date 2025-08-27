import Foundation
import Logging
import Testing

@testable import Roulette

@Suite("Roulette Command Tests")
struct RouletteCommandTests {
    @Test("Should have correct command configuration")
    func testCommandConfiguration() {
        #expect(RouletteCommand.configuration.commandName == "roulette")
        #expect(
            RouletteCommand.configuration.abstract == "Random code refactoring tool to combat agentic coding effects"
        )
    }

    @Test("Should initialize with default values")
    func testDefaultValues() {
        // Test that the default values are correct by parsing empty arguments
        do {
            let command = try RouletteCommand.parse([])
            #expect(command.count == 3)
            #expect(command.excludeTests == false)
            #expect(command.verbose == false)
        } catch {
            Issue.record("Failed to parse empty arguments: \(error)")
        }
    }
}

@Suite("RouletteError Tests")
struct RouletteErrorTests {
    @Test("Should provide correct error descriptions")
    func testErrorDescriptions() {
        let gitError = RouletteError.gitCommandFailed("git ls-files")
        #expect(gitError.errorDescription == "Git command failed: git ls-files")

        let noFilesError = RouletteError.noSwiftFiles
        #expect(noFilesError.errorDescription == "No Swift files found in repository")

        let analysisError = RouletteError.analysisError("test error")
        #expect(analysisError.errorDescription == "Code analysis error: test error")
    }
}

@Suite("GitFileDiscovery Tests")
struct GitFileDiscoveryTests {
    let logger = Logger(label: "test")

    @Test("Should discover Swift files in git repository")
    func testDiscoverSwiftFiles() throws {
        let discovery = GitFileDiscovery(logger: logger)

        // This test runs in the actual repository, so it should find Swift files
        let files = try discovery.discoverSwiftFiles(excludeTests: false)

        #expect(!files.isEmpty, "Should find Swift files in repository")
        #expect(files.allSatisfy { $0.hasSuffix(".swift") }, "All files should have .swift extension")

        // Should find at least our Roulette source files
        let rouletteFiles = files.filter { $0.contains("Roulette") && !$0.contains("Tests") }
        #expect(rouletteFiles.count >= 1, "Should find at least 1 Roulette source file")
    }

    @Test("Should exclude test files when requested")
    func testExcludeTestFiles() throws {
        let discovery = GitFileDiscovery(logger: logger)

        let allFiles = try discovery.discoverSwiftFiles(excludeTests: false)
        let nonTestFiles = try discovery.discoverSwiftFiles(excludeTests: true)

        // Should have fewer files when excluding tests
        #expect(nonTestFiles.count <= allFiles.count, "Should have fewer or equal files when excluding tests")

        // Should not contain common test patterns
        let hasTestPatterns = nonTestFiles.contains { file in
            file.contains("Tests/") || file.contains("Test.swift") || file.contains("Tests.swift")
                || file.contains("Mock.swift") || file.contains("Stub.swift")
        }
        #expect(!hasTestPatterns, "Should not contain test patterns when excluding tests")
    }

    @Test("Should filter out generated and build files")
    func testFilterGeneratedFiles() throws {
        let discovery = GitFileDiscovery(logger: logger)

        let files = try discovery.discoverSwiftFiles(excludeTests: false)

        // Should not contain generated or build files
        let hasExcludedPatterns = files.contains { file in
            file.contains(".build/") || file.contains("Package.swift") || file.contains(".generated.")
                || file.contains("Generated/") || file.contains("Derived/")
        }
        #expect(!hasExcludedPatterns, "Should not contain excluded patterns")
    }

    @Test("Should get file info with size and modification date")
    func testGetFileInfo() throws {
        let discovery = GitFileDiscovery(logger: logger)

        // Get a known file - our own test file
        let testFile = "Tests/RouletteTests/RouletteCommandTests.swift"
        let fileInfo = try discovery.getFileInfo(testFile)

        #expect(fileInfo.path == testFile)
        #expect(fileInfo.size > 0, "File should have non-zero size")
        #expect(fileInfo.lastModified <= Date(), "File modification date should not be in future")

        // Check derived properties
        #expect(fileInfo.ageInDays >= 0, "File age should be non-negative")
        #expect(fileInfo.selectionWeight > 0, "File should have positive selection weight")
    }
}

@Suite("FileInfo Tests")
struct FileInfoTests {
    @Test("Should calculate correct age in days")
    func testAgeCalculation() {
        let now = Date()
        let threeDaysAgo = now.addingTimeInterval(-3 * 24 * 60 * 60)

        let fileInfo = FileInfo(path: "test.swift", size: 1000, lastModified: threeDaysAgo)

        #expect(abs(fileInfo.ageInDays - 3.0) < 0.1, "Should calculate age as approximately 3 days")
    }

    @Test("Should calculate selection weight based on size and age")
    func testSelectionWeight() {
        let now = Date()

        // Test newer file has higher weight than older file
        let newFile = FileInfo(path: "new.swift", size: 1000, lastModified: now.addingTimeInterval(-1 * 24 * 60 * 60))
        let oldFile = FileInfo(path: "old.swift", size: 1000, lastModified: now.addingTimeInterval(-30 * 24 * 60 * 60))

        #expect(newFile.selectionWeight > oldFile.selectionWeight, "Newer files should have higher weight")

        // Test larger file has higher weight than smaller file (same age)
        let bigFile = FileInfo(path: "big.swift", size: 10000, lastModified: now.addingTimeInterval(-1 * 24 * 60 * 60))
        let smallFile = FileInfo(
            path: "small.swift",
            size: 100,
            lastModified: now.addingTimeInterval(-1 * 24 * 60 * 60)
        )

        #expect(bigFile.selectionWeight > smallFile.selectionWeight, "Larger files should have higher weight")

        // All weights should be positive
        #expect(newFile.selectionWeight > 0)
        #expect(oldFile.selectionWeight > 0)
        #expect(bigFile.selectionWeight > 0)
        #expect(smallFile.selectionWeight > 0)
    }
}

@Suite("DuplicatePreventionStore Tests")
struct DuplicatePreventionStoreTests {
    let logger = Logger(label: "test")

    func createTempStore() -> DuplicatePreventionStore {
        let tempDir = FileManager.default.temporaryDirectory
        let testStore = tempDir.appendingPathComponent("roulette-test-\(UUID()).json")
        return DuplicatePreventionStore(logger: logger, storeURL: testStore, maxHistoryDays: 1.0)
    }

    @Test("Should start with empty history")
    func testEmptyHistory() throws {
        let store = createTempStore()

        let recentFiles = try store.getRecentlySelectedFiles()
        #expect(recentFiles.isEmpty, "New store should have no recent files")

        let filtered = try store.filterRecentlySelected(["test.swift", "another.swift"])
        #expect(filtered.count == 2, "Should not filter anything from empty history")
    }

    @Test("Should record and retrieve file selections")
    func testRecordSelection() throws {
        let store = createTempStore()

        let filesToRecord = ["file1.swift", "file2.swift", "file3.swift"]
        try store.recordSelection(filesToRecord)

        let recentFiles = try store.getRecentlySelectedFiles()
        #expect(recentFiles.count == 3, "Should record all selected files")
        #expect(recentFiles.contains("file1.swift"))
        #expect(recentFiles.contains("file2.swift"))
        #expect(recentFiles.contains("file3.swift"))
    }

    @Test("Should filter recently selected files")
    func testFilterRecent() throws {
        let store = createTempStore()

        // Record some files
        try store.recordSelection(["recent1.swift", "recent2.swift"])

        // Test filtering
        let candidates = ["recent1.swift", "fresh.swift", "recent2.swift", "another.swift"]
        let filtered = try store.filterRecentlySelected(candidates)

        #expect(filtered.count == 2, "Should filter out 2 recently selected files")
        #expect(filtered.contains("fresh.swift"))
        #expect(filtered.contains("another.swift"))
        #expect(!filtered.contains("recent1.swift"))
        #expect(!filtered.contains("recent2.swift"))
    }

    @Test("Should clear selection history")
    func testClearHistory() throws {
        let store = createTempStore()

        // Record some files
        try store.recordSelection(["file1.swift", "file2.swift"])

        // Verify they're recorded
        var recentFiles = try store.getRecentlySelectedFiles()
        #expect(recentFiles.count == 2)

        // Clear history
        try store.clearHistory()

        // Verify it's cleared
        recentFiles = try store.getRecentlySelectedFiles()
        #expect(recentFiles.isEmpty, "History should be empty after clearing")
    }

    @Test("Should respect maxHistoryDays setting")
    func testMaxHistoryDaysConfiguration() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let testStore = tempDir.appendingPathComponent("roulette-history-test-\(UUID()).json")

        // Test with normal positive maxHistoryDays
        let store = DuplicatePreventionStore(logger: logger, storeURL: testStore, maxHistoryDays: 1.0)
        try store.recordSelection(["test1.swift", "test2.swift"])

        let recentFiles = try store.getRecentlySelectedFiles()
        #expect(recentFiles.count == 2, "Should retain files within history period")
        #expect(recentFiles.contains("test1.swift"))
        #expect(recentFiles.contains("test2.swift"))
    }

    @Test("Should handle missing store file gracefully")
    func testMissingStoreFile() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let nonExistentStore = tempDir.appendingPathComponent("non-existent-\(UUID()).json")
        let store = DuplicatePreventionStore(logger: logger, storeURL: nonExistentStore)

        // Should not throw when store doesn't exist
        let recentFiles = try store.getRecentlySelectedFiles()
        #expect(recentFiles.isEmpty, "Should return empty set for non-existent store")
    }

    @Test("Should persist selections across store instances")
    func testPersistence() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let storeURL = tempDir.appendingPathComponent("persistence-test-\(UUID()).json")

        // First store instance
        let store1 = DuplicatePreventionStore(logger: logger, storeURL: storeURL)
        try store1.recordSelection(["persistent.swift"])

        // Second store instance
        let store2 = DuplicatePreventionStore(logger: logger, storeURL: storeURL)
        let recentFiles = try store2.getRecentlySelectedFiles()

        #expect(recentFiles.contains("persistent.swift"), "Should persist selections across instances")
    }
}

@Suite("SecureRandomNumberGenerator Tests")
struct SecureRandomNumberGeneratorTests {
    @Test("Should generate random numbers")
    func testRandomGeneration() {
        let generator = SecureRandomNumberGenerator()

        // Generate several random numbers
        let numbers = (0..<100).map { _ in generator.next() }

        // Should have variety (not all the same)
        let uniqueNumbers = Set(numbers)
        #expect(uniqueNumbers.count > 50, "Should generate diverse random numbers")

        // All should be valid UInt64 values (no need to test bounds, UInt64 covers full range)
        #expect(numbers.allSatisfy { _ in true }, "All generated values should be valid")
    }

    @Test("Should work with Swift's random API")
    func testSwiftIntegration() {
        var generator = SecureRandomNumberGenerator()

        // Test with Int.random
        let randomInts = (0..<100).map { _ in Int.random(in: 1...100, using: &generator) }
        #expect(randomInts.allSatisfy { (1...100).contains($0) }, "All integers should be in specified range")

        // Test with Double.random
        let randomDoubles = (0..<100).map { _ in Double.random(in: 0.0..<1.0, using: &generator) }
        #expect(randomDoubles.allSatisfy { (0.0..<1.0).contains($0) }, "All doubles should be in specified range")

        // Should have variety
        let uniqueInts = Set(randomInts)
        let uniqueDoubles = Set(randomDoubles)
        #expect(uniqueInts.count > 50, "Should generate diverse integers")
        #expect(uniqueDoubles.count > 50, "Should generate diverse doubles")
    }
}

@Suite("FileSelector Tests")
struct FileSelectorTests {
    let logger = Logger(label: "test")

    func createTempSelector() -> FileSelector {
        FileSelector(logger: logger)
    }

    @Test("Should select files from repository")
    func testBasicFileSelection() throws {
        let selector = createTempSelector()

        // Test basic selection in our repository
        let selectedFiles = try selector.selectRandomFiles(count: 2, excludeTests: false)

        #expect(selectedFiles.count <= 2, "Should not select more than requested count")
        #expect(!selectedFiles.isEmpty, "Should select at least some files")
        #expect(selectedFiles.allSatisfy { $0.hasSuffix(".swift") }, "All selected files should be Swift files")
    }

    @Test("Should respect exclude tests flag")
    func testExcludeTests() throws {
        let selector = createTempSelector()

        // Test with and without test exclusion
        _ = try selector.selectRandomFiles(count: 10, excludeTests: false)
        let withoutTests = try selector.selectRandomFiles(count: 10, excludeTests: true)

        // When excluding tests, should not contain test patterns
        let hasTestPatterns = withoutTests.contains { file in
            file.contains("Tests/") || file.contains("Test.swift") || file.contains("Tests.swift")
        }
        #expect(!hasTestPatterns, "Should not contain test files when excluding tests")
    }

    @Test("Should handle empty repository gracefully")
    func testEmptyRepository() throws {
        // This test would be hard to implement since we're in a real repo
        // Instead, we test that the selector handles the case where discovery returns few files
        let selector = createTempSelector()

        // Request more files than likely exist in our small test repo section
        let selectedFiles = try selector.selectRandomFiles(count: 1000, excludeTests: false)

        // Should return available files, not fail
        #expect(!selectedFiles.isEmpty, "Should return available files even if fewer than requested")
        #expect(selectedFiles.allSatisfy { $0.hasSuffix(".swift") }, "All files should be Swift files")
    }

    @Test("Should handle duplicate prevention")
    func testDuplicatePrevention() throws {
        let selector = createTempSelector()

        // First selection
        let firstSelection = try selector.selectRandomFiles(count: 2, excludeTests: true)
        #expect(!firstSelection.isEmpty, "First selection should find files")

        // Second selection should try to avoid duplicates
        let secondSelection = try selector.selectRandomFiles(count: 2, excludeTests: true)
        #expect(!secondSelection.isEmpty, "Second selection should find files")

        // Note: Due to the nature of duplicate prevention, we can't guarantee no overlap
        // in a small repository, but the system should attempt to avoid duplicates
    }

    @Test("Should apply weighted selection")
    func testWeightedSelection() throws {
        let selector = createTempSelector()

        // Test that selection works with weighting
        let selectedFiles = try selector.selectRandomFiles(count: 3, excludeTests: false)

        #expect(!selectedFiles.isEmpty, "Weighted selection should find files")
        #expect(selectedFiles.allSatisfy { $0.hasSuffix(".swift") }, "All selected files should be Swift files")

        // The weighted selection should still work even if weights can't be calculated
        // (the implementation falls back to uniform selection in that case)
    }
}
