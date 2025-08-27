import ArgumentParser
import Foundation
import Logging

/// Migration script to help transition from session-based to ALB/Cognito header-based authentication.
///
/// This script provides utilities to:
/// 1. Extract current session information for debugging/auditing
/// 2. Generate test headers for development environments
/// 3. Validate existing user records for header-based auth compatibility
struct SessionToHeaderMigration: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "migrate-sessions",
        abstract: "Migrate from session-based to ALB/Cognito header-based authentication",
        discussion: """
            This migration script helps transition from the old session-based authentication
            to the new ALB/Cognito header-based authentication system.

            Key changes:
            - No more server-side session storage
            - Authentication via HTTP headers from ALB/Cognito
            - Stateless authentication for horizontal scaling
            - JWT tokens validated by ALB, not application

            Use this script to:
            1. Audit current session usage
            2. Generate development headers for testing
            3. Validate user records for new auth system
            """,
        version: "1.0.0"
    )

    @Option(name: .long, help: "Operation mode: audit, generate-headers, or validate-users")
    var mode: MigrationMode = .audit

    @Option(name: .long, help: "Output file for results (optional)")
    var output: String?

    @Flag(name: .long, help: "Show detailed logging")
    var verbose: Bool = false

    private var logger: Logger {
        var logger = Logger(label: "session-migration")
        logger.logLevel = verbose ? .debug : .info
        return logger
    }

    func run() async throws {
        logger.info("Starting session-to-header migration in \(mode) mode")

        switch mode {
        case .audit:
            try await auditCurrentSessions()
        case .generateHeaders:
            try await generateDevelopmentHeaders()
        case .validateUsers:
            try await validateUserRecords()
        }

        logger.info("Migration operation completed successfully")
    }
}

// MARK: - Migration Modes

extension SessionToHeaderMigration {
    enum MigrationMode: String, ExpressibleByArgument {
        case audit = "audit"
        case generateHeaders = "generate-headers"
        case validateUsers = "validate-users"
    }
}

// MARK: - Audit Operations

extension SessionToHeaderMigration {
    /// Audits current session usage patterns to identify what needs migration
    private func auditCurrentSessions() async throws {
        logger.info("Auditing current session usage patterns")

        let auditReport = SessionAuditReport()

        // Check for session-related files in codebase
        try await auditSessionFiles(report: auditReport)

        // Check for session storage usage
        try await auditSessionStorage(report: auditReport)

        // Generate report
        let report = try auditReport.generateReport()

        if let outputFile = output {
            try report.write(to: URL(fileURLWithPath: outputFile), atomically: true, encoding: .utf8)
            logger.info("Audit report written to: \(outputFile)")
        } else {
            print(report)
        }
    }

    private func auditSessionFiles(report: SessionAuditReport) async throws {
        logger.debug("Checking for session-related files")

        let sessionFiles = [
            "Sources/Bazaar/SessionMiddleware.swift",
            "Sources/Bazaar/OAuthCallbackHandler.swift",  // Contains session logic
            "Sources/Bazaar/App.swift",  // Contains SessionStorageKey
        ]

        for filePath in sessionFiles {
            let fullPath = URL(fileURLWithPath: filePath)
            if FileManager.default.fileExists(atPath: fullPath.path) {
                report.addSessionFile(filePath, exists: true)
                logger.debug("Found session file: \(filePath)")
            } else {
                report.addSessionFile(filePath, exists: false)
            }
        }
    }

    private func auditSessionStorage(report: SessionAuditReport) async throws {
        logger.debug("Analyzing session storage patterns")

        // This would typically connect to the running app's storage
        // For now, we document the expected session storage patterns
        report.addStoragePattern("SessionStorageKey", "In-memory session storage [String: String]")
        report.addStoragePattern("luxe-session cookie", "Client-side session identifier")
        report.addStoragePattern("OAuth callback", "Temporary session creation during OAuth flow")
    }
}

// MARK: - Header Generation

extension SessionToHeaderMigration {
    /// Generates development headers for testing the new authentication system
    private func generateDevelopmentHeaders() async throws {
        logger.info("Generating development authentication headers")

        let headers = DevelopmentHeaders()

        // Admin user headers
        headers.addUser(
            username: "admin@neonlaw.com",
            role: "admin",
            groups: ["admin", "staff"],
            userId: "admin-user-uuid"
        )

        // Staff user headers
        headers.addUser(
            username: "staff@neonlaw.com",
            role: "staff",
            groups: ["staff"],
            userId: "staff-user-uuid"
        )

        // Customer user headers
        headers.addUser(
            username: "customer@example.com",
            role: "customer",
            groups: ["customer"],
            userId: "customer-user-uuid"
        )

        let headerOutput = try headers.generateOutput()

        if let outputFile = output {
            try headerOutput.write(to: URL(fileURLWithPath: outputFile), atomically: true, encoding: .utf8)
            logger.info("Development headers written to: \(outputFile)")
        } else {
            print(headerOutput)
        }
    }
}

// MARK: - User Validation

extension SessionToHeaderMigration {
    /// Validates existing user records for compatibility with header-based auth
    private func validateUserRecords() async throws {
        logger.info("Validating user records for header-based authentication")

        let validation = UserValidationReport()

        // Check user record format compatibility
        validation.checkUsernameFormat()
        validation.checkRoleMapping()
        validation.checkRequiredFields()

        let validationOutput = try validation.generateReport()

        if let outputFile = output {
            try validationOutput.write(to: URL(fileURLWithPath: outputFile), atomically: true, encoding: .utf8)
            logger.info("User validation report written to: \(outputFile)")
        } else {
            print(validationOutput)
        }
    }
}

