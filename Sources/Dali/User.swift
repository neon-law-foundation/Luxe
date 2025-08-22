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

public final class User: Model, Content, @unchecked Sendable {
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
