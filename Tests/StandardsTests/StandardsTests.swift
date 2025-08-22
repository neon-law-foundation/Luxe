import Testing

@testable import Standards

@Suite("Standards CLI")
struct StandardsTests {
    @Test("Standards main command should be available")
    func testStandardsCommandExists() async throws {
        #expect(Standards.configuration.abstract.contains("Validate Sagebrush Standards"))
    }

    @Test("Validate subcommand should be available")
    func testValidateSubcommandExists() async throws {
        #expect(Standards.Validate.configuration.abstract.contains("Validate standards files"))
    }
}
