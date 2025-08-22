import Fluent
import FluentPostgresDriver
import Logging
import PostgresNIO
import TestUtilities
import Testing
import Vapor

@testable import Dali
@testable import Palette

@Suite("Newsletter Service Tests", .serialized)
struct NewsletterServiceTests {

    @Test("NewsletterService can create a newsletter")
    func newsletterServiceCanCreateNewsletter() async throws {
        try await TestUtilities.withApp { app, database in
            let service = NewsletterService(database: database)
            let adminService = AdminUserService(database: database)

            // Create an admin user for testing
            let email = "admin_newsletter_\(UniqueCodeGenerator.generateISOCode(prefix: "ADMIN"))@example.com"
            let input = AdminUserService.CreatePersonAndUserInput(
                name: "Admin User",
                email: email,
                username: email,
                role: .admin
            )

            let adminResult = try await adminService.createPersonAndUser(input)

            // Create a newsletter
            let newsletter = try await service.create(
                name: .nvSciTech,
                subjectLine: "Test Newsletter Subject",
                markdownContent: "# Test Newsletter\n\nThis is test content.",
                createdBy: adminResult.userId
            )

            #expect(newsletter.name == .nvSciTech)
            #expect(newsletter.subjectLine == "Test Newsletter Subject")
            #expect(newsletter.markdownContent == "# Test Newsletter\n\nThis is test content.")
            #expect(newsletter.createdBy == adminResult.userId)
            #expect(newsletter.sentAt == nil)
            #expect(newsletter.recipientCount == 0)
            #expect(newsletter.isDraft == true)
        }
    }

    @Test("NewsletterService can find newsletter by ID")
    func newsletterServiceCanFindById() async throws {
        try await TestUtilities.withApp { app, database in
            let service = NewsletterService(database: database)
            let adminService = AdminUserService(database: database)

            // Create an admin user
            let email = "admin_find_\(UniqueCodeGenerator.generateISOCode(prefix: "FIND"))@example.com"
            let adminResult = try await adminService.createPersonAndUser(
                AdminUserService.CreatePersonAndUserInput(
                    name: "Admin User",
                    email: email,
                    username: email,
                    role: .admin
                )
            )

            // Create a newsletter
            let created = try await service.create(
                name: .sagebrush,
                subjectLine: "Find Me Newsletter",
                markdownContent: "Content to find",
                createdBy: adminResult.userId
            )

            // Find the newsletter
            let found = try await service.findById(created.id)

            #expect(found != nil)
            #expect(found?.id == created.id)
            #expect(found?.subjectLine == "Find Me Newsletter")

            // Try finding non-existent newsletter
            let notFound = try await service.findById(UUID())
            #expect(notFound == nil)
        }
    }

    @Test("NewsletterService can list all newsletters")
    func newsletterServiceCanFindAll() async throws {
        try await TestUtilities.withApp { app, database in
            let service = NewsletterService(database: database)
            let adminService = AdminUserService(database: database)

            // Create an admin user
            let email = "admin_list_\(UniqueCodeGenerator.generateISOCode(prefix: "LIST"))@example.com"
            let adminResult = try await adminService.createPersonAndUser(
                AdminUserService.CreatePersonAndUserInput(
                    name: "Admin User",
                    email: email,
                    username: email,
                    role: .admin
                )
            )

            // Create multiple newsletters
            let newsletter1 = try await service.create(
                name: .nvSciTech,
                subjectLine: "Newsletter 1",
                markdownContent: "Content 1",
                createdBy: adminResult.userId
            )

            let newsletter2 = try await service.create(
                name: .sagebrush,
                subjectLine: "Newsletter 2",
                markdownContent: "Content 2",
                createdBy: adminResult.userId
            )

            // Find all newsletters
            let allNewsletters = try await service.findAll()

            // Should contain at least our two newsletters
            #expect(allNewsletters.contains { $0.id == newsletter1.id })
            #expect(allNewsletters.contains { $0.id == newsletter2.id })
        }
    }

