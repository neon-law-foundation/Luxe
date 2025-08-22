import Foundation
import Testing

@testable import Standards

@Suite("File Processor")
struct FileProcessorTests {
    @Test("Should find markdown files recursively")
    func testFindsMarkdownFilesRecursively() async throws {
        let processor = FileProcessor()

        // Create a temporary directory structure for testing
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("standards-test")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create test files
        let file1 = tempDir.appendingPathComponent("test1.md")
        let file2 = tempDir.appendingPathComponent("subdir").appendingPathComponent("test2.md")
        let file3 = tempDir.appendingPathComponent("README.md")
        let file4 = tempDir.appendingPathComponent("CLAUDE.md")
        let file5 = tempDir.appendingPathComponent("other.txt")

        try FileManager.default.createDirectory(
            at: file2.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try "test content".write(to: file1, atomically: true, encoding: .utf8)
        try "test content".write(to: file2, atomically: true, encoding: .utf8)
        try "readme content".write(to: file3, atomically: true, encoding: .utf8)
        try "claude content".write(to: file4, atomically: true, encoding: .utf8)
        try "other content".write(to: file5, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let foundFiles = processor.findMarkdownFiles(in: tempDir.path)

        // Should find test1.md and test2.md, but exclude README.md and CLAUDE.md
        #expect(foundFiles.count == 2)
        #expect(foundFiles.contains { $0.hasSuffix("test1.md") })
        #expect(foundFiles.contains { $0.hasSuffix("test2.md") })
        #expect(!foundFiles.contains { $0.hasSuffix("README.md") })
        #expect(!foundFiles.contains { $0.hasSuffix("CLAUDE.md") })
        #expect(!foundFiles.contains { $0.hasSuffix("other.txt") })
    }

    @Test("Should handle empty directory")
    func testHandlesEmptyDirectory() async throws {
        let processor = FileProcessor()

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("standards-test-empty")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let foundFiles = processor.findMarkdownFiles(in: tempDir.path)
        #expect(foundFiles.isEmpty)
    }

    @Test("Should handle non-existent directory")
    func testHandlesNonExistentDirectory() async throws {
        let processor = FileProcessor()
        let nonExistentPath = "/path/that/does/not/exist"

        let foundFiles = processor.findMarkdownFiles(in: nonExistentPath)
        #expect(foundFiles.isEmpty)
    }

    @Test("Should exclude README.md and CLAUDE.md by name")
    func testExcludesSpecificFiles() async throws {
        let processor = FileProcessor()

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("standards-test-exclude")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create files that should be excluded
        let readmeFile = tempDir.appendingPathComponent("README.md")
        let claudeFile = tempDir.appendingPathComponent("CLAUDE.md")
        let validFile = tempDir.appendingPathComponent("valid-standard.md")

        try "readme".write(to: readmeFile, atomically: true, encoding: .utf8)
        try "claude".write(to: claudeFile, atomically: true, encoding: .utf8)
        try "valid".write(to: validFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let foundFiles = processor.findMarkdownFiles(in: tempDir.path)

        #expect(foundFiles.count == 1)
        #expect(foundFiles.first?.hasSuffix("valid-standard.md") == true)
    }
}
