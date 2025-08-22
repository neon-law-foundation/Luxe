#if os(macOS)
import SwiftUI

struct SidebarView: View {
    @Binding var selectedFilter: TicketFilter
    @StateObject private var viewModel = SidebarViewModel()

    var body: some View {
        List(selection: $selectedFilter) {
            Section("Inbox") {
                ForEach(TicketFilter.allCases, id: \.self) { filter in
                    Label {
                        HStack {
                            Text(filter.rawValue)
                            Spacer()
                            if let count = viewModel.ticketCounts[filter] {
                                Text("\(count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.gray.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                    } icon: {
                        Image(systemName: filter.systemImageName)
                            .foregroundColor(colorForFilter(filter))
                    }
                    .tag(filter)
                }
            }

            if !viewModel.tags.isEmpty {
                Section("Tags") {
                    ForEach(viewModel.tags, id: \.self) { tag in
                        Label(tag, systemImage: "tag")
                            .badge(viewModel.tagCounts[tag] ?? 0)
                    }
                }
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("Concierge")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {}) {
                    Image(systemName: "square.and.pencil")
                }
                .help("New Ticket")
            }
        }
        .task {
            await viewModel.loadFolders()
        }
    }

    private func colorForFilter(_ filter: TicketFilter) -> Color {
        switch filter {
        case .highPriority:
            return .red
        case .open:
            return .blue
        case .pending:
            return .orange
        case .resolved:
            return .green
        case .closed:
            return .gray
        default:
            return .primary
        }
    }
}

@MainActor
class SidebarViewModel: ObservableObject {
    @Published var folders: [TicketFilter] = TicketFilter.allCases
    @Published var ticketCounts: [TicketFilter: Int] = [:]
    @Published var tags: [String] = []
    @Published var tagCounts: [String: Int] = [:]
    @Published var selectedFilter: TicketFilter = .all

    func loadFolders() async {
        // In a real implementation, this would fetch from the database
        // For now, we'll use mock data
        ticketCounts = [
            .all: 42,
            .unassigned: 12,
            .myTickets: 8,
            .open: 20,
            .pending: 10,
            .inProgress: 5,
            .resolved: 5,
            .closed: 2,
            .highPriority: 3,
        ]

        tags = ["billing", "support", "bug", "feature-request"]
        tagCounts = [
            "billing": 5,
            "support": 15,
            "bug": 8,
            "feature-request": 3,
        ]
    }
}
#endif