    @Test("NewsletterService can update draft newsletter")
    func newsletterServiceCanUpdateDraft() async throws {
        try await TestUtilities.withApp { app, database in
            let service = NewsletterService(database: database)
            let adminService = AdminUserService(database: database)

            // Create an admin user
            let email = "admin_update_\(UniqueCodeGenerator.generateISOCode(prefix: "UPDATE"))@example.com"
            let adminResult = try await adminService.createPersonAndUser(
                AdminUserService.CreatePersonAndUserInput(
                    name: "Admin User",
                    email: email,
                    username: email,
                    role: .admin
                )
            )

            // Create a draft newsletter
            let draft = try await service.create(
                name: .neonLaw,
                subjectLine: "Original Subject",
                markdownContent: "Original content",
                createdBy: adminResult.userId
            )

            // Update the newsletter
            let updated = try await service.update(
                id: draft.id,
                subjectLine: "Updated Subject",
                markdownContent: "Updated content"
            )

            #expect(updated.id == draft.id)
            #expect(updated.subjectLine == "Updated Subject")
            #expect(updated.markdownContent == "Updated content")
            #expect(updated.isDraft == true)
        }
    }

    @Test("NewsletterService can send newsletter")
    func newsletterServiceCanSendNewsletter() async throws {
        try await TestUtilities.withApp { app, database in
            let service = NewsletterService(database: database)
            let adminService = AdminUserService(database: database)

            // Create an admin user
            let adminEmail = "admin_send_\(UniqueCodeGenerator.generateISOCode(prefix: "SEND"))@example.com"
            let adminResult = try await adminService.createPersonAndUser(
                AdminUserService.CreatePersonAndUserInput(
                    name: "Admin User",
                    email: adminEmail,
                    username: adminEmail,
                    role: .admin
                )
            )

            // Create subscriber users with sci_tech subscription
            for i in 1...3 {
                let subscriberEmail =
                    "subscriber_\(i)_\(UniqueCodeGenerator.generateISOCode(prefix: "SUB"))@example.com"
                let subscriberResult = try await adminService.createPersonAndUser(
                    AdminUserService.CreatePersonAndUserInput(
                        name: "Subscriber \(i)",
                        email: subscriberEmail,
                        username: subscriberEmail,
                        role: .customer
                    )
                )

                // Subscribe user to sci_tech newsletter
                try await service.subscribeUser(userId: subscriberResult.userId, to: .nvSciTech)
            }

            // Create a draft newsletter
            let draft = try await service.create(
                name: .nvSciTech,
                subjectLine: "Newsletter to Send",
                markdownContent: "Content to send",
                createdBy: adminResult.userId
            )

            // Send the newsletter
            let sent = try await service.send(id: draft.id)

            #expect(sent.id == draft.id)
            #expect(sent.sentAt != nil)
            #expect(sent.recipientCount >= 3)  // At least our 3 subscribers
            #expect(sent.isSent == true)
            #expect(sent.isDraft == false)
        }
    }

    @Test("NewsletterService prevents sending already sent newsletter")
    func newsletterServicePreventsDoubleSending() async throws {
        try await TestUtilities.withApp { app, database in
            let service = NewsletterService(database: database)
            let adminService = AdminUserService(database: database)

            // Create an admin user
            let email = "admin_double_\(UniqueCodeGenerator.generateISOCode(prefix: "DOUBLE"))@example.com"
            let adminResult = try await adminService.createPersonAndUser(
                AdminUserService.CreatePersonAndUserInput(
                    name: "Admin User",
                    email: email,
                    username: email,
                    role: .admin
                )
            )

            // Create and send a newsletter
            let newsletter = try await service.create(
                name: .sagebrush,
                subjectLine: "Already Sent",
                markdownContent: "This was sent",
                createdBy: adminResult.userId
            )

            _ = try await service.send(id: newsletter.id)

            // Try to send again - should throw error
            do {
                _ = try await service.send(id: newsletter.id)
                #expect(Bool(false), "Should throw error when trying to send already sent newsletter")
            } catch let error as NewsletterError {
                #expect(error == .alreadySent)
            }
        }
    }

