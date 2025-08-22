import Foundation
import PostgresNIO
import Testing

@testable import Dali

@Suite("Newsletter Tests", .serialized)
struct NewsletterTests {
    @Test("Newsletter should store all properties correctly")
    func newsletterPropertiesAreValidated() throws {
        let id = UUID()
        let name = Newsletter.NewsletterName.nvSciTech
        let subjectLine = "Latest Science & Technology News"
        let markdownContent = "# Newsletter Content\n\nThis is the newsletter content."
        let sentAt = Date()
        let recipientCount = 42
        let createdBy = UUID()
        let createdAt = Date()
        let updatedAt = Date()

        let newsletter = Newsletter(
            id: id,
            name: name,
            subjectLine: subjectLine,
            markdownContent: markdownContent,
            sentAt: sentAt,
            recipientCount: recipientCount,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        #expect(newsletter.id == id)
        #expect(newsletter.name == name)
        #expect(newsletter.subjectLine == subjectLine)
        #expect(newsletter.markdownContent == markdownContent)
        #expect(newsletter.sentAt == sentAt)
        #expect(newsletter.recipientCount == recipientCount)
        #expect(newsletter.createdBy == createdBy)
        #expect(newsletter.createdAt == createdAt)
        #expect(newsletter.updatedAt == updatedAt)
        #expect(newsletter.isSent == true)
        #expect(newsletter.isDraft == false)
    }

    @Test("Newsletter draft should have nil sentAt")
    func newsletterDraftHasNilSentAt() throws {
        let newsletter = Newsletter(
            id: UUID(),
            name: .sagebrush,
            subjectLine: "Draft Newsletter",
            markdownContent: "# Draft Content",
            sentAt: nil,
            recipientCount: 0,
            createdBy: UUID(),
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(newsletter.sentAt == nil)
        #expect(newsletter.isSent == false)
        #expect(newsletter.isDraft == true)
        #expect(newsletter.recipientCount == 0)
    }

    @Test("NewsletterName enum should have correct values")
    func newsletterNameEnumWorksCorrectly() throws {
        #expect(Newsletter.NewsletterName.nvSciTech.rawValue == "nv-sci-tech")
        #expect(Newsletter.NewsletterName.sagebrush.rawValue == "sagebrush")
        #expect(Newsletter.NewsletterName.neonLaw.rawValue == "neon-law")

        // Test all cases are covered
        let allCases = Newsletter.NewsletterName.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.nvSciTech))
        #expect(allCases.contains(.sagebrush))
        #expect(allCases.contains(.neonLaw))
    }

    @Test("Newsletter can be initialized with default values")
    func newsletterCanBeInitializedWithDefaults() throws {
        let newsletter = Newsletter(
            id: UUID(),
            name: .neonLaw,
            subjectLine: "Legal Updates",
            markdownContent: "# Legal Newsletter",
            createdBy: UUID(),
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(newsletter.sentAt == nil)
        #expect(newsletter.recipientCount == 0)
        #expect(newsletter.isDraft == true)
        #expect(newsletter.isSent == false)
    }

    @Test("Newsletter isSent and isDraft are mutually exclusive")
    func newsletterStatePropertiesAreMutuallyExclusive() throws {
        // Test draft state
        let draft = Newsletter(
            id: UUID(),
            name: .nvSciTech,
            subjectLine: "Draft",
            markdownContent: "Content",
            sentAt: nil,
            recipientCount: 0,
            createdBy: UUID(),
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(draft.isDraft == true)
        #expect(draft.isSent == false)

        // Test sent state
        let sent = Newsletter(
            id: UUID(),
            name: .nvSciTech,
            subjectLine: "Sent",
            markdownContent: "Content",
            sentAt: Date(),
            recipientCount: 100,
            createdBy: UUID(),
            createdAt: Date(),
            updatedAt: Date()
        )

        #expect(sent.isDraft == false)
        #expect(sent.isSent == true)
    }
}
