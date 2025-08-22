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

@Suite("Invoice Tests", .serialized)
struct InvoiceTests {

    @Test("Invoice has required fields")
    func invoiceHasRequiredFields() async throws {
        // Create a test invoice
        let vendorId = UUID()
        let sentDate = Date()
        let invoice = Invoice(vendorID: vendorId, invoicedFrom: .neonLaw, invoicedAmount: 150000, sentAt: sentDate)

        // Verify the model has all required fields
        #expect(invoice.$vendor.id == vendorId)
        #expect(invoice.invoicedFrom == .neonLaw)
        #expect(invoice.invoicedAmount == 150000)
        #expect(invoice.sentAt == sentDate)

        // ID should be nil before saving
        #expect(invoice.id == nil)

        // Timestamps should be nil before saving
        #expect(invoice.createdAt == nil)
        #expect(invoice.updatedAt == nil)
    }

    @Test("InvoicedFrom enum has all expected values")
    func invoicedFromEnumHasAllExpectedValues() async throws {
        let allCases = InvoicedFrom.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.neonLaw))
        #expect(allCases.contains(.neonLawFoundation))
        #expect(allCases.contains(.sagebrushServices))

        // Verify raw values match database constraints
        #expect(InvoicedFrom.neonLaw.rawValue == "neon_law")
        #expect(InvoicedFrom.neonLawFoundation.rawValue == "neon_law_foundation")
        #expect(InvoicedFrom.sagebrushServices.rawValue == "sagebrush_services")
    }

    @Test("Invoice can be saved with valid vendor reference")
    func invoiceCanBeSavedWithValidVendorReference() async throws {
        try await TestUtilities.withApp { app, database in

            // First verify the table exists with raw SQL
            let countResult = try await (app.db as! PostgresDatabase).sql()
                .raw("SELECT COUNT(*) as count FROM accounting.invoices")
                .first()

            #expect(countResult != nil)
            print("Database connection verified - accounting.invoices table accessible")

            // Create a test person first
            let uniqueEmail = "invoice.vendor.\(UUID().uuidString)@example.com"
            let personInsertResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO directory.people (name, email, created_at, updated_at)
                    VALUES (\(bind: "Invoice Vendor Person"), \(bind: uniqueEmail), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id
                    """
                )
                .first()

            guard let personResult = personInsertResult,
                let personId = try? personResult.decode(column: "id", as: UUID.self)
            else {
                Issue.record("Failed to create test person")
                return
            }

            // Create a test vendor referencing the person
            let uniqueVendorName = "Invoice Vendor \(UniqueCodeGenerator.generateISOCode(prefix: "IVND"))"
            let vendorInsertResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO accounting.vendors (name, entity_id, person_id, created_at, updated_at)
                    VALUES (\(bind: uniqueVendorName), NULL, \(bind: personId), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id
                    """
                )
                .first()

            guard let vendorResult = vendorInsertResult,
                let vendorId = try? vendorResult.decode(column: "id", as: UUID.self)
            else {
                Issue.record("Failed to create test vendor")
                return
            }

            // Create a test invoice
            let sentAt = Date()
            let invoiceInsertResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO accounting.invoices (vendor_id, invoiced_from, invoiced_amount, sent_at, created_at, updated_at)
                    VALUES (\(bind: vendorId), \(bind: "neon_law"), \(bind: 250000), \(bind: sentAt), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id
                    """
                )
                .first()

            #expect(invoiceInsertResult != nil)

            if let result = invoiceInsertResult {
                let invoiceId = try result.decode(column: "id", as: UUID.self)
                print("Successfully saved Invoice with ID: \(invoiceId)")
            }
        }
    }

    @Test("Invoice enforces positive amount constraint")
    func invoiceEnforcesPositiveAmountConstraint() async throws {
        try await TestUtilities.withApp { app, database in

            // Create a test person first
            let uniqueEmail = "constraint.vendor.\(UUID().uuidString)@example.com"
            let personInsertResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO directory.people (name, email, created_at, updated_at)
                    VALUES (\(bind: "Constraint Vendor Person"), \(bind: uniqueEmail), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id
                    """
                )
                .first()

            guard let personResult = personInsertResult,
                let personId = try? personResult.decode(column: "id", as: UUID.self)
            else {
                Issue.record("Failed to create test person")
                return
            }

            // Create a test vendor referencing the person
            let uniqueVendorName = "Constraint Vendor \(UniqueCodeGenerator.generateISOCode(prefix: "CNTV"))"
            let vendorInsertResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO accounting.vendors (name, entity_id, person_id, created_at, updated_at)
                    VALUES (\(bind: uniqueVendorName), NULL, \(bind: personId), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id
                    """
                )
                .first()

            guard let vendorResult = vendorInsertResult,
                let vendorId = try? vendorResult.decode(column: "id", as: UUID.self)
            else {
                Issue.record("Failed to create test vendor")
                return
            }

            // Try to insert invoice with negative amount - this should fail
            do {
                let _ = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO accounting.invoices (vendor_id, invoiced_from, invoiced_amount, sent_at, created_at, updated_at)
                        VALUES (\(bind: vendorId), \(bind: "neon_law"), \(bind: -1000), \(bind: Date()), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        """
                    )
                    .first()

                Issue.record("Expected constraint violation but insert succeeded")
            } catch {
                // This is expected - the constraint should prevent the insert
                print("Constraint successfully prevented negative amount: \(error)")
            }

            // Try to insert invoice with zero amount - this should also fail
            do {
                let _ = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO accounting.invoices (vendor_id, invoiced_from, invoiced_amount, sent_at, created_at, updated_at)
                        VALUES (\(bind: vendorId), \(bind: "neon_law"), \(bind: 0), \(bind: Date()), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        """
                    )
                    .first()

                Issue.record("Expected constraint violation but insert succeeded")
            } catch {
                // This is expected - the constraint should prevent the insert
                print("Constraint successfully prevented zero amount: \(error)")
            }
        }
    }

    @Test("Invoice enforces invoiced_from constraint")
    func invoiceEnforcesInvoicedFromConstraint() async throws {
        try await TestUtilities.withApp { app, database in

            // Create a test person first
            let uniqueEmail = "enum.vendor.\(UUID().uuidString)@example.com"
            let personInsertResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO directory.people (name, email, created_at, updated_at)
                    VALUES (\(bind: "Enum Vendor Person"), \(bind: uniqueEmail), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id
                    """
                )
                .first()

            guard let personResult = personInsertResult,
                let personId = try? personResult.decode(column: "id", as: UUID.self)
            else {
                Issue.record("Failed to create test person")
                return
            }

            // Create a test vendor referencing the person
            let uniqueVendorName = "Enum Vendor \(UniqueCodeGenerator.generateISOCode(prefix: "ENUMV"))"
            let vendorInsertResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO accounting.vendors (name, entity_id, person_id, created_at, updated_at)
                    VALUES (\(bind: uniqueVendorName), NULL, \(bind: personId), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id
                    """
                )
                .first()

            guard let vendorResult = vendorInsertResult,
                let vendorId = try? vendorResult.decode(column: "id", as: UUID.self)
            else {
                Issue.record("Failed to create test vendor")
                return
            }

            // Test valid invoiced_from values
            let validValues = ["neon_law", "neon_law_foundation", "sagebrush_services"]

            for value in validValues {
                let invoiceInsertResult = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO accounting.invoices (vendor_id, invoiced_from, invoiced_amount, sent_at, created_at, updated_at)
                        VALUES (\(bind: vendorId), \(bind: value), \(bind: 100000), \(bind: Date()), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        RETURNING id
                        """
                    )
                    .first()

                #expect(invoiceInsertResult != nil)
                print("Valid invoiced_from '\(value)' accepted")
            }

            // Try to insert invoice with invalid invoiced_from - this should fail
            do {
                let _ = try await (app.db as! PostgresDatabase).sql()
                    .raw(
                        """
                        INSERT INTO accounting.invoices (vendor_id, invoiced_from, invoiced_amount, sent_at, created_at, updated_at)
                        VALUES (\(bind: vendorId), \(bind: "invalid_company"), \(bind: 100000), \(bind: Date()), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                        """
                    )
                    .first()

                Issue.record("Expected constraint violation but insert succeeded")
            } catch {
                // This is expected - the constraint should prevent the insert
                print("Constraint successfully prevented invalid invoiced_from: \(error)")
            }
        }
    }

    @Test("Invoice can query relationship to vendor")
    func invoiceCanQueryRelationshipToVendor() async throws {
        try await TestUtilities.withApp { app, database in

            // Create a test person first
            let uniqueEmail = "relationship.vendor.\(UUID().uuidString)@example.com"
            let personInsertResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO directory.people (name, email, created_at, updated_at)
                    VALUES (\(bind: "Relationship Vendor Person"), \(bind: uniqueEmail), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id
                    """
                )
                .first()

            guard let personResult = personInsertResult,
                let personId = try? personResult.decode(column: "id", as: UUID.self)
            else {
                Issue.record("Failed to create test person")
                return
            }

            // Create a test vendor referencing the person
            let uniqueVendorName = "Relationship Vendor \(UniqueCodeGenerator.generateISOCode(prefix: "RELV"))"
            let vendorInsertResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO accounting.vendors (name, entity_id, person_id, created_at, updated_at)
                    VALUES (\(bind: uniqueVendorName), NULL, \(bind: personId), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id
                    """
                )
                .first()

            guard let vendorResult = vendorInsertResult,
                let vendorId = try? vendorResult.decode(column: "id", as: UUID.self)
            else {
                Issue.record("Failed to create test vendor")
                return
            }

            // Create and insert a test invoice
            let sentAt = Date()
            let invoiceInsertResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    INSERT INTO accounting.invoices (vendor_id, invoiced_from, invoiced_amount, sent_at, created_at, updated_at)
                    VALUES (\(bind: vendorId), \(bind: "sagebrush_services"), \(bind: 350000), \(bind: sentAt), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
                    RETURNING id
                    """
                )
                .first()

            guard let invoiceResult = invoiceInsertResult,
                let invoiceId = try? invoiceResult.decode(column: "id", as: UUID.self)
            else {
                Issue.record("Failed to create test invoice")
                return
            }

            // Query the invoice with its vendor information
            let queryResult = try await (app.db as! PostgresDatabase).sql()
                .raw(
                    """
                    SELECT i.invoiced_from, i.invoiced_amount, i.sent_at, v.name as vendor_name
                    FROM accounting.invoices i
                    JOIN accounting.vendors v ON i.vendor_id = v.id
                    WHERE i.id = \(bind: invoiceId)
                    """
                )
                .first()

            #expect(queryResult != nil)

            if let result = queryResult {
                let invoicedFrom = try result.decode(column: "invoiced_from", as: String.self)
                let invoicedAmount = try result.decode(column: "invoiced_amount", as: Int64.self)
                let vendorName = try result.decode(column: "vendor_name", as: String.self)

                #expect(invoicedFrom == "sagebrush_services")
                #expect(invoicedAmount == 350000)
                #expect(vendorName == uniqueVendorName)

                print(
                    "Invoice relationship query successful: \(vendorName) invoice for $\(Double(invoicedAmount)/100.0) from \(invoicedFrom)"
                )
            }
        }
    }
}
