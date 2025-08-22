import Foundation
import Testing

@testable import Standards

@Suite("Output Formatter")
struct OutputFormatterTests {
    @Test("Should format validation success with colors")
    func testFormatsValidationSuccess() async throws {
        let formatter = OutputFormatter()
        let result = ValidationResult(
            isValid: true,
            validFiles: ["/path/to/valid1.md", "/path/to/valid2.md"],
            invalidFiles: [],
            errors: []
        )

        let output = formatter.formatResult(result, useColors: true, verbose: false)

        #expect(output.contains("2 files"))
        #expect(output.contains("✓"))
        #expect(output.contains("All standards files are valid"))
    }

    @Test("Should format validation failure with colors")
    func testFormatsValidationFailure() async throws {
        let formatter = OutputFormatter()
        let result = ValidationResult(
            isValid: false,
            validFiles: ["/path/to/valid.md"],
            invalidFiles: ["/path/to/invalid.md"],
            errors: ["/path/to/invalid.md: Missing YAML frontmatter delimiters (---)"]
        )

        let output = formatter.formatResult(result, useColors: true, verbose: false)

        #expect(output.contains("2 files"))
        #expect(output.contains("1 valid"))
        #expect(output.contains("1 invalid"))
        #expect(output.contains("✗"))
        #expect(output.contains("Some standards files are invalid"))
    }

    @Test("Should format verbose output")
    func testFormatsVerboseOutput() async throws {
        let formatter = OutputFormatter()
        let result = ValidationResult(
            isValid: true,
            validFiles: ["/path/to/valid1.md", "/path/to/valid2.md"],
            invalidFiles: [],
            errors: []
        )

        let output = formatter.formatResult(result, useColors: false, verbose: true)

        #expect(output.contains("valid1.md"))
        #expect(output.contains("valid2.md"))
        #expect(output.contains("✓"))
    }

    @Test("Should format output without colors")
    func testFormatsOutputWithoutColors() async throws {
        let formatter = OutputFormatter()
        let result = ValidationResult(
            isValid: false,
            validFiles: ["/path/to/valid.md"],
            invalidFiles: ["/path/to/invalid.md"],
            errors: ["/path/to/invalid.md: Missing YAML frontmatter"]
        )

        let output = formatter.formatResult(result, useColors: false, verbose: false)

        // Should not contain ANSI color codes
        #expect(!output.contains("\u{001B}["))
        #expect(output.contains("✗"))
        #expect(output.contains("Missing YAML frontmatter"))
    }

    @Test("Should format empty directory result")
    func testFormatsEmptyDirectoryResult() async throws {
        let formatter = OutputFormatter()
        let result = ValidationResult(
            isValid: true,
            validFiles: [],
            invalidFiles: [],
            errors: []
        )

        let output = formatter.formatResult(result, useColors: false, verbose: false)

        #expect(output.contains("0 files"))
        #expect(output.contains("No markdown files found"))
    }

    @Test("Should format summary statistics")
    func testFormatsSummaryStatistics() async throws {
        let formatter = OutputFormatter()
        let result = ValidationResult(
            isValid: false,
            validFiles: ["/valid1.md", "/valid2.md", "/valid3.md"],
            invalidFiles: ["/invalid1.md", "/invalid2.md"],
            errors: ["error1", "error2"]
        )

        let summary = formatter.formatSummary(result)

        #expect(summary.contains("5 files processed"))
        #expect(summary.contains("3 valid"))
        #expect(summary.contains("2 invalid"))
    }

    @Test("Should apply colors correctly")
    func testAppliesColors() async throws {
        let formatter = OutputFormatter()

        let greenText = formatter.colorize("success", color: .green)
        let redText = formatter.colorize("error", color: .red)
        let resetText = formatter.colorize("normal", color: .reset)

        #expect(greenText.contains("\u{001B}[32m"))  // ANSI green
        #expect(redText.contains("\u{001B}[31m"))  // ANSI red
        #expect(resetText.contains("\u{001B}[0m"))  // ANSI reset
    }

    @Test("Should not apply colors when disabled")
    func testDoesNotApplyColorsWhenDisabled() async throws {
        let formatter = OutputFormatter()

        let plainText = formatter.colorize("text", color: .green, useColors: false)

        #expect(plainText == "text")
        #expect(!plainText.contains("\u{001B}["))
    }
}
