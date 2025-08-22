import Testing

@testable import Standards

@Suite("YAML Validator")
struct YAMLValidatorTests {
    @Test("Should detect presence of YAML frontmatter delimiters")
    func testDetectsFrontmatterPresence() async throws {
        let validMarkdown = """
            ---
            code: TEST001
            title: Test Standard
            respondant_type: individual
            ---

            # Test Standard Content

            This is the content of the standard.
            """

        let validator = YAMLValidator()
        let result = validator.hasFrontmatter(content: validMarkdown)
        #expect(result == true)
    }

    @Test("Should detect absence of YAML frontmatter")
    func testDetectsNoFrontmatter() async throws {
        let invalidMarkdown = """
            # Test Standard Content

            This markdown has no YAML frontmatter.
            """

        let validator = YAMLValidator()
        let result = validator.hasFrontmatter(content: invalidMarkdown)
        #expect(result == false)
    }

    @Test("Should validate proper starting delimiter")
    func testValidatesStartingDelimiter() async throws {
        let markdownWithStartDelimiter = """
            ---
            code: TEST001
            title: Test Standard
            ---

            Content here
            """

        let validator = YAMLValidator()
        let result = validator.hasValidStartDelimiter(content: markdownWithStartDelimiter)
        #expect(result == true)
    }

    @Test("Should reject missing starting delimiter")
    func testRejectsMissingStartDelimiter() async throws {
        let markdownWithoutStartDelimiter = """
            code: TEST001
            title: Test Standard
            ---

            Content here
            """

        let validator = YAMLValidator()
        let result = validator.hasValidStartDelimiter(content: markdownWithoutStartDelimiter)
        #expect(result == false)
    }

    @Test("Should validate proper ending delimiter")
    func testValidatesEndingDelimiter() async throws {
        let markdownWithEndDelimiter = """
            ---
            code: TEST001
            title: Test Standard
            ---

            Content here
            """

        let validator = YAMLValidator()
        let result = validator.hasValidEndDelimiter(content: markdownWithEndDelimiter)
        #expect(result == true)
    }

    @Test("Should reject missing ending delimiter")
    func testRejectsMissingEndDelimiter() async throws {
        let markdownWithoutEndDelimiter = """
            ---
            code: TEST001
            title: Test Standard

            Content here
            """

        let validator = YAMLValidator()
        let result = validator.hasValidEndDelimiter(content: markdownWithoutEndDelimiter)
        #expect(result == false)
    }

    @Test("Should validate proper YAML parsing")
    func testValidatesYAMLParsing() async throws {
        let validYAMLMarkdown = """
            ---
            code: TEST001
            title: "Test Standard"
            respondant_type: individual
            ---

            Content here
            """

        let validator = YAMLValidator()
        let result = validator.isValidYAML(content: validYAMLMarkdown)
        #expect(result == true)
    }

    @Test("Should reject invalid YAML syntax")
    func testRejectsInvalidYAMLSyntax() async throws {
        let invalidYAMLMarkdown = """
            ---
            code: TEST001
            title: "Test Standard
            respondant_type: [invalid: yaml
            ---

            Content here
            """

        let validator = YAMLValidator()
        let result = validator.isValidYAML(content: invalidYAMLMarkdown)
        #expect(result == false)
    }

    @Test("Should validate required YAML fields")
    func testValidatesRequiredFields() async throws {
        let validMarkdownWithRequiredFields = """
            ---
            code: TEST001
            title: "Test Standard"
            respondant_type: individual
            ---

            Content here
            """

        let validator = YAMLValidator()
        let result = validator.hasRequiredFields(content: validMarkdownWithRequiredFields)
        #expect(result == true)
    }

    @Test("Should reject missing required YAML fields")
    func testRejectsMissingRequiredFields() async throws {
        let invalidMarkdownMissingFields = """
            ---
            title: "Test Standard"
            respondant_type: individual
            ---

            Content here
            """

        let validator = YAMLValidator()
        let result = validator.hasRequiredFields(content: invalidMarkdownMissingFields)
        #expect(result == false)
    }
}
