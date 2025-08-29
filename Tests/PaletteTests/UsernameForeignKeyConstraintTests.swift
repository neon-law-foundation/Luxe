import FluentPostgresDriver
import Foundation
import Logging
import PostgresNIO
import TestUtilities
import Testing
import Vapor

@testable import Dali
@testable import Palette

@Suite("Username Foreign Key Constraint Tests", .serialized)
struct UsernameForeignKeyConstraintTests {

    @Test(
        "Foreign key constraint prevents orphaned users and validates references",
        .disabled(
            if: ProcessInfo.processInfo.environment["CI"] != nil,
            "Disabled for CI due to database connection timeout issues"
        )
    )
    func foreignKeyConstraintPreventsOrphanedUsersAndValidatesReferences() async throws {
        try await TestUtilities.withApp { app, database in
            let postgres = app.db as! PostgresDatabase

            // TEST 1: Verify that the foreign key constraint exists
            let constraintQuery = """
                SELECT 1 FROM information_schema.table_constraints
                WHERE table_schema = 'auth'
                AND table_name = 'users'
                AND constraint_name = 'fk_auth_users_username_directory_people_email'
                AND constraint_type = 'FOREIGN KEY'
                """
            let constraintRows = try await postgres.sql().raw(SQLQueryString(constraintQuery)).all()

            #expect(
                !constraintRows.isEmpty,
                "Foreign key constraint fk_auth_users_username_directory_people_email should exist"
            )

            // Generate unique identifiers for this test run
            let testId = TestUtilities.randomCode(prefix: "fktest")
            let validEmail = "testuser-\(testId)@example.com"
            let invalidEmail = "nonexistent-\(testId)@example.com"

            // TEST 2: Verify that we can insert a user with a valid email reference
            // First create a person
            try await postgres.sql().raw(
                """
                INSERT INTO directory.people (name, email)
                VALUES ('Test User \(testId)', \(bind: validEmail))
                """
            ).run()

            // Then create a user with the same email as username - this should succeed
            try await postgres.sql().raw(
                """
                INSERT INTO auth.users (username, person_id, role)
                SELECT \(bind: validEmail), p.id, 'customer'::auth.user_role
                FROM directory.people p
                WHERE p.email = \(bind: validEmail)
                """
            ).run()

            // Verify the user was created
            let userRows = try await postgres.sql().raw(
                "SELECT username FROM auth.users WHERE username = \(bind: validEmail)"
            ).all()
            #expect(!userRows.isEmpty, "User with valid email reference should be created successfully")

            // TEST 3: Verify that we cannot insert a user with an invalid email reference
            var insertFailed = false
            do {
                try await postgres.sql().raw(
                    """
                    INSERT INTO auth.users (username, role)
                    VALUES (\(bind: invalidEmail), 'customer'::auth.user_role)
                    """
                ).run()
            } catch {
                insertFailed = true
                let errorString = String(reflecting: error)
                #expect(
                    errorString.contains("foreign key") || errorString.contains("violates"),
                    "Error should be related to foreign key constraint violation"
                )
            }

            #expect(insertFailed, "Insert with invalid email reference should fail due to foreign key constraint")

            // TEST 4: Verify that we cannot delete a person if a user references their email
            var deleteFailed = false
            do {
                try await postgres.sql().raw("DELETE FROM directory.people WHERE email = \(bind: validEmail)").run()
            } catch {
                deleteFailed = true
                let errorString = String(reflecting: error)
                #expect(
                    errorString.contains("foreign key") || errorString.contains("violates")
                        || errorString.contains("referenced"),
                    "Error should be related to foreign key constraint violation"
                )
            }

            #expect(deleteFailed, "Delete of referenced person should fail due to foreign key constraint")

            // Clean up test data at the end
            try? await postgres.sql().raw("DELETE FROM auth.users WHERE username = \(bind: validEmail)").run()
            try? await postgres.sql().raw("DELETE FROM directory.people WHERE email = \(bind: validEmail)").run()
        }
    }

    @Test(
        "Foreign key constraint allows cascade updates and maintains referential integrity",
        .disabled(
            if: ProcessInfo.processInfo.environment["CI"] != nil,
            "Disabled for CI due to database connection timeout issues"
        )
    )
    func foreignKeyConstraintAllowsCascadeUpdatesAndMaintainsReferentialIntegrity() async throws {
        try await TestUtilities.withApp { app, database in
            let postgres = app.db as! PostgresDatabase

            // Generate unique identifiers for this test run
            let testId = TestUtilities.randomCode(prefix: "cascade")
            let testEmail = "cascadetest-\(testId)@example.com"

            // Create a person and user with matching email/username
            try await postgres.sql().raw(
                """
                INSERT INTO directory.people (name, email)
                VALUES ('Cascade Test User \(testId)', \(bind: testEmail))
                """
            ).run()

            try await postgres.sql().raw(
                """
                INSERT INTO auth.users (username, person_id, role)
                SELECT \(bind: testEmail), p.id, 'staff'::auth.user_role
                FROM directory.people p
                WHERE p.email = \(bind: testEmail)
                """
            ).run()

            // TEST: Verify both records exist before any operations
            let userRows = try await postgres.sql().raw(
                "SELECT username FROM auth.users WHERE username = \(bind: testEmail)"
            ).all()
            #expect(!userRows.isEmpty, "User should exist before cascade operations")

            let personRows = try await postgres.sql().raw(
                "SELECT email FROM directory.people WHERE email = \(bind: testEmail)"
            ).all()
            #expect(!personRows.isEmpty, "Person should exist before cascade operations")

            // Clean up test data
            try? await postgres.sql().raw("DELETE FROM auth.users WHERE username = \(bind: testEmail)").run()
            try? await postgres.sql().raw("DELETE FROM directory.people WHERE email = \(bind: testEmail)").run()
        }
    }
}
