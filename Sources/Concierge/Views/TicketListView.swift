#if os(macOS)
import SwiftUI

struct TicketListView: View {
    let filter: TicketFilter
    @Binding var selectedTicketId: UUID?
    let searchText: String

    @StateObject private var viewModel = TicketListViewModel()
    @State private var sortOrder: TicketSortOrder = .dateDescending

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("\(viewModel.tickets.count) tickets")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Spacer()

                Picker("Sort", selection: $sortOrder) {
                    ForEach(TicketSortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 150)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Ticket List
            List(selection: $selectedTicketId) {
                ForEach(filteredTickets) { ticket in
                    TicketRowView(ticket: ticket)
                        .tag(ticket.id)
                }
            }
            .listStyle(PlainListStyle())
        }
        .navigationTitle(filter.rawValue)
        .task {
            await viewModel.loadTickets(filter: filter)
        }
        .onChange(of: filter) { _, newFilter in
            Task {
                await viewModel.loadTickets(filter: newFilter)
            }
        }
        .onChange(of: sortOrder) { _, newOrder in
            viewModel.sortOrder = newOrder
        }
    }

    private var filteredTickets: [TicketPreview] {
        if searchText.isEmpty {
            return viewModel.tickets
        } else {
            return viewModel.tickets.filter { ticket in
                ticket.subject.localizedCaseInsensitiveContains(searchText)
                    || ticket.snippet.localizedCaseInsensitiveContains(searchText)
                    || ticket.requesterName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

struct TicketRowView: View {
    let ticket: TicketPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Unread indicator
                Circle()
                    .fill(ticket.isUnread ? Color.blue : Color.clear)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(ticket.requesterName)
                            .font(.system(size: 13, weight: ticket.isUnread ? .semibold : .regular))
                            .lineLimit(1)

                        Spacer()

                        Text(ticket.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text(ticket.subject)
                            .font(.system(size: 13, weight: ticket.isUnread ? .medium : .regular))
                            .lineLimit(1)

                        if ticket.hasAttachment {
                            Image(systemName: "paperclip")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    Text(ticket.snippet)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                VStack(alignment: .trailing, spacing: 4) {
                    PriorityBadge(priority: ticket.priority)
                    StatusBadge(status: ticket.status)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .background(Color.clear)
    }
}

struct PriorityBadge: View {
    let priority: TicketPriority

    var body: some View {
        Text(priority.displayName)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(colorForPriority.opacity(0.2))
            .foregroundColor(colorForPriority)
            .clipShape(Capsule())
    }

    private var colorForPriority: Color {
        switch priority {
        case .low:
            return .gray
        case .medium:
            return .blue
        case .high:
            return .orange
        case .critical:
            return .red
        }
    }
}

struct StatusBadge: View {
    let status: TicketStatus

    var body: some View {
        Text(status.displayName)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(colorForStatus.opacity(0.2))
            .foregroundColor(colorForStatus)
            .clipShape(Capsule())
    }

    private var colorForStatus: Color {
        switch status {
        case .open:
            return .blue
        case .pending:
            return .orange
        case .inProgress:
            return .purple
        case .resolved:
            return .green
        case .closed:
            return .gray
        }
    }
}

@MainActor
class TicketListViewModel: ObservableObject {
    @Published var tickets: [TicketPreview] = []
    @Published var sortOrder: TicketSortOrder = .dateDescending {
        didSet {
            sortTickets()
        }
    }

    func loadTickets(filter: TicketFilter) async {
        // In a real implementation, this would fetch from the database
        // For now, we'll use mock data
        tickets = [
            TicketPreview(
                id: UUID(),
                ticketNumber: "TKT-000042",
                subject: "Unable to access account after password reset",
                snippet: "I followed the password reset instructions but I'm still unable to log in to my account...",
                requesterName: "Jane Smith",
                priority: .high,
                status: .open,
                updatedAt: Date().addingTimeInterval(-3600),
                isUnread: true,
                hasAttachment: true
            ),
            TicketPreview(
                id: UUID(),
                ticketNumber: "TKT-000041",
                subject: "Billing inquiry for last month's invoice",
                snippet: "I noticed a discrepancy in my last month's invoice. The amount charged doesn't match...",
                requesterName: "John Doe",
                priority: .medium,
                status: .pending,
                updatedAt: Date().addingTimeInterval(-7200),
                isUnread: true
            ),
            TicketPreview(
                id: UUID(),
                ticketNumber: "TKT-000040",
                subject: "Feature request: Export data to CSV",
                snippet: "It would be great if we could export our data to CSV format for analysis in Excel...",
                requesterName: "Alice Johnson",
                priority: .low,
                status: .open,
                updatedAt: Date().addingTimeInterval(-86400)
            ),
        ]

        sortTickets()
    }

    private func sortTickets() {
        switch sortOrder {
        case .dateDescending:
            tickets.sort { $0.updatedAt > $1.updatedAt }
        case .dateAscending:
            tickets.sort { $0.updatedAt < $1.updatedAt }
        case .priority:
            tickets.sort { $0.priority.rawValue > $1.priority.rawValue }
        case .status:
            tickets.sort { $0.status.rawValue < $1.status.rawValue }
        }
    }
}
#endif
