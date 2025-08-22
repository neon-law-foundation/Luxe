import Foundation

// MARK: - Data Models

public struct Repository {
    public let name: String
    public let organization: String
    public let isPrivate: Bool
    public let hasIssues: Bool
    public let hasProjects: Bool

    public init(
        name: String,
        organization: String,
        isPrivate: Bool,
        hasIssues: Bool,
        hasProjects: Bool
    ) {
        self.name = name
        self.organization = organization
        self.isPrivate = isPrivate
        self.hasIssues = hasIssues
        self.hasProjects = hasProjects
    }
}

public struct BranchProtection {
    public let repository: String
    public let branch: String
    public let requirePullRequest: Bool
    public let requiredReviewCount: Int

    public init(
        repository: String,
        branch: String,
        requirePullRequest: Bool,
        requiredReviewCount: Int
    ) {
        self.repository = repository
        self.branch = branch
        self.requirePullRequest = requirePullRequest
        self.requiredReviewCount = requiredReviewCount
    }
}

public struct CommittedFile {
    public let path: String
    public let content: String
    public let repository: String

    public init(path: String, content: String, repository: String) {
        self.path = path
        self.content = content
        self.repository = repository
    }
}

// MARK: - Protocols

public protocol GitHubClientProtocol {
    func createRepository(_ repository: Repository) async throws
    func setupBranchProtection(_ protection: BranchProtection) async throws
    func commitFile(_ file: CommittedFile) async throws
    func shutdown() async throws
}

public protocol FileManagerProtocol {
    func readFile(at path: String) throws -> String
    func fileExists(at path: String) -> Bool
}
