import Dali
import Fluent
import Foundation
import Vapor

/// Service for working with Cognito user data and the auth.users table
public struct CognitoUserService {
    
    /// Represents Cognito data extracted from ALB headers (transient data structure)
    public struct CognitoData: Codable, Sendable {
        public let cognitoSub: String
        public let cognitoGroups: [String]
        public let username: String
        public let email: String
        public let name: String?
        public let albHeaders: [String: String]
        
        public init(
            cognitoSub: String,
            cognitoGroups: [String],
            username: String,
            email: String,
            name: String? = nil,
            albHeaders: [String: String] = [:]
        ) {
            self.cognitoSub = cognitoSub
            self.cognitoGroups = cognitoGroups
            self.username = username
            self.email = email
            self.name = name
            self.albHeaders = albHeaders
        }
        
        /// Determines the appropriate UserRole based on Cognito groups
        public var userRole: UserRole {
            User.roleFromCognitoGroups(cognitoGroups)
        }
        
        /// Validates the Cognito data
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
            
            guard email.contains("@") else {
                throw ValidationError("Email must contain @ symbol")
            }
        }
    }
    
    /// Finds or creates a User in the auth.users table based on Cognito data
    public static func findOrCreateUser(
        from cognitoData: CognitoData,
        database: Database
    ) async throws -> User {
        try cognitoData.validate()
        
        // Try to find existing user by cognito sub first
        if let existingUser = try await User.query(on: database)
            .filter(\User.$sub == cognitoData.cognitoSub)
            .first() {
            
            // Update role if it has changed based on current groups
            existingUser.updateRoleFromCognitoGroups(cognitoData.cognitoGroups)
            
            // Update username if it has changed (email might have changed)
            if existingUser.username != cognitoData.username {
                existingUser.username = cognitoData.username
            }
            
            try await existingUser.save(on: database)
            return existingUser
        }
        
        // Try to find existing user by username/email
        if let existingUser = try await User.query(on: database)
            .filter(\User.$username == cognitoData.username)
            .first() {
            
            // Update with Cognito sub if it was missing
            if existingUser.sub == nil {
                existingUser.sub = cognitoData.cognitoSub
            }
            
            // Update role based on groups
            existingUser.updateRoleFromCognitoGroups(cognitoData.cognitoGroups)
            
            try await existingUser.save(on: database)
            return existingUser
        }
        
        // Create new user in auth.users table
        let newUser = User(
            username: cognitoData.username,
            sub: cognitoData.cognitoSub,
            role: cognitoData.userRole
        )
        
        try await newUser.save(on: database)
        return newUser
    }
    
    /// Updates an existing User's role based on current Cognito groups
    public static func updateUserRole(
        user: User,
        cognitoGroups: [String],
        database: Database
    ) async throws -> User {
        user.updateRoleFromCognitoGroups(cognitoGroups)
        try await user.save(on: database)
        return user
    }
    
    /// Validates that a User's role matches their Cognito groups
    public static func validateUserRole(
        user: User,
        cognitoGroups: [String]
    ) -> Bool {
        user.validateRoleMatchesCognitoGroups(cognitoGroups)
    }
}

// MARK: - User Extensions for Cognito Integration

extension User {
    /// Creates logging data for audit purposes (excludes sensitive information)
    public func createAuditLogData(
        cognitoGroups: [String] = [],
        requestPath: String,
        albHeaderCount: Int = 0
    ) -> [String: Any] {
        [
            "user_id": id?.uuidString ?? "unknown",
            "cognito_sub": sub ?? "unknown",
            "cognito_groups": cognitoGroups,
            "username": username,
            "role": role.rawValue,
            "request_path": requestPath,
            "alb_headers_count": albHeaderCount,
            "created_at": createdAt?.ISO8601Format() ?? "unknown"
        ]
    }
    
    /// Checks if user has appropriate access for Cognito groups
    public func hasAppropriateCognitoAccess(_ cognitoGroups: [String]) -> Bool {
        let expectedRole = User.roleFromCognitoGroups(cognitoGroups)
        return role.accessLevel >= expectedRole.accessLevel
    }
}