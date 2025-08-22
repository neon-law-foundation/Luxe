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

@Suite("LawyerInquiry Model Tests", .serialized)
struct LawyerInquiryTests {
    @Test("LawyerInquiry can be created with required fields")
    func createWithRequiredFields() async throws {
        try await TestUtilities.withApp { app, database in
            let inquiry = LawyerInquiry(
                firmName: "Smith & Associates",
                contactName: "John Smith",
                email: "john@smithlaw.com"
            )

            try await inquiry.create(on: app.db)

            #expect(inquiry.id != nil)
            #expect(inquiry.firmName == "Smith & Associates")
            #expect(inquiry.contactName == "John Smith")
            #expect(inquiry.email == "john@smithlaw.com")
            #expect(inquiry.inquiryStatus == .new)
            #expect(inquiry.createdAt != nil)
            #expect(inquiry.updatedAt != nil)
        }
    }

    @Test("LawyerInquiry can be created with all fields")
    func createWithAllFields() async throws {
        try await TestUtilities.withApp { app, database in
            let inquiry = LawyerInquiry(
                firmName: "Nevada Legal Group",
                contactName: "Jane Doe",
                email: "jane@nevadalegal.com",
                nevadaBarMember: .yes,
                currentSoftware: "Clio",
                useCases: "Contract analysis, legal research",
                inquiryStatus: .new,
                notes: "High priority lead"
            )

            try await inquiry.create(on: app.db)

            #expect(inquiry.id != nil)
            #expect(inquiry.firmName == "Nevada Legal Group")
            #expect(inquiry.contactName == "Jane Doe")
            #expect(inquiry.email == "jane@nevadalegal.com")
            #expect(inquiry.nevadaBarMember == .yes)
            #expect(inquiry.currentSoftware == "Clio")
            #expect(inquiry.useCases == "Contract analysis, legal research")
            #expect(inquiry.inquiryStatus == .new)
            #expect(inquiry.notes == "High priority lead")
        }
    }

    @Test("LawyerInquiry status enum works correctly")
    func statusEnumValues() {
        #expect(LawyerInquiry.Status.new.rawValue == "new")
        #expect(LawyerInquiry.Status.contacted.rawValue == "contacted")
        #expect(LawyerInquiry.Status.qualified.rawValue == "qualified")
        #expect(LawyerInquiry.Status.converted.rawValue == "converted")
        #expect(LawyerInquiry.Status.declined.rawValue == "declined")
        #expect(LawyerInquiry.Status.allCases.count == 5)
    }

    @Test("LawyerInquiry Nevada Bar status enum works correctly")
    func nevadaBarStatusEnumValues() {
        #expect(LawyerInquiry.NevadaBarStatus.yes.rawValue == "yes")
        #expect(LawyerInquiry.NevadaBarStatus.no.rawValue == "no")
        #expect(LawyerInquiry.NevadaBarStatus.considering.rawValue == "considering")
        #expect(LawyerInquiry.NevadaBarStatus.allCases.count == 3)
    }

    @Test("LawyerInquiry can be queried by email")
    func queryByEmail() async throws {
        try await TestUtilities.withApp { app, database in
            let inquiry1 = LawyerInquiry(
                firmName: "Law Firm 1",
                contactName: "Contact 1",
                email: "test1@example.com"
            )
            let inquiry2 = LawyerInquiry(
                firmName: "Law Firm 2",
                contactName: "Contact 2",
                email: "test2@example.com"
            )

            try await inquiry1.create(on: app.db)
            try await inquiry2.create(on: app.db)

            let found = try await LawyerInquiry.query(on: app.db)
                .filter(\.$email == "test1@example.com")
                .first()

            #expect(found != nil)
            #expect(found?.firmName == "Law Firm 1")
            #expect(found?.email == "test1@example.com")
        }
    }

    @Test("LawyerInquiry can be queried by status")
    func queryByStatus() async throws {
        try await TestUtilities.withApp { app, database in
            let newInquiry = LawyerInquiry(
                firmName: "New Firm",
                contactName: "New Contact",
                email: "new@example.com",
                inquiryStatus: .new
            )
            let contactedInquiry = LawyerInquiry(
                firmName: "Contacted Firm",
                contactName: "Contacted Contact",
                email: "contacted@example.com",
                inquiryStatus: .contacted
            )

            try await newInquiry.create(on: app.db)
            try await contactedInquiry.create(on: app.db)

            let newInquiries = try await LawyerInquiry.query(on: app.db)
                .filter(\.$inquiryStatus == .new)
                .all()

            #expect(newInquiries.count >= 1)
            #expect(newInquiries.contains { $0.email == "new@example.com" })
        }
    }

    @Test("LawyerInquiry can be updated")
    func updateInquiry() async throws {
        try await TestUtilities.withApp { app, database in
            let inquiry = LawyerInquiry(
                firmName: "Update Test Firm",
                contactName: "Update Test",
                email: "update@example.com"
            )

            try await inquiry.create(on: app.db)
            let originalUpdatedAt = inquiry.updatedAt

            // Wait a bit to ensure timestamp difference
            try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

            inquiry.inquiryStatus = .contacted
            inquiry.notes = "Called and left voicemail"
            try await inquiry.update(on: app.db)

            #expect(inquiry.inquiryStatus == .contacted)
            #expect(inquiry.notes == "Called and left voicemail")
            #expect(inquiry.updatedAt != originalUpdatedAt)
        }
    }
}
