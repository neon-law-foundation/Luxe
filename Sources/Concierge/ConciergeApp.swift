#if os(macOS)
import Logging
import SwiftUI

@main
struct ConciergeApp: App {
    let logger = Logger(label: "com.neonlaw.concierge")

    init() {
        logger.info("Concierge app starting...")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Ticket") {
                    // Handle new ticket creation
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
#else
// Stub main function for non-macOS platforms
@main
struct ConciergeApp {
    static func main() {
        print("Concierge is only available on macOS")
    }
}
#endif
