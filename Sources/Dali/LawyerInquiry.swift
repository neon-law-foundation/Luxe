import Fluent
import Foundation
import Vapor

/// Represents a lawyer inquiry in the public schema
public final class LawyerInquiry: Model, @unchecked Sendable {
    public static let schema = "lawyer_inquiries"

    /// Inquiry status options
    public enum Status: String, Codable, CaseIterable, Sendable {
        case new
        case contacted
        case qualified
        case converted
        case declined
    }

    /// Nevada Bar membership status
    public enum NevadaBarStatus: String, Codable, CaseIterable, Sendable {
        case yes
        case no
        case considering
    }

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @Field(key: "firm_name")
    public var firmName: String

    @Field(key: "contact_name")
    public var contactName: String

    @Field(key: "email")
    public var email: String

    @OptionalEnum(key: "nevada_bar_member")
    public var nevadaBarMember: NevadaBarStatus?

    @OptionalField(key: "current_software")
    public var currentSoftware: String?

    @OptionalField(key: "use_cases")
    public var useCases: String?

    @Enum(key: "inquiry_status")
    public var inquiryStatus: Status

    @OptionalField(key: "notes")
    public var notes: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        firmName: String,
        contactName: String,
        email: String,
        nevadaBarMember: NevadaBarStatus? = nil,
        currentSoftware: String? = nil,
        useCases: String? = nil,
        inquiryStatus: Status = .new,
        notes: String? = nil
    ) {
        self.id = id
        self.firmName = firmName
        self.contactName = contactName
        self.email = email
        self.nevadaBarMember = nevadaBarMember
        self.currentSoftware = currentSoftware
        self.useCases = useCases
        self.inquiryStatus = inquiryStatus
        self.notes = notes
    }
}

extension LawyerInquiry: Content {}
