import Fluent
import Foundation
import Vapor

/// Represents an invoice in the accounting schema
public final class Invoice: Model, @unchecked Sendable {
    public static let schema = "invoices"
    public static let space = "accounting"

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @Parent(key: "vendor_id")
    public var vendor: Vendor

    @Enum(key: "invoiced_from")
    public var invoicedFrom: InvoicedFrom

    @Field(key: "invoiced_amount")
    public var invoicedAmount: Int64

    @Field(key: "sent_at")
    public var sentAt: Date

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        vendorID: Vendor.IDValue,
        invoicedFrom: InvoicedFrom,
        invoicedAmount: Int64,
        sentAt: Date
    ) {
        self.id = id
        self.$vendor.id = vendorID
        self.invoicedFrom = invoicedFrom
        self.invoicedAmount = invoicedAmount
        self.sentAt = sentAt
    }
}

/// Enum representing the entity that issued the invoice
public enum InvoicedFrom: String, CaseIterable, Codable, Sendable {
    case neonLaw = "neon_law"
    case neonLawFoundation = "neon_law_foundation"
    case sagebrushServices = "sagebrush_services"
}

extension Invoice: Content {}
