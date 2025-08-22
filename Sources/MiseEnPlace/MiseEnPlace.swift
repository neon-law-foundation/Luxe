import AsyncHTTPClient
import Foundation
import NIOCore
import NIOHTTP1

/// Main MiseEnPlace class for creating GitHub repositories
public class MiseEnPlace {
    private let githubClient: GitHubClientProtocol
    private let fileManager: FileManagerProtocol

    public init(
        githubClient: GitHubClientProtocol? = nil,
        fileManager: FileManagerProtocol? = nil
    ) {
        self.githubClient = githubClient ?? GitHubClient()
        self.fileManager = fileManager ?? DefaultFileManager()
    }

    /// Creates a new private GitHub repository with the specified configuration
    public func createRepository(name: String) async throws {
        // Create the repository
        let repository = Repository(
            name: name,
            organization: "neon-law",
            isPrivate: true,
            hasIssues: false,
            hasProjects: false
        )

        try await githubClient.createRepository(repository)

        // Copy template files first
        try await copyTemplateFiles(to: name)

        // Set up branch protection after files are committed
        let branchProtection = BranchProtection(
            repository: name,
            branch: "main",
            requirePullRequest: true,
            requiredReviewCount: 1
        )

        do {
            try await githubClient.setupBranchProtection(branchProtection)
        } catch {
            // Branch protection failed, but continue with repository creation
            print("⚠️  Branch protection setup failed: \(error.localizedDescription)")
        }
    }

    private func copyTemplateFiles(to repositoryName: String) async throws {
        // Copy .github folder
        let githubFiles = [
            ".github/CODEOWNERS",
            ".github/workflows/ci.yaml",
            ".github/workflows/cd.yaml",
        ]

        for filePath in githubFiles {
            do {
                let content = try fileManager.readFile(at: filePath)
                let file = CommittedFile(
                    path: filePath,
                    content: content,
                    repository: repositoryName
                )
                try await githubClient.commitFile(file)
            } catch {
                // If file doesn't exist, skip it
                continue
            }
        }

        // Copy .gitignore
        if let gitignoreContent = try? fileManager.readFile(at: ".gitignore") {
            let file = CommittedFile(
                path: ".gitignore",
                content: gitignoreContent,
                repository: repositoryName
            )
            try await githubClient.commitFile(file)
        }

        // Copy CLAUDE.md
        if let claudeContent = try? fileManager.readFile(at: "CLAUDE.md") {
            let file = CommittedFile(
                path: "CLAUDE.md",
                content: claudeContent,
                repository: repositoryName
            )
            try await githubClient.commitFile(file)
        }

        // Copy contract style guide
        if let contractStyleContent = try? fileManager.readFile(at: "Sources/NeonWeb/Markdown/contract_style_guide.md")
        {
            let file = CommittedFile(
                path: "contract_style_guide.md",
                content: contractStyleContent,
                repository: repositoryName
            )
            try await githubClient.commitFile(file)
        }

        // Create README.md with repository name following contract style guide
        let readmeContent = """
            # \(repositoryName)

            This repository contains legal matter documentation and contract materials for project \(repositoryName). All content
            follows the established contract style guide and professional documentation standards outlined in this repository.

            ## Documentation Standards

            All documents in this repository must adhere to the contract style guide principles:

            - **Line length**: 120 characters maximum per line, optimizing space usage
            - **Writing voice**: Active, concise voice authored with legal precision and clarity
            - **Inclusive language**: Professional terminology that is inclusive of all people
            - **Legal formatting**: Harvard outline style with hierarchical headings and consistent numbering

            ## Getting Started

            1. Review `contract_style_guide.md` for comprehensive writing and formatting standards
            2. See `CLAUDE.md` for project guidelines and development instructions
            3. Follow the established patterns for legal documentation and employee handbook creation

            ## Matter Project Code Name

            This repository corresponds to matter project: **\(repositoryName)**.

            ## Repository Structure

            - `/notations/` - Legal notations and contract templates, written in Sagebrush Standards style.

            For additional information, consult the project guidelines in CLAUDE.md and the contract style guide.
            """

        let readmeFile = CommittedFile(
            path: "README.md",
            content: readmeContent,
            repository: repositoryName
        )
        try await githubClient.commitFile(readmeFile)
    }

    /// Shutdown the MiseEnPlace client and clean up resources
    public func shutdown() async throws {
        try await githubClient.shutdown()
    }
}
