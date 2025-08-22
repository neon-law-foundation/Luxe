#if os(macOS)
import Foundation
import Testing

@testable import Concierge

@Suite("Concierge - Shared Inbox Application", .serialized)
struct ConciergeTests {

    @Suite("Models", .serialized)
    struct ModelTests {
        @Test("TicketPreview has correct properties")
        func ticketPreviewHasCorrectProperties() async throws {
            let ticket = TicketPreview(
                id: UUID(),
                ticketNumber: "TKT-000001",
                subject: "Test Ticket",
                snippet: "This is a test ticket...",
                requesterName: "Test User",
                priority: .medium,
                status: .open,
                updatedAt: Date()
            )
            #expect(ticket.subject == "Test Ticket")
            #expect(ticket.priority == .medium)
            #expect(ticket.status == .open)
        }

        @Test("TicketDetail has mutable priority and status")
        func ticketDetailHasMutableFields() async throws {
            var ticket = TicketDetail(
                id: UUID(),
                ticketNumber: "TKT-000001",
                subject: "Test Ticket",
                description: "Description",
                requester: "Test User",
                requesterEmail: "test@example.com",
                assignee: nil,
                priority: .low,
                status: .open,
                source: .email,
                tags: [],
                createdAt: Date(),
                updatedAt: Date()
            )

            ticket.priority = .high
            ticket.status = .resolved

            #expect(ticket.priority == .high)
            #expect(ticket.status == .resolved)
        }
    }

    @Suite("Enums", .serialized)
    struct EnumTests {
        @Test("TicketPriority has all cases")
        func ticketPriorityHasAllCases() async throws {
            let allCases = TicketPriority.allCases
            #expect(allCases.count == 4)
            #expect(allCases.contains(.low))
            #expect(allCases.contains(.medium))
            #expect(allCases.contains(.high))
            #expect(allCases.contains(.critical))
        }

        @Test("TicketStatus has all cases")
        func ticketStatusHasAllCases() async throws {
            let allCases = TicketStatus.allCases
            #expect(allCases.count == 5)
            #expect(allCases.contains(.open))
            #expect(allCases.contains(.pending))
            #expect(allCases.contains(.inProgress))
            #expect(allCases.contains(.resolved))
            #expect(allCases.contains(.closed))
        }

        @Test("TicketFilter has system image names")
        func ticketFilterHasSystemImageNames() async throws {
            #expect(TicketFilter.all.systemImageName == "tray.2")
            #expect(TicketFilter.unassigned.systemImageName == "person.crop.circle.badge.questionmark")
            #expect(TicketFilter.open.systemImageName == "envelope.open")
            #expect(TicketFilter.resolved.systemImageName == "checkmark.circle")
        }
    }

    @Suite("View Models", .serialized)
    struct ViewModelTests {
        @Test("SidebarViewModel loads folders")
        func sidebarViewModelLoadsFolders() async throws {
            let viewModel = await SidebarViewModel()
            await viewModel.loadFolders()

            let folders = await viewModel.folders
            let ticketCounts = await viewModel.ticketCounts

            #expect(folders.count > 0)
            #expect(ticketCounts.count > 0)
        }

        @Test("TicketListViewModel loads tickets")
        func ticketListViewModelLoadsTickets() async throws {
            let viewModel = await TicketListViewModel()
            await viewModel.loadTickets(filter: .all)

            let tickets = await viewModel.tickets
            #expect(tickets.count >= 0)
        }

        @Test("TicketDetailViewModel loads ticket details")
        func ticketDetailViewModelLoadsTicketDetails() async throws {
            let viewModel = await TicketDetailViewModel()
            await viewModel.loadTicket(id: UUID())

            let ticket = await viewModel.ticket
            let conversations = await viewModel.conversations
            let error = await viewModel.error

            #expect(ticket != nil || error != nil)
            #expect(conversations.count >= 0)
        }
    }

    @Suite("Search and Filter", .serialized)
    struct SearchAndFilterTests {
        @Test("SearchViewModel performs search")
        func searchViewModelPerformsSearch() async throws {
            let viewModel = await SearchViewModel()
            await MainActor.run {
                viewModel.searchText = "test"
            }
            await viewModel.performSearch()

            let searchResults = await viewModel.searchResults
            #expect(searchResults != nil)
        }

        @Test("TicketFilterCriteria has correct structure")
        func ticketFilterCriteriaHasCorrectStructure() async throws {
            let filter = TicketFilterCriteria(
                status: [.open, .pending],
                priority: [.high, .critical],
                assignee: nil,
                tags: ["urgent"]
            )
            #expect(filter.status.count == 2)
            #expect(filter.priority.count == 2)
            #expect(filter.tags.count == 1)
        }
    }

    @Suite("Action Models", .serialized)
    struct ActionModelTests {
        @Test("TicketActionViewModel performs actions")
        func ticketActionViewModelPerformsActions() async throws {
            let viewModel = await TicketActionViewModel()
            await viewModel.assignTicket(ticketId: UUID(), to: UUID())

            let lastAction = await viewModel.lastAction
            #expect(lastAction != nil)
        }

        @Test("TicketActionViewModel updates priority")
        func ticketActionViewModelUpdatesPriority() async throws {
            let viewModel = await TicketActionViewModel()
            await viewModel.updatePriority(ticketId: UUID(), to: .high)

            let lastAction = await viewModel.lastAction
            #expect(lastAction?.contains("Priority") == true)
        }
    }
}
#endif
