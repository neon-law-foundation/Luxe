#if os(macOS)
import SwiftUI

struct ToolbarView: View {
    @StateObject private var viewModel = ToolbarViewModel()

    var body: some View {
        HStack {
            Button(action: {}) {
                Label("New Ticket", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)

            Divider()
                .frame(height: 20)

            Button(action: {}) {
                Label("Archive", systemImage: "archivebox")
            }
            .disabled(viewModel.selectedTickets.isEmpty)

            Button(action: {}) {
                Label("Delete", systemImage: "trash")
            }
            .disabled(viewModel.selectedTickets.isEmpty)

            Spacer()

            Button(action: {}) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }

            Button(action: {}) {
                Label("Settings", systemImage: "gear")
            }
        }
        .padding()
    }
}
#endif
