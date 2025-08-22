import Foundation
import Testing

@testable import Standards

@Suite("Integration Tests")
struct IntegrationTests {

    @Test("Should validate real standards directory structure")
    func testValidatesRealStandardsStructure() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("integration-standards-test")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create a realistic standards directory structure
        let standardsDir = tempDir.appendingPathComponent("standards")
        let corporateDir = standardsDir.appendingPathComponent("corporate")
        let individualDir = standardsDir.appendingPathComponent("individual")

        try FileManager.default.createDirectory(at: corporateDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: individualDir, withIntermediateDirectories: true)

        // Create valid corporate standard
        let corporateStandard = """
            ---
            code: CORP001
            title: "Corporate Formation Standard"
            respondant_type: organization
            ---

            # Corporate Formation Standard

            This standard outlines the requirements for corporate entity formation.

            ## Requirements

            1. Articles of Incorporation must be filed
            2. Corporate bylaws must be established
            3. Board of directors must be appointed

            ## Process

            The formation process typically takes 5-10 business days.
            """

        // Create valid individual standard
        let individualStandard = """
            ---
            code: IND001
            title: "Individual Service Standard"
            respondant_type: individual
            ---

            # Individual Service Standard

            This standard defines service levels for individual clients.

            ## Response Times

            - Initial consultation: Within 24 hours
            - Document review: Within 48 hours
            - Final delivery: Within 5 business days
            """

        // Create invalid standard (missing required fields)
        let invalidStandard = """
            ---
            title: "Incomplete Standard"
            ---

            # Incomplete Standard

            This standard is missing the code and respondant_type fields.
            """

        // Create files that should be excluded
        let readmeContent = """
            # Standards Directory

            This directory contains all Sagebrush Standards files.
            """

        let claudeContent = """
            # Standards Development Instructions

            When creating new standards, follow these guidelines...
            """

        try corporateStandard.write(
            to: corporateDir.appendingPathComponent("corporate-formation.md"),
            atomically: true,
            encoding: .utf8
        )

        try individualStandard.write(
            to: individualDir.appendingPathComponent("individual-service.md"),
            atomically: true,
            encoding: .utf8
        )

        try invalidStandard.write(
            to: standardsDir.appendingPathComponent("incomplete.md"),
            atomically: true,
            encoding: .utf8
        )

        try readmeContent.write(
            to: standardsDir.appendingPathComponent("README.md"),
            atomically: true,
            encoding: .utf8
        )

        try claudeContent.write(
            to: standardsDir.appendingPathComponent("CLAUDE.md"),
            atomically: true,
            encoding: .utf8
        )

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Test the validator
        let validator = StandardsValidator()
        let result = validator.validateDirectory(path: standardsDir.path)

        // Should find 3 markdown files (2 valid, 1 invalid)
        #expect(result.totalFilesProcessed == 3)
        #expect(result.validFiles.count == 2)
        #expect(result.invalidFiles.count == 1)
        #expect(result.isValid == false)

        // Verify correct files were processed
        #expect(result.validFiles.contains { $0.contains("corporate-formation.md") })
        #expect(result.validFiles.contains { $0.contains("individual-service.md") })
        #expect(result.invalidFiles.contains { $0.contains("incomplete.md") })

        // Verify README.md and CLAUDE.md were excluded
        let allProcessedFiles = result.validFiles + result.invalidFiles
        #expect(!allProcessedFiles.contains { $0.contains("README.md") })
        #expect(!allProcessedFiles.contains { $0.contains("CLAUDE.md") })

        // Verify error message is informative
        #expect(!result.errors.isEmpty)
        #expect(result.errors.contains { $0.contains("incomplete.md") })
        #expect(result.errors.contains { $0.contains("Missing required YAML fields") })
    }

    @Test("Should handle complex nested directory structure")
    func testHandlesComplexNestedStructure() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nested-standards-test")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Create deeply nested structure
        let deepPath =
            tempDir
            .appendingPathComponent("level1")
            .appendingPathComponent("level2")
            .appendingPathComponent("level3")
            .appendingPathComponent("level4")

        try FileManager.default.createDirectory(at: deepPath, withIntermediateDirectories: true)

        // Create a valid standard in the deep path
        let validDeepStandard = """
            ---
            code: DEEP001
            title: "Deeply Nested Standard"
            respondant_type: individual
            ---

            # Deeply Nested Standard

            This standard tests recursive directory traversal.
            """

        try validDeepStandard.write(
            to: deepPath.appendingPathComponent("deep-standard.md"),
            atomically: true,
            encoding: .utf8
        )

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let validator = StandardsValidator()
        let result = validator.validateDirectory(path: tempDir.path)

        #expect(result.totalFilesProcessed == 1)
        #expect(result.validFiles.count == 1)
        #expect(result.invalidFiles.count == 0)
        #expect(result.isValid == true)
        #expect(result.validFiles.first?.contains("deep-standard.md") == true)
    }

    @Test("Should validate different respondant_type values")
    func testValidatesDifferentRespondantTypes() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("respondant-type-test")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let individualStandard = """
            ---
            code: TYPE001
            title: "Individual Type Standard"
            respondant_type: individual
            ---

            Content for individual respondants.
            """

        let organizationStandard = """
            ---
            code: TYPE002
            title: "Organization Type Standard"
            respondant_type: organization
            ---

            Content for organization respondants.
            """

        let bothStandard = """
            ---
            code: TYPE003
            title: "Both Type Standard"
            respondant_type: both
            ---

            Content for both individual and organization respondants.
            """

        try individualStandard.write(
            to: tempDir.appendingPathComponent("individual.md"),
            atomically: true,
            encoding: .utf8
        )

        try organizationStandard.write(
            to: tempDir.appendingPathComponent("organization.md"),
            atomically: true,
            encoding: .utf8
        )

        try bothStandard.write(
            to: tempDir.appendingPathComponent("both.md"),
            atomically: true,
            encoding: .utf8
        )

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let validator = StandardsValidator()
        let result = validator.validateDirectory(path: tempDir.path)

        #expect(result.totalFilesProcessed == 3)
        #expect(result.validFiles.count == 3)
        #expect(result.invalidFiles.count == 0)
        #expect(result.isValid == true)
    }

    @Test("Should handle standards with complex YAML structures")
    func testHandlesComplexYAMLStructures() async throws {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("complex-yaml-test")
            .appendingPathComponent(UUID().uuidString)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let complexStandard = """
            ---
            code: COMPLEX001
            title: "Complex YAML Standard"
            respondant_type: organization
            version: "1.2.0"
            effective_date: "2024-01-01"
            tags: ["legal", "corporate", "formation"]
            related_standards:
              - CORP001
              - CORP002
            metadata:
              author: "Legal Team"
              review_date: "2024-12-31"
              complexity: "high"
            ---

            # Complex YAML Standard

            This standard demonstrates complex YAML frontmatter structures.
            """

        try complexStandard.write(
            to: tempDir.appendingPathComponent("complex.md"),
            atomically: true,
            encoding: .utf8
        )

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let validator = StandardsValidator()
        let result = validator.validateDirectory(path: tempDir.path)

        // Should still validate successfully with additional fields
        #expect(result.totalFilesProcessed == 1)
        #expect(result.validFiles.count == 1)
        #expect(result.invalidFiles.count == 0)
        #expect(result.isValid == true)
    }
}