    @Test("NewsletterService can manage subscriptions")
    func newsletterServiceCanManageSubscriptions() async throws {
        try await TestUtilities.withApp { app, database in
            let service = NewsletterService(database: database)
            let adminService = AdminUserService(database: database)

            // Create a user
            let email = "subscriber_\(UniqueCodeGenerator.generateISOCode(prefix: "SUBTEST"))@example.com"
            let userResult = try await adminService.createPersonAndUser(
                AdminUserService.CreatePersonAndUserInput(
                    name: "Test Subscriber",
                    email: email,
                    username: email,
                    role: .customer
                )
            )

            // Subscribe user to newsletter
            try await service.subscribeUser(userId: userResult.userId, to: .nvSciTech)

            // Check subscription
            let subscribers = try await service.getSubscribers(for: .nvSciTech)
            #expect(subscribers.contains(userResult.userId))

            // Unsubscribe user
            try await service.unsubscribeUser(userId: userResult.userId, from: .nvSciTech)

            // Check subscription again
            let subscribersAfter = try await service.getSubscribers(for: .nvSciTech)
            #expect(!subscribersAfter.contains(userResult.userId))
        }
    }

    @Test("NewsletterService can delete draft newsletter")
    func newsletterServiceCanDeleteDraft() async throws {
        try await TestUtilities.withApp { app, database in
            let service = NewsletterService(database: database)
            let adminService = AdminUserService(database: database)

            // Create an admin user
            let email = "admin_delete_\(UniqueCodeGenerator.generateISOCode(prefix: "DELETE"))@example.com"
            let adminResult = try await adminService.createPersonAndUser(
                AdminUserService.CreatePersonAndUserInput(
                    name: "Admin User",
                    email: email,
                    username: email,
                    role: .admin
                )
            )

            // Create a draft newsletter
            let draft = try await service.create(
                name: .neonLaw,
                subjectLine: "To Delete",
                markdownContent: "Delete me",
                createdBy: adminResult.userId
            )

            // Delete the newsletter
            try await service.delete(id: draft.id)

            // Try to find it - should be nil
            let found = try await service.findById(draft.id)
            #expect(found == nil)
        }
    }

    @Test("NewsletterService prevents updating sent newsletter")
    func newsletterServicePreventsUpdatingSentNewsletter() async throws {
        try await TestUtilities.withApp { app, database in
            let service = NewsletterService(database: database)
            let adminService = AdminUserService(database: database)

            // Create an admin user
            let email = "admin_noupdate_\(UniqueCodeGenerator.generateISOCode(prefix: "NOUPD"))@example.com"
            let adminResult = try await adminService.createPersonAndUser(
                AdminUserService.CreatePersonAndUserInput(
                    name: "Admin User",
                    email: email,
                    username: email,
                    role: .admin
                )
            )

            // Create and send a newsletter
            let newsletter = try await service.create(
                name: .sagebrush,
                subjectLine: "Sent Newsletter",
                markdownContent: "Sent content",
                createdBy: adminResult.userId
            )

            _ = try await service.send(id: newsletter.id)

            // Try to update - should throw error
            do {
                _ = try await service.update(
                    id: newsletter.id,
                    subjectLine: "Cannot Update"
                )
                #expect(Bool(false), "Should throw error when trying to update sent newsletter")
            } catch let error as NewsletterError {
                #expect(error == .cannotUpdateSentNewsletter)
            }
        }
    }

    @Test("NewsletterService prevents deleting sent newsletter")
    func newsletterServicePreventsDeletingSentNewsletter() async throws {
        try await TestUtilities.withApp { app, database in
            let service = NewsletterService(database: database)
            let adminService = AdminUserService(database: database)

            // Create an admin user
            let email = "admin_nodelete_\(UniqueCodeGenerator.generateISOCode(prefix: "NODEL"))@example.com"
            let adminResult = try await adminService.createPersonAndUser(
                AdminUserService.CreatePersonAndUserInput(
                    name: "Admin User",
                    email: email,
                    username: email,
                    role: .admin
                )
            )

            // Create and send a newsletter
            let newsletter = try await service.create(
                name: .neonLaw,
                subjectLine: "Cannot Delete",
                markdownContent: "Protected content",
                createdBy: adminResult.userId
            )

            _ = try await service.send(id: newsletter.id)

            // Try to delete - should throw error
            do {
                try await service.delete(id: newsletter.id)
                #expect(Bool(false), "Should throw error when trying to delete sent newsletter")
            } catch let error as NewsletterError {
                #expect(error == .cannotDeleteSentNewsletter)
            }
        }
    }
}
