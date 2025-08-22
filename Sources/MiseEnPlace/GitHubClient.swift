import AsyncHTTPClient
import Foundation
import NIOCore
import NIOHTTP1

/// GitHub API client implementation
public class GitHubClient: GitHubClientProtocol {
    private let httpClient: HTTPClient
    private let token: String
    private let baseURL = "https://api.github.com"
    private let shouldShutdownClient: Bool

    public init(token: String? = nil, httpClient: HTTPClient? = nil) {
        if let providedClient = httpClient {
            self.httpClient = providedClient
            self.shouldShutdownClient = false
        } else {
            self.httpClient = HTTPClient(eventLoopGroupProvider: .singleton)
            self.shouldShutdownClient = true
        }
        self.token = token ?? ProcessInfo.processInfo.environment["GITHUB_TOKEN"] ?? ""
    }

    public func createRepository(_ repository: Repository) async throws {
        let url = "\(baseURL)/orgs/\(repository.organization)/repos"

        let requestBody = CreateRepositoryRequest(
            name: repository.name,
            private: repository.isPrivate,
            has_issues: repository.hasIssues,
            has_projects: repository.hasProjects,
            auto_init: true
        )

        let jsonData = try JSONEncoder().encode(requestBody)

        var request = HTTPClientRequest(url: url)
        request.method = .POST
        request.headers.add(name: "Authorization", value: "Bearer \(token)")
        request.headers.add(name: "Accept", value: "application/vnd.github.v3+json")
        request.headers.add(name: "Content-Type", value: "application/json")
        request.headers.add(name: "User-Agent", value: "MiseEnPlace/1.0")
        request.body = .bytes(ByteBuffer(bytes: jsonData))

        let response = try await httpClient.execute(request, timeout: .seconds(30))

        guard response.status == .created else {
            let body = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: body)
            throw MiseEnPlaceError.githubAPIError("Failed to create repository: \(errorMessage)")
        }
    }

    public func setupBranchProtection(_ protection: BranchProtection) async throws {
        let url = "\(baseURL)/repos/neon-law/\(protection.repository)/branches/\(protection.branch)/protection"

        _ = BranchProtectionRequest(
            required_status_checks: RequiredStatusChecks(
                strict: true,
                contexts: []
            ),
            enforce_admins: true,
            required_pull_request_reviews: RequiredPullRequestReviews(
                required_approving_review_count: protection.requiredReviewCount,
                dismiss_stale_reviews: false,
                require_code_owner_reviews: false
            ),
            restrictions: nil
        )

        // Manually construct JSON to ensure restrictions: null is included
        let jsonString = """
            {
              "required_status_checks": {
                "strict": true,
                "contexts": []
              },
              "enforce_admins": true,
              "required_pull_request_reviews": {
                "required_approving_review_count": \(protection.requiredReviewCount),
                "dismiss_stale_reviews": false,
                "require_code_owner_reviews": false
              },
              "restrictions": null
            }
            """
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw MiseEnPlaceError.githubAPIError("Failed to encode branch protection request")
        }

        var request = HTTPClientRequest(url: url)
        request.method = .PUT
        request.headers.add(name: "Authorization", value: "Bearer \(token)")
        request.headers.add(name: "Accept", value: "application/vnd.github.v3+json")
        request.headers.add(name: "Content-Type", value: "application/json")
        request.headers.add(name: "User-Agent", value: "MiseEnPlace/1.0")
        request.body = .bytes(ByteBuffer(bytes: jsonData))

        let response = try await httpClient.execute(request, timeout: .seconds(30))

        guard response.status == .ok || response.status == .created else {
            let body = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: body)
            throw MiseEnPlaceError.githubAPIError("Failed to setup branch protection: \(errorMessage)")
        }
    }

    public func commitFile(_ file: CommittedFile) async throws {
        let url = "\(baseURL)/repos/neon-law/\(file.repository)/contents/\(file.path)"

        let encodedContent = Data(file.content.utf8).base64EncodedString()

        // Check if file exists to get its SHA
        let existingSha = try await getExistingFileSha(repository: file.repository, path: file.path)

        let requestBody = CreateFileRequest(
            message: existingSha != nil ? "Update \(file.path)" : "Add \(file.path)",
            content: encodedContent,
            branch: "main",
            sha: existingSha
        )

        let jsonData = try JSONEncoder().encode(requestBody)

        var request = HTTPClientRequest(url: url)
        request.method = .PUT
        request.headers.add(name: "Authorization", value: "Bearer \(token)")
        request.headers.add(name: "Accept", value: "application/vnd.github.v3+json")
        request.headers.add(name: "Content-Type", value: "application/json")
        request.headers.add(name: "User-Agent", value: "MiseEnPlace/1.0")
        request.body = .bytes(ByteBuffer(bytes: jsonData))

        let response = try await httpClient.execute(request, timeout: .seconds(30))

        guard response.status == .created || response.status == .ok else {
            let body = try await response.body.collect(upTo: 1024 * 1024)
            let errorMessage = String(buffer: body)
            throw MiseEnPlaceError.githubAPIError("Failed to commit file \(file.path): \(errorMessage)")
        }
    }

    private func getExistingFileSha(repository: String, path: String) async throws -> String? {
        let url = "\(baseURL)/repos/neon-law/\(repository)/contents/\(path)"

        var request = HTTPClientRequest(url: url)
        request.method = .GET
        request.headers.add(name: "Authorization", value: "Bearer \(token)")
        request.headers.add(name: "Accept", value: "application/vnd.github.v3+json")
        request.headers.add(name: "User-Agent", value: "MiseEnPlace/1.0")

        let response = try await httpClient.execute(request, timeout: .seconds(30))

        // If file doesn't exist, return nil
        guard response.status == .ok else {
            return nil
        }

        let body = try await response.body.collect(upTo: 1024 * 1024)
        let jsonString = String(buffer: body)

        // Parse the response to get the SHA
        struct FileResponse: Codable {
            let sha: String
        }

        let fileResponse = try JSONDecoder().decode(FileResponse.self, from: Data(jsonString.utf8))
        return fileResponse.sha
    }

    public func shutdown() async throws {
        if shouldShutdownClient {
            try await httpClient.shutdown()
        }
    }

    deinit {
        if shouldShutdownClient {
            // Force shutdown in deinit as a safety net
            try? httpClient.syncShutdown()
        }
    }
}

// MARK: - Request Models

private struct CreateRepositoryRequest: Codable {
    let name: String
    let `private`: Bool
    let has_issues: Bool
    let has_projects: Bool
    let auto_init: Bool
}

private struct BranchProtectionRequest: Codable {
    let required_status_checks: RequiredStatusChecks?
    let enforce_admins: Bool
    let required_pull_request_reviews: RequiredPullRequestReviews
    let restrictions: Restrictions?
}

private struct RequiredStatusChecks: Codable {
    let strict: Bool
    let contexts: [String]
}

private struct RequiredPullRequestReviews: Codable {
    let required_approving_review_count: Int
    let dismiss_stale_reviews: Bool
    let require_code_owner_reviews: Bool
}

private struct Restrictions: Codable {
    // Can be expanded as needed
}

private struct CreateFileRequest: Codable {
    let message: String
    let content: String
    let branch: String
    let sha: String?
}
