import ArgumentParser
import Foundation
import Testing

@testable import Standards

@Suite("Validate Command")
struct ValidateCommandTests {
    @Test("Should handle default path argument")
    func testHandlesDefaultPath() async throws {
        // Parse arguments to create command with default path
        let arguments = ["validate"]
        let parseResult = try Standards.parseAsRoot(arguments)

        guard let validateCommand = parseResult as? Standards.Validate else {
            #expect(Bool(false), "Should parse as Validate command")
            return
        }

        // Default path should be "."
        #expect(validateCommand.path == ".")
        #expect(validateCommand.verbose == false)
    }

    @Test("Should handle custom path argument")
    func testHandlesCustomPath() async throws {
        let customPath = "/custom/path/to/standards"

        // Parse arguments to create command
        let arguments = ["validate", customPath]
        let parseResult = try Standards.parseAsRoot(arguments)

        guard let validateCommand = parseResult as? Standards.Validate else {
            #expect(Bool(false), "Should parse as Validate command")
            return
        }

        #expect(validateCommand.path == customPath)
    }

    @Test("Should handle verbose flag")
    func testHandlesVerboseFlag() async throws {
        let arguments = ["validate", "--verbose", "/some/path"]
        let parseResult = try Standards.parseAsRoot(arguments)

        guard let validateCommand = parseResult as? Standards.Validate else {
            #expect(Bool(false), "Should parse as Validate command")
            return
        }

        #expect(validateCommand.verbose == true)
        #expect(validateCommand.path == "/some/path")
    }

    @Test("Should handle short verbose flag")
    func testHandlesShortVerboseFlag() async throws {
        let arguments = ["validate", "-v", "/some/path"]
        let parseResult = try Standards.parseAsRoot(arguments)

        guard let validateCommand = parseResult as? Standards.Validate else {
            #expect(Bool(false), "Should parse as Validate command")
            return
        }

        #expect(validateCommand.verbose == true)
    }

    @Test("Should validate directory structure in integration test")
    func testValidatesDirectoryStructure() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("validate-command-test")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create a valid standards file
        let validContent = """
            ---
            code: TEST001
            title: "Integration Test Standard"
            respondant_type: individual
            ---

            # Integration Test Standard

            This is a test for the validate command integration.
            """

        let validFile = tempDir.appendingPathComponent("integration-test.md")
        try validContent.write(to: validFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Test the validation logic directly through StandardsValidator
        #expect(throws: Never.self) {
            let validator = StandardsValidator()
            let result = validator.validateDirectory(path: tempDir.path)
            if !result.isValid {
                throw ValidationTestError.validationFailed
            }
        }
    }
}

enum ValidationTestError: Error {
    case validationFailed
}
