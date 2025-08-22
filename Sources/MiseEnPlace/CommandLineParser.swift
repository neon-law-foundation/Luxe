import Foundation

/// Command line argument parser
public struct CommandLineParser {
    private let arguments: [String]

    public init(arguments: [String] = CommandLine.arguments) {
        self.arguments = arguments
    }

    public func parseRepositoryName() throws -> String {
        guard arguments.count > 1 else {
            throw MiseEnPlaceError.missingRepositoryName
        }

        let repositoryName = arguments[1]

        // Validate repository name format
        try validateRepositoryName(repositoryName)

        return repositoryName
    }

    private func validateRepositoryName(_ name: String) throws {
        // Repository name validation rules:
        // - Must not be empty
        // - Must not contain spaces
        // - Must not contain uppercase letters
        // - Must not contain slashes
        // - Must be between 1 and 100 characters

        guard !name.isEmpty else {
            throw MiseEnPlaceError.invalidRepositoryName
        }

        guard name.count <= 100 else {
            throw MiseEnPlaceError.invalidRepositoryName
        }

        guard !name.contains(" ") else {
            throw MiseEnPlaceError.invalidRepositoryName
        }

        guard !name.contains("/") else {
            throw MiseEnPlaceError.invalidRepositoryName
        }

        guard name.lowercased() == name else {
            throw MiseEnPlaceError.invalidRepositoryName
        }
    }
}

// MARK: - Error Types

public enum MiseEnPlaceError: Error, LocalizedError, Equatable {
    case missingRepositoryName
    case invalidRepositoryName
    case fileNotFound(String)
    case githubAPIError(String)

    public var errorDescription: String? {
        switch self {
        case .missingRepositoryName:
            return "Repository name is required. Usage: swift run MiseEnPlace <repository-name>"
        case .invalidRepositoryName:
            return "Invalid repository name. Must be lowercase, no spaces, no slashes, and 1-100 characters long."
        case .fileNotFound(let path):
            return "File not found at path: \(path)"
        case .githubAPIError(let message):
            return "GitHub API error: \(message)"
        }
    }
}
