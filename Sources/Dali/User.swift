import Fluent
import Foundation
import Vapor

public enum UserRole: String, Codable, CaseIterable, Sendable {
    case customer
    case staff
    case admin

    public var displayName: String {
        switch self {
        case .customer: return "Customer"
        case .staff: return "Staff"
        case .admin: return "Admin"
        }
    }

    public var accessLevel: Int {
        switch self {
        case .customer: return 1
        case .staff: return 2
        case .admin: return 3
        }
    }
}

public final class User: Model, Content, Authenticatable, @unchecked Sendable {
    public static let schema = "users"
    public static let space = "auth"

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "username")
    public var username: String

    @OptionalField(key: "sub")
    public var sub: String?

    @Field(key: "role")
    public var role: UserRole

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    // Optional parent relationship to Person
    @OptionalParent(key: "person_id")
    public var person: Person?

    public init() {}

    public init(id: UUID? = nil, username: String, sub: String? = nil, role: UserRole = .staff) {
        self.id = id
        self.username = username
        self.sub = sub
        self.role = role
    }

    public func validate() throws {
        guard !username.isEmpty else {
            throw ValidationError("Username cannot be empty")
        }

        guard username.count >= 3 else {
            throw ValidationError("Username must be at least 3 characters long")
        }

        guard username.count <= 255 else {
            throw ValidationError("Username cannot be longer than 255 characters")
        }

        // Validate sub field if provided
        if let sub = sub {
            guard !sub.isEmpty else {
                throw ValidationError("Sub cannot be empty when provided")
            }

            guard sub.count <= 255 else {
                throw ValidationError("Sub cannot be longer than 255 characters")
            }
        }

        // Role validation is implicit since it's an enum
        guard UserRole.allCases.contains(role) else {
            throw ValidationError("Invalid user role")
        }
    }

    // MARK: - Role-based authorization helpers

    public func hasRole(_ requiredRole: UserRole) -> Bool {
        role.accessLevel >= requiredRole.accessLevel
    }

    public func isCustomer() -> Bool {
        role == .customer
    }

    public func isStaff() -> Bool {
        role == .staff
    }

    public func isAdmin() -> Bool {
        role == .admin
    }

    public func canAccessStaffFeatures() -> Bool {
        hasRole(.staff)
    }

    public func canAccessAdminFeatures() -> Bool {
        hasRole(.admin)
    }

    // MARK: - Cognito Groups Mapping

    /// Maps Cognito groups to UserRole, prioritizing highest access level
    public static func roleFromCognitoGroups(_ cognitoGroups: [String]) -> UserRole {
        // Check for admin groups first (highest priority)
        if cognitoGroups.contains(where: { isAdminGroup($0) }) {
            return .admin
        }

        // Check for staff groups
        if cognitoGroups.contains(where: { isStaffGroup($0) }) {
            return .staff
        }

        // Default to customer for any other groups or no groups
        return .customer
    }

    /// Determines if a Cognito group indicates admin access
    private static func isAdminGroup(_ group: String) -> Bool {
        let adminGroups = [
            "admin",
            "administrators",
            "superadmin",
            "super-admin",
            "system-admin",
            "luxe-admin",
        ]
        return adminGroups.contains(group.lowercased())
    }

    /// Determines if a Cognito group indicates staff access
    private static func isStaffGroup(_ group: String) -> Bool {
        let staffGroups = [
            "staff",
            "employees",
            "team",
            "lawyers",
            "attorneys",
            "paralegals",
            "luxe-staff",
        ]
        return staffGroups.contains(group.lowercased())
    }

    /// Updates user role based on current Cognito groups
    public func updateRoleFromCognitoGroups(_ cognitoGroups: [String]) {
        let newRole = User.roleFromCognitoGroups(cognitoGroups)

        // Only update if role has changed to avoid unnecessary database writes
        if self.role != newRole {
            self.role = newRole
        }
    }

    /// Validates that user's role is appropriate for their Cognito groups
    public func validateRoleMatchesCognitoGroups(_ cognitoGroups: [String]) -> Bool {
        let expectedRole = User.roleFromCognitoGroups(cognitoGroups)
        return self.role == expectedRole
    }
}

public struct ValidationError: Error, LocalizedError {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? {
        message
    }
}
