import Fluent
import Foundation
import Vapor

/// Represents a share issuance in the equity schema.
///
/// Share issuances track the allocation of shares to holders, including
/// financial details, tax information, and any restrictions. Each issuance
/// references a share class, a holder entity, and optionally a supporting document.
///
/// This model supports tax reporting with fields for taxable year, calendar year,
/// and amounts to include in gross income, making it suitable for equity compensation
/// tracking and compliance reporting.
public final class ShareIssuance: Model, @unchecked Sendable {
    public static let schema = "share_issuances"
    public static let space = "equity"

    @ID(custom: .id, generatedBy: .database)
    public var id: UUID?

    @Parent(key: "share_class_id")
    public var shareClass: ShareClass

    @Parent(key: "holder_id")
    public var holder: Entity

    @OptionalParent(key: "document_id")
    public var document: Blob?

    @OptionalField(key: "fair_market_value_per_share")
    public var fairMarketValuePerShare: Decimal?

    @OptionalField(key: "amount_paid_per_share")
    public var amountPaidPerShare: Decimal?

    @OptionalField(key: "amount_paid_for_shares")
    public var amountPaidForShares: Decimal?

    @OptionalField(key: "amount_to_include_in_gross_income")
    public var amountToIncludeInGrossIncome: Decimal?

    @OptionalField(key: "restrictions")
    public var restrictions: String?

    @OptionalField(key: "taxable_year")
    public var taxableYear: String?

    @OptionalField(key: "calendar_year")
    public var calendarYear: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        shareClassID: ShareClass.IDValue,
        holderID: Entity.IDValue,
        documentID: Blob.IDValue? = nil,
        fairMarketValuePerShare: Decimal? = nil,
        amountPaidPerShare: Decimal? = nil,
        amountPaidForShares: Decimal? = nil,
        amountToIncludeInGrossIncome: Decimal? = nil,
        restrictions: String? = nil,
        taxableYear: String? = nil,
        calendarYear: String? = nil
    ) {
        self.id = id
        self.$shareClass.id = shareClassID
        self.$holder.id = holderID
        if let documentID = documentID {
            self.$document.id = documentID
        }
        self.fairMarketValuePerShare = fairMarketValuePerShare
        self.amountPaidPerShare = amountPaidPerShare
        self.amountPaidForShares = amountPaidForShares
        self.amountToIncludeInGrossIncome = amountToIncludeInGrossIncome
        self.restrictions = restrictions
        self.taxableYear = taxableYear
        self.calendarYear = calendarYear
    }
}

extension ShareIssuance: Content {}
