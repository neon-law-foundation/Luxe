import Foundation
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