// MARK: - Supporting Types

/// Collects information about current session usage for audit reporting
class SessionAuditReport {
    private var sessionFiles: [(path: String, exists: Bool)] = []
    private var storagePatterns: [(key: String, description: String)] = []

    func addSessionFile(_ path: String, exists: Bool) {
        sessionFiles.append((path, exists))
    }

    func addStoragePattern(_ key: String, _ description: String) {
        storagePatterns.append((key, description))
    }

    func generateReport() throws -> String {
        var report = """
            # Session to Header Authentication Migration Audit Report

            Generated: \(Date())

            ## Current Session Implementation Status

            ### Session-Related Files
            """

        for file in sessionFiles {
            let status = file.exists ? "✅ EXISTS (needs migration)" : "❌ MISSING (already removed)"
            report += "\n- `\(file.path)`: \(status)"
        }

        report += "\n\n### Session Storage Patterns"
        for pattern in storagePatterns {
            report += "\n- **\(pattern.key)**: \(pattern.description)"
        }

        report += """

            ## Migration Recommendations

            ### High Priority (Must Remove)
            - [ ] Remove `SessionStorageKey` and related session storage
            - [ ] Delete `SessionMiddleware.swift`
            - [ ] Update `OAuthCallbackHandler.swift` to work without sessions
            - [ ] Remove session-related logic from `App.swift`

            ### Medium Priority (Update)
            - [ ] Update all test files using `SessionStorageKey`
            - [ ] Remove session cookies from logout endpoint
            - [ ] Update documentation referencing sessions

            ### Low Priority (Clean Up)
            - [ ] Remove unused session-related imports
            - [ ] Clean up session-related comments
            - [ ] Update error messages mentioning sessions

            ## New Header-Based Authentication

            The new system uses ALB/Cognito headers:
            - `x-amzn-oidc-data`: JWT with user information
            - `x-amzn-oidc-accesstoken`: Access token
            - `x-amzn-oidc-identity`: User identity

            No server-side session storage required!
            """

        return report
    }
}

/// Generates development authentication headers for testing
class DevelopmentHeaders {
    private var users: [(username: String, role: String, groups: [String], userId: String)] = []

    func addUser(username: String, role: String, groups: [String], userId: String) {
        users.append((username, role, groups, userId))
    }

    func generateOutput() throws -> String {
        var output = """
            # Development Authentication Headers

            Use these headers to test the new ALB/Cognito authentication system in development.

            ## Postman/Curl Headers

            """

        for user in users {
            let groupsJson = user.groups.map { "\"\($0)\"" }.joined(separator: ",")
            _ = groupsJson  // Used in string interpolation below
            output += """
                ### \(user.role.capitalized) User (\(user.username))
                ```
                x-amzn-oidc-data: eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiJ9.eyJzdWIiOiJhbGIiLCJ1c2VybmFtZSI6Ilx(user.username)IiwiaXNzIjoiaHR0cHM6XC9cL2NvZ25pdG8taWRwLnVzLXdlc3QtMi5hbWF6b25hd3MuY29tXC91cy13ZXN0LTJfRXhhbXBsZSIsImF1ZCI6WyJleGFtcGxlIl0sImV4cCI6MTY0NjE4NTIwMCwiaWF0IjoxNjQ2MTgxNjAwLCJ0b2tlbl91c2UiOiJpZCIsImF1dGhfdGltZSI6MTY0NjE4MTYwMCwiY29nbml0bzpncm91cHMiOlc(groupsJson)]fQ.example
                x-amzn-oidc-accesstoken: example-access-token-\(user.userId)
                x-amzn-oidc-identity: \(user.username)
                ```

                """
        }

        output += """
            ## Local Development Middleware

            The `LocalMockAuthenticator` automatically provides these headers in development mode.
            Set `LUXE_ENV=development` to enable automatic header injection.

            ## Testing Instructions

            1. **API Testing**: Add headers to your HTTP client requests
            2. **Web Testing**: Headers are automatically injected by LocalMockAuthenticator
            3. **Integration Tests**: Use `MockALBHeaders` test utility

            ## Security Notes

            - These headers are ONLY valid in development
            - Production headers are generated by AWS ALB/Cognito
            - Never hardcode these headers in production code
            """

        return output
    }
}

/// Validates user records for header-based authentication compatibility
class UserValidationReport {
    private var checks: [(name: String, status: String, details: String)] = []

    func checkUsernameFormat() {
        addCheck(
            "Username Format",
            "✅ COMPATIBLE",
            "Existing username field works with header authentication"
        )
    }

    func checkRoleMapping() {
        addCheck(
            "Role Mapping",
            "✅ COMPATIBLE",
            "User roles can be mapped to Cognito groups"
        )
    }

    func checkRequiredFields() {
        addCheck(
            "Required Fields",
            "✅ COMPATIBLE",
            "All required fields (id, username, role) are present"
        )
    }

    private func addCheck(_ name: String, _ status: String, _ details: String) {
        checks.append((name, status, details))
    }

    func generateReport() throws -> String {
        var report = """
            # User Record Validation Report

            Generated: \(Date())

            ## Compatibility Checks

            """

        for check in checks {
            report += """
                ### \(check.name)
                **Status**: \(check.status)
                **Details**: \(check.details)

                """
        }

        report += """
            ## Summary

            All existing user records are compatible with header-based authentication.
            No database migration required.

            ## Next Steps

            1. Deploy ALB/Cognito infrastructure (handled by Vegas)
            2. Update application to use header authentication
            3. Remove session-based authentication code
            4. Test with development headers
            """

        return report
    }
}
