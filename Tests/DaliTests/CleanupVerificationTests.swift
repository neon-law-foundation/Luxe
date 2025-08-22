import Fluent
import FluentPostgresDriver
import Foundation
import Logging
import PostgresNIO
import ServiceLifecycle
import TestUtilities
import Testing
import Vapor

@testable import Dali
@testable import Palette

@Suite("Cleanup Verification Tests", .serialized)
struct CleanupVerificationTests {

    @Test(
        "Transaction rollback cleans up created records",
        .disabled("Transaction isolation data persistence issues - needs investigation")
    )
    func transactionRollbackCleansUpCreatedRecords() async throws {
        // First, get a baseline count of records
        let initialCounts = try await TestUtilities.withApp { app, database in
            let userCount = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM auth.users")
                .first()
            let personCount = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM directory.people")
                .first()
            let entityCount = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM directory.entities")
                .first()

            guard let userResult = userCount,
                let personResult = personCount,
                let entityResult = entityCount
            else {
                throw DatabaseError.invalidResult("Failed to get initial counts")
            }

            return (
                users: try userResult.decode(column: "count", as: Int.self),
                people: try personResult.decode(column: "count", as: Int.self),
                entities: try entityResult.decode(column: "count", as: Int.self)
            )
        }

        // Now create records in a transaction that should roll back
        try await TestUtilities.withApp { app, database in
            // Create a person
            let personEmail = "cleanup_test_\(UniqueCodeGenerator.generateISOCode(prefix: "test"))@example.com"
            let personResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO directory.people (name, email, created_at, updated_at)
                    VALUES (\(bind: "Cleanup Test Person"), \(bind: personEmail), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id
                    """
                )
                .first()

            #expect(personResult != nil)

            if let personResult = personResult {
                let personId = try personResult.decode(column: "id", as: UUID.self)

                // Create a user
                let username = personEmail
                let userResult = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO auth.users (username, person_id, created_at, updated_at)
                        VALUES (\(bind: username), \(bind: personId), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        RETURNING id
                        """
                    )
                    .first()

                #expect(userResult != nil)
            }
        }

        // Verify counts are back to original after rollback
        let finalCounts = try await TestUtilities.withApp { app, database in
            let userCount = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM auth.users")
                .first()
            let personCount = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM directory.people")
                .first()
            let entityCount = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM directory.entities")
                .first()

            guard let userResult = userCount,
                let personResult = personCount,
                let entityResult = entityCount
            else {
                throw DatabaseError.invalidResult("Failed to get final counts")
            }

            return (
                users: try userResult.decode(column: "count", as: Int.self),
                people: try personResult.decode(column: "count", as: Int.self),
                entities: try entityResult.decode(column: "count", as: Int.self)
            )
        }

