import Dali
import Foundation
import Vapor

/// Represents Cognito user information extracted from ALB headers
public struct CognitoUser: Codable, Content, Sendable {
    /// Cognito User Pool subject identifier (sub claim)
    public let cognitoSub: String

    /// Cognito groups the user belongs to
    public let cognitoGroups: [String]

    /// User's username/email from Cognito
    public let username: String

    /// User's email from Cognito
    public let email: String

    /// User's display name (optional)
    public let name: String?

    /// Raw ALB headers for debugging/audit purposes
    public let albHeaders: [String: String]

    /// Timestamp when this CognitoUser was created
    public let createdAt: Date

    public init(
        cognitoSub: String,
        cognitoGroups: [String],
        username: String,
        email: String,
        name: String? = nil,
        albHeaders: [String: String] = [:],
        createdAt: Date = Date()
    ) {
        self.cognitoSub = cognitoSub
        self.cognitoGroups = cognitoGroups
        self.username = username
        self.email = email
        self.name = name
        self.albHeaders = albHeaders
        self.createdAt = createdAt
    }
}

// MARK: - Validation Support

extension CognitoUser: Validatable {
    public static func validations(_ validations: inout Validations) {
        validations.add("cognitoSub", as: String.self, is: !.empty)
        validations.add("username", as: String.self, is: !.empty && .count(3...))
        validations.add("email", as: String.self, is: .email)
    }

    /// Validates the CognitoUser data
    public func validate() throws {
        guard !cognitoSub.isEmpty else {
            throw ValidationError("Cognito sub cannot be empty")
        }

        guard !username.isEmpty else {
            throw ValidationError("Username cannot be empty")
        }

        guard username.count >= 3 else {
            throw ValidationError("Username must be at least 3 characters")
        }

        guard !email.isEmpty else {
            throw ValidationError("Email cannot be empty")
        }

        // Basic email validation
        guard email.contains("@") else {
            throw ValidationError("Email must contain @ symbol")
        }
    }
}

// MARK: - User Role Mapping

extension CognitoUser {
    /// Determines the appropriate UserRole based on Cognito groups
    public var userRole: UserRole {
        User.roleFromCognitoGroups(cognitoGroups)
    }

    /// Checks if user has admin privileges
    public var isAdmin: Bool {
        userRole == .admin
    }

    /// Checks if user has staff privileges
    public var isStaff: Bool {
        userRole.accessLevel >= UserRole.staff.accessLevel
    }

    /// Gets all applicable roles for this user (hierarchical)
    public var applicableRoles: [UserRole] {
        let currentRole = userRole
        return UserRole.allCases.filter { $0.accessLevel <= currentRole.accessLevel }
    }
}

// MARK: - Debugging and Logging Support

extension CognitoUser {
    /// Returns a sanitized representation for logging (excludes sensitive ALB headers)
    public var loggingDescription: [String: Any] {
        [
            "cognito_sub": cognitoSub,
            "cognito_groups": cognitoGroups,
            "username": username,
            "email": email,
            "name": name ?? "nil",
            "user_role": userRole.rawValue,
            "created_at": ISO8601DateFormatter().string(from: createdAt),
        ]
    }

    /// Returns header names (not values) for debugging
    public var albHeaderNames: [String] {
        Array(albHeaders.keys).sorted()
    }
}
