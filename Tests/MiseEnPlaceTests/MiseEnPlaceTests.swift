import Foundation
import Testing

@testable import MiseEnPlace

@Suite("MiseEnPlace CLI Tool Tests", .serialized)
struct MiseEnPlaceTests {
    @Suite("GitHub Repository Creation", .serialized)
    struct GitHubRepositoryTests {
        @Test("Creates a new private repository in the neon-law organization")
        func createsNewPrivateRepositoryInNeonLawOrganization() async throws {
            let client = MockGitHubClient()
            let miseEnPlace = MiseEnPlace(githubClient: client)

            try await miseEnPlace.createRepository(name: "test-repo")

            #expect(client.createdRepositories.count == 1)
            let repo = try #require(client.createdRepositories.first)
            #expect(repo.name == "test-repo")
            #expect(repo.organization == "neon-law")
            #expect(repo.isPrivate == true)
        }

        @Test("Sets up branch protection on main branch")
        func setsUpBranchProtectionOnMainBranch() async throws {
            let client = MockGitHubClient()
            let miseEnPlace = MiseEnPlace(githubClient: client)

            try await miseEnPlace.createRepository(name: "test-repo")

            #expect(client.branchProtections.count == 1)
            let protection = try #require(client.branchProtections.first)
            #expect(protection.repository == "test-repo")
            #expect(protection.branch == "main")
            #expect(protection.requirePullRequest == true)
            #expect(protection.requiredReviewCount >= 1)
        }

        @Test("Disables issues and projects")
        func disablesIssuesAndProjectsOnCreation() async throws {
            let client = MockGitHubClient()
            let miseEnPlace = MiseEnPlace(githubClient: client)

            try await miseEnPlace.createRepository(name: "test-repo")

            let repo = try #require(client.createdRepositories.first)
            #expect(repo.hasIssues == false)
            #expect(repo.hasProjects == false)
        }
    }

    @Suite("File Template Copying", .serialized)
    struct FileTemplateCopyingTests {
        @Test("Copies .github folder structure from template")
        func copiesGitHubFolderStructureFromTemplate() async throws {
            let client = MockGitHubClient()
            let fileManager = MockFileManager()
            let miseEnPlace = MiseEnPlace(githubClient: client, fileManager: fileManager)

            try await miseEnPlace.createRepository(name: "test-repo")

            let expectedFiles = [
                ".github/CODEOWNERS",
                ".github/workflows/ci.yaml",
                ".github/workflows/cd.yaml",
            ]

            for file in expectedFiles {
                #expect(client.committedFiles.contains { $0.path == file })
            }
        }

        @Test("Copies .gitignore file")
        func copiesGitignoreFile() async throws {
            let client = MockGitHubClient()
            let fileManager = MockFileManager()
            let miseEnPlace = MiseEnPlace(githubClient: client, fileManager: fileManager)

            try await miseEnPlace.createRepository(name: "test-repo")

            #expect(client.committedFiles.contains { $0.path == ".gitignore" })
        }

        @Test("Copies CLAUDE.md file")
        func copiesClaudeMDFile() async throws {
            let client = MockGitHubClient()
            let fileManager = MockFileManager()
            let miseEnPlace = MiseEnPlace(githubClient: client, fileManager: fileManager)

            try await miseEnPlace.createRepository(name: "test-repo")

            #expect(client.committedFiles.contains { $0.path == "CLAUDE.md" })
        }

        @Test("Creates README.md with repository name")
        func createsReadmeWithRepositoryName() async throws {
            let client = MockGitHubClient()
            let fileManager = MockFileManager()
            let miseEnPlace = MiseEnPlace(githubClient: client, fileManager: fileManager)

            let repoName = "awesome-project"
            try await miseEnPlace.createRepository(name: repoName)

            let readme = client.committedFiles.first { $0.path == "README.md" }
            let readmeContent = try #require(readme?.content)
            #expect(readmeContent.contains(repoName))
        }
    }

    @Suite("Command Line Interface", .serialized)
    struct CommandLineInterfaceTests {
        @Test("Accepts repository name as argument")
        func acceptsRepositoryNameAsArgument() async throws {
            let args = ["MiseEnPlace", "my-new-repo"]
            let parser = CommandLineParser(arguments: args)

            let repoName = try parser.parseRepositoryName()
            #expect(repoName == "my-new-repo")
        }

        @Test("Shows help when no arguments provided")
        func showsHelpWhenNoArgumentsProvided() async throws {
            let args = ["MiseEnPlace"]
            let parser = CommandLineParser(arguments: args)

            #expect(throws: MiseEnPlaceError.missingRepositoryName) {
                try parser.parseRepositoryName()
            }
        }

        @Test("Validates repository name format")
        func validatesRepositoryNameFormat() async throws {
            let invalidNames = ["repo with spaces", "UPPERCASE", "repo/slash", ""]

            for name in invalidNames {
                let args = ["MiseEnPlace", name]
                let parser = CommandLineParser(arguments: args)

                #expect(throws: MiseEnPlaceError.invalidRepositoryName) {
                    try parser.parseRepositoryName()
                }
            }
        }
    }
}

// MARK: - Mock Types

class MockGitHubClient: GitHubClientProtocol {
    var createdRepositories: [Repository] = []
    var branchProtections: [BranchProtection] = []
    var committedFiles: [CommittedFile] = []

    func createRepository(_ repository: Repository) async throws {
        createdRepositories.append(repository)
    }

    func setupBranchProtection(_ protection: BranchProtection) async throws {
        branchProtections.append(protection)
    }

    func commitFile(_ file: CommittedFile) async throws {
        committedFiles.append(file)
    }

    func shutdown() async throws {
        // Mock implementation - no cleanup needed
    }
}

class MockFileManager: FileManagerProtocol {
    var fileContents: [String: String] = [
        ".github/CODEOWNERS": "* @aire-neon @shicholas\n",
        ".github/workflows/ci.yaml": "name: CI\non: push\njobs:\n  test:\n    runs-on: ubuntu-latest\n",
        ".github/workflows/cd.yaml": "name: CD\non: push\njobs:\n  deploy:\n    runs-on: ubuntu-latest\n",
        ".gitignore": ".build/\n.vscode/\n.DS_Store\n.swiftpm/\n",
        "CLAUDE.md": "# Test CLAUDE.md content",
    ]

    func readFile(at path: String) throws -> String {
        guard let content = fileContents[path] else {
            throw MiseEnPlaceError.fileNotFound(path)
        }
        return content
    }

    func fileExists(at path: String) -> Bool {
        fileContents[path] != nil
    }
}
