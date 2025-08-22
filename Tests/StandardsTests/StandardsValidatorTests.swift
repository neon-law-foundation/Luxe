import Foundation
import Testing

@testable import Standards

@Suite("Standards Validator")
struct StandardsValidatorTests {
    @Test("Should validate all files in directory successfully")
    func testValidatesAllFilesSuccessfully() async throws {
        let validator = StandardsValidator()

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("standards-validator-test")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create valid standard files
        let validContent1 = """
            ---
            code: TEST001
            title: "Test Standard 1"
            respondant_type: individual
            ---

            # Test Standard 1
            Content here.
            """

        let validContent2 = """
            ---
            code: TEST002
            title: "Test Standard 2"
            respondant_type: organization
            ---

            # Test Standard 2
            More content here.
            """

        let file1 = tempDir.appendingPathComponent("test1.md")
        let file2 = tempDir.appendingPathComponent("subdir").appendingPathComponent("test2.md")

        try FileManager.default.createDirectory(
            at: file2.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try validContent1.write(to: file1, atomically: true, encoding: .utf8)
        try validContent2.write(to: file2, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let result = validator.validateDirectory(path: tempDir.path)

        #expect(result.isValid == true)
        #expect(result.validFiles.count == 2)
        #expect(result.invalidFiles.isEmpty)
        #expect(result.errors.isEmpty)
    }

    @Test("Should detect invalid files and provide error details")
    func testDetectsInvalidFilesWithErrors() async throws {
        let validator = StandardsValidator()

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("standards-validator-invalid-test")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create invalid standard files
        let invalidContent1 = """
            # No YAML frontmatter
            This file has no frontmatter.
            """

        let invalidContent2 = """
            ---
            title: "Missing Code Field"
            respondant_type: individual
            ---

            Content here.
            """

        let validContent = """
            ---
            code: TEST003
            title: "Valid Standard"
            respondant_type: individual
            ---

            Valid content.
            """

        let invalidFile1 = tempDir.appendingPathComponent("invalid1.md")
        let invalidFile2 = tempDir.appendingPathComponent("invalid2.md")
        let validFile = tempDir.appendingPathComponent("valid.md")

        try invalidContent1.write(to: invalidFile1, atomically: true, encoding: .utf8)
        try invalidContent2.write(to: invalidFile2, atomically: true, encoding: .utf8)
        try validContent.write(to: validFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let result = validator.validateDirectory(path: tempDir.path)

        #expect(result.isValid == false)
        #expect(result.validFiles.count == 1)
        #expect(result.invalidFiles.count == 2)
        #expect(result.errors.count == 2)

        // Check that error messages are informative
        #expect(result.errors.contains { $0.contains("invalid1.md") })
        #expect(result.errors.contains { $0.contains("invalid2.md") })
    }

    @Test("Should handle empty directory gracefully")
    func testHandlesEmptyDirectory() async throws {
        let validator = StandardsValidator()

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("standards-validator-empty-test")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let result = validator.validateDirectory(path: tempDir.path)

        #expect(result.isValid == true)
        #expect(result.validFiles.isEmpty)
        #expect(result.invalidFiles.isEmpty)
        #expect(result.errors.isEmpty)
    }

    @Test("Should exclude README.md and CLAUDE.md files")
    func testExcludesSpecialFiles() async throws {
        let validator = StandardsValidator()

        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("standards-validator-exclude-test")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let readmeContent = """
            # README
            This is a readme file without proper frontmatter.
            """

        let claudeContent = """
            # Claude Instructions
            No frontmatter here either.
            """

        let validContent = """
            ---
            code: TEST004
            title: "Valid Standard"
            respondant_type: individual
            ---

            Valid content.
            """

        let readmeFile = tempDir.appendingPathComponent("README.md")
        let claudeFile = tempDir.appendingPathComponent("CLAUDE.md")
        let validFile = tempDir.appendingPathComponent("valid.md")

        try readmeContent.write(to: readmeFile, atomically: true, encoding: .utf8)
        try claudeContent.write(to: claudeFile, atomically: true, encoding: .utf8)
        try validContent.write(to: validFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let result = validator.validateDirectory(path: tempDir.path)

        #expect(result.isValid == true)
        #expect(result.validFiles.count == 1)
        #expect(result.invalidFiles.isEmpty)
        #expect(result.errors.isEmpty)

        // Verify that the valid file is the only one processed
        #expect(result.validFiles.first?.hasSuffix("valid.md") == true)
    }
}
