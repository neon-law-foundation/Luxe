#if os(macOS)
import SwiftUI

struct ContentView: View {
    @State private var selectedFolder: TicketFilter = .all
    @State private var selectedTicketId: UUID?
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedFilter: $selectedFolder)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 300)
        } content: {
            TicketListView(
                filter: selectedFolder,
                selectedTicketId: $selectedTicketId,
                searchText: searchText
            )
            .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 500)
        } detail: {
            if let ticketId = selectedTicketId {
                TicketDetailView(ticketId: ticketId)
            } else {
                Text("Select a ticket to view details")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search tickets")
        .navigationTitle("Concierge")
    }
}
#endif