        // Assert that counts are identical (rollback worked)
        #expect(initialCounts.users == finalCounts.users, "User count should be unchanged after rollback")
        #expect(initialCounts.people == finalCounts.people, "Person count should be unchanged after rollback")
        #expect(initialCounts.entities == finalCounts.entities, "Entity count should be unchanged after rollback")
    }

    @Test(
        "Multiple test runs do not accumulate data",
        .disabled("Transaction isolation data persistence issues - needs investigation")
    )
    func multipleTestRunsDoNotAccumulateData() async throws {
        // Run the same test pattern multiple times and verify no data accumulation
        var runResults: [(users: Int, people: Int, entities: Int)] = []

        for i in 1...3 {
            let counts = try await TestUtilities.withApp { app, database in
                // Create some test data each time
                let personEmail =
                    "accumulation_test_\(i)_\(UniqueCodeGenerator.generateISOCode(prefix: "test"))@example.com"
                let personResult = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO directory.people (name, email, created_at, updated_at)
                        VALUES (\(bind: "Accumulation Test Person \(i)"), \(bind: personEmail), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        RETURNING id
                        """
                    )
                    .first()

                #expect(personResult != nil)

                // Check counts after each test run
                let userCount = try await (app.db as! PostgresDatabase).sql()
                    .raw("SELECT COUNT(*) as count FROM auth.users")
                    .first()
                let personCount = try await (app.db as! PostgresDatabase).sql()
                    .raw("SELECT COUNT(*) as count FROM directory.people")
                    .first()
                let entityCount = try await (app.db as! PostgresDatabase).sql()
                    .raw("SELECT COUNT(*) as count FROM directory.entities")
                    .first()

                guard let userResult = userCount,
                    let personResult = personCount,
                    let entityResult = entityCount
                else {
                    throw DatabaseError.invalidResult("Failed to get counts for run \(i)")
                }

                return (
                    users: try userResult.decode(column: "count", as: Int.self),
                    people: try personResult.decode(column: "count", as: Int.self),
                    entities: try entityResult.decode(column: "count", as: Int.self)
                )
            }

            runResults.append(counts)
        }

        // Verify all runs have identical counts (no accumulation)
        let firstRun = runResults[0]
        for (index, run) in runResults.enumerated() {
            #expect(run.users == firstRun.users, "User count should be identical across all runs (run \(index + 1))")
            #expect(
                run.people == firstRun.people,
                "Person count should be identical across all runs (run \(index + 1))"
            )
            #expect(
                run.entities == firstRun.entities,
                "Entity count should be identical across all runs (run \(index + 1))"
            )
        }
    }

    @Test(
        "Transaction rollback handles multiple table insertions",
        .disabled("Transaction isolation conflicts with TestUtilities framework - architecture issue")
    )
    func transactionRollbackHandlesMultipleTableInsertions() async throws {
        // Test that complex multi-table operations are fully rolled back
        let initialCounts = try await TestUtilities.withApp { app, database in
            let userCount = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM auth.users")
                .first()
            let personCount = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM directory.people")
                .first()

            guard let userResult = userCount,
                let personResult = personCount
            else {
                throw DatabaseError.invalidResult("Failed to get initial counts")
            }

            return (
                users: try userResult.decode(column: "count", as: Int.self),
                people: try personResult.decode(column: "count", as: Int.self)
            )
        }

        // Perform complex multi-table operations
        try await TestUtilities.withApp { app, database in
            // Create multiple people
            for i in 1...5 {
                let personEmail =
                    "multi_table_test_\(i)_\(UniqueCodeGenerator.generateISOCode(prefix: "test"))@example.com"
                let personResult = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO directory.people (name, email, created_at, updated_at)
                        VALUES (\(bind: "Multi Test Person \(i)"), \(bind: personEmail), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        RETURNING id
                        """
                    )
                    .first()

                #expect(personResult != nil)

                if let personResult = personResult {
                    let personId = try personResult.decode(column: "id", as: UUID.self)

                    // Create corresponding user
                    let userResult = try await (app.db as! PostgresDatabase).sql()
                        .raw(
                            """
                            INSERT INTO auth.users (username, person_id, created_at, updated_at)
                            VALUES (\(bind: personEmail), \(bind: personId), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                            RETURNING id
                            """
                        )
                        .first()

                    #expect(userResult != nil)
                }
            }

            // Verify records exist during transaction
            let duringUserCount = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM auth.users")
                .first()
            let duringPersonCount = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM directory.people")
                .first()

            guard let duringUserResult = duringUserCount,
                let duringPersonResult = duringPersonCount
            else {
                throw DatabaseError.invalidResult("Failed to get counts during transaction")
            }

            let currentUsers = try duringUserResult.decode(column: "count", as: Int.self)
            let currentPeople = try duringPersonResult.decode(column: "count", as: Int.self)

            // Should have increased by 5 each
            #expect(currentUsers >= initialCounts.users + 5, "User count should increase during transaction")
            #expect(currentPeople >= initialCounts.people + 5, "Person count should increase during transaction")
        }

        // Verify all changes were rolled back
        let finalCounts = try await TestUtilities.withApp { app, database in
            let userCount = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM auth.users")
                .first()
            let personCount = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM directory.people")
                .first()

            guard let userResult = userCount,
                let personResult = personCount
            else {
                throw DatabaseError.invalidResult("Failed to get final counts")
            }

            return (
                users: try userResult.decode(column: "count", as: Int.self),
                people: try personResult.decode(column: "count", as: Int.self)
            )
        }

        #expect(initialCounts.users == finalCounts.users, "User count should return to original after rollback")
        #expect(initialCounts.people == finalCounts.people, "Person count should return to original after rollback")
    }

    @Test(
        "withTransactionRollback isolated from regular database operations",
        .disabled("Transaction isolation data persistence issues - needs investigation")
    )
    func withTransactionRollbackIsolatedFromRegularDatabaseOperations() async throws {
        // This test verifies that operations in withTransactionRollback don't affect
        // operations outside the transaction rollback context

        // Get baseline counts
        let baseline = try await TestUtilities.withApp { app, database in
            let userCount = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM auth.users")
                .first()

            guard let userResult = userCount else {
                throw DatabaseError.invalidResult("Failed to get baseline count")
            }

            return try userResult.decode(column: "count", as: Int.self)
        }

        // Perform operations in transaction rollback - these should be rolled back
        try await TestUtilities.withApp { app, database in
            let personEmail = "isolation_test_\(UniqueCodeGenerator.generateISOCode(prefix: "test"))@example.com"

            // Create person and user that should be rolled back
            let personResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO directory.people (name, email, created_at, updated_at)
                    VALUES (\(bind: "Isolation Test Person"), \(bind: personEmail), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id
                    """
                )
                .first()

            #expect(personResult != nil)

            if let personResult = personResult {
                let personId = try personResult.decode(column: "id", as: UUID.self)

                let userResult = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO auth.users (username, person_id, created_at, updated_at)
                        VALUES (\(bind: personEmail), \(bind: personId), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        RETURNING id
                        """
                    )
                    .first()

                #expect(userResult != nil)
            }
        }

        // Check that counts are back to baseline (rollback worked)
        let afterRollback = try await TestUtilities.withApp { app, database in
            let userCount = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM auth.users")
                .first()

            guard let userResult = userCount else {
                throw DatabaseError.invalidResult("Failed to get after-rollback count")
            }

            return try userResult.decode(column: "count", as: Int.self)
        }

        #expect(baseline == afterRollback, "User count should be identical before and after rollback")
    }
}

// Custom error for database operations
enum DatabaseError: Error {
    case invalidResult(String)
}
