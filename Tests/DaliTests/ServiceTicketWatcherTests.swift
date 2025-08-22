import Foundation
import PostgresNIO
import Testing

@testable import Dali

@Suite("ServiceTicketWatcher Tests", .serialized)
struct ServiceTicketWatcherTests {
    @Test("ServiceTicketWatcher should store watcher information")
    func serviceTicketWatcherPropertiesAreValidated() throws {
        let id = UUID()
        let ticketId = UUID()
        let userId = UUID()
        let addedBy = UUID()
        let createdAt = Date()

        let watcher = ServiceTicketWatcher(
            id: id,
            ticketId: ticketId,
            userId: userId,
            addedBy: addedBy,
            createdAt: createdAt
        )

        #expect(watcher.id == id)
        #expect(watcher.ticketId == ticketId)
        #expect(watcher.userId == userId)
        #expect(watcher.addedBy == addedBy)
        #expect(watcher.createdAt == createdAt)
    }

    @Test("ServiceTicketWatcher should handle self-added watchers")
    func selfAddedWatcherWorksCorrectly() throws {
        let userId = UUID()
        let watcher = ServiceTicketWatcher(
            id: UUID(),
            ticketId: UUID(),
            userId: userId,
            addedBy: userId,  // User added themselves as watcher
            createdAt: Date()
        )

        #expect(watcher.userId == watcher.addedBy)
    }

    @Test("ServiceTicketWatcher should handle admin-added watchers")
    func adminAddedWatcherWorksCorrectly() throws {
        let userId = UUID()
        let adminId = UUID()
        let watcher = ServiceTicketWatcher(
            id: UUID(),
            ticketId: UUID(),
            userId: userId,
            addedBy: adminId,  // Admin added another user as watcher
            createdAt: Date()
        )

        #expect(watcher.userId == userId)
        #expect(watcher.addedBy == adminId)
        #expect(watcher.userId != watcher.addedBy)
    }

    @Test("ServiceTicketWatcher should be codable")
    func serviceTicketWatcherCodableWorksCorrectly() throws {
        let watcher = ServiceTicketWatcher(
            id: UUID(),
            ticketId: UUID(),
            userId: UUID(),
            addedBy: UUID(),
            createdAt: Date()
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(watcher)
        let decoded = try decoder.decode(ServiceTicketWatcher.self, from: data)

        #expect(decoded.id == watcher.id)
        #expect(decoded.ticketId == watcher.ticketId)
        #expect(decoded.userId == watcher.userId)
        #expect(decoded.addedBy == watcher.addedBy)
    }

    @Test("ServiceTicketWatcher should handle multiple watchers for same ticket")
    func multipleWatchersPerTicketWorkCorrectly() throws {
        let ticketId = UUID()
        let user1 = UUID()
        let user2 = UUID()
        let addedBy = UUID()

        let watcher1 = ServiceTicketWatcher(
            id: UUID(),
            ticketId: ticketId,
            userId: user1,
            addedBy: addedBy,
            createdAt: Date()
        )

        let watcher2 = ServiceTicketWatcher(
            id: UUID(),
            ticketId: ticketId,
            userId: user2,
            addedBy: addedBy,
            createdAt: Date()
        )

        #expect(watcher1.ticketId == watcher2.ticketId)
        #expect(watcher1.userId != watcher2.userId)
        #expect(watcher1.id != watcher2.id)
    }
}
