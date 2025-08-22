# Concierge - Shared Inbox for macOS

Concierge is a native macOS application designed as a shared inbox for customer support tickets. It provides a
Mail.app-like interface for managing service tickets from the Luxe platform's help desk system.

## Features

- **Three-column layout** similar to Mail.app for optimal ticket management

- **Sidebar navigation** with smart folders and ticket counts

- **Real-time ticket updates** with priority and status indicators

- **Conversation threading** with support for internal notes

- **Advanced search and filtering** capabilities

- **Bulk actions** for efficient ticket management

- **Native macOS integration** with keyboard shortcuts and system styling

## Architecture

Concierge follows the project's Swift-only architecture with a UI-only design:

```text
Sources/Concierge/
├── ConciergeApp.swift          # Main app entry point
├── ContentView.swift          # Root view with NavigationSplitView
├── Models/
│   └── TicketModels.swift     # UI data models for display
├── Views/
│   ├── SidebarView.swift      # Left sidebar with folders and filters
│   ├── TicketListView.swift   # Middle pane with ticket list
│   ├── TicketDetailView.swift # Right pane with ticket details
│   └── ToolbarView.swift      # Action toolbar
└── ViewModels/
    └── SharedViewModels.swift # ObservableObject view models
```

## Data Integration

Concierge is designed as a UI-only application. In the future, it will connect to the Luxe platform via
SwiftOpenAPI client for real-time ticket data.

## Building and Running

### Prerequisites

- macOS 15.0 or later

- Xcode 16.0 or later

- Swift 6.1 or later

### Using Xcode

1. **Open the project in Xcode:**

   ```bash
   open Package.swift
   ```

2. **Select the Concierge scheme:**
   - In Xcode, click the scheme selector (next to the play button)
   - Choose "Concierge" from the list

3. **Build and run:**
   - Press ⌘R or click the play button
   - The app will launch as a native macOS application

### Using Swift Package Manager

1. **Build the project:**

   ```bash
   swift build --product Concierge
   ```

2. **Run the application:**

   ```bash
   swift run Concierge
   ```

### Running Tests

1. **Run all Concierge tests:**

   ```bash
   swift test --filter ConciergeTests
   ```

2. **Run specific test suites:**

   ```bash
   swift test --filter "ConciergeTests.SidebarTests"
   swift test --filter "ConciergeTests.TicketListTests"
   ```

### Development Workflow

Following the project's TDD approach:

1. **Write tests first** using Swift Testing framework
2. **Run tests** to see expected failures
3. **Implement features** to pass tests
4. **Refactor** while keeping tests green

## User Interface

### Sidebar (Left Column)

- **Inbox folders** with ticket counts

- **Smart filters** (All, Unassigned, My Tickets, etc.)

- **Status-based folders** (Open, Pending, Resolved, etc.)

- **Tag-based filtering** with counts

- **Priority filters** for urgent tickets

### Ticket List (Middle Column)

- **Ticket previews** with subject, snippet, and metadata

- **Sortable columns** by date, priority, status

- **Unread indicators** for new tickets

- **Attachment indicators** for tickets with files

- **Bulk selection** for mass actions

### Ticket Details (Right Column)

- **Full ticket information** with metadata

- **Conversation thread** with all messages

- **Internal notes** marked distinctly

- **System messages** for status changes

- **Reply composition** with rich text support

- **Action toolbar** for common operations

## Keyboard Shortcuts

- `⌘N` - New ticket

- `⌘R` - Reply to ticket

- `⌘⏎` - Send reply

- `⌘F` - Focus search

- `⌘1-9` - Switch between sidebar folders

- `⌘⌫` - Delete selected tickets

- `Space` - Mark ticket as read/unread

## Configuration

Concierge reads configuration from environment variables:

- `CONCIERGE_LOG_LEVEL` - Logging level (debug, info, warning, error)

## Integration with Luxe Platform

Concierge is designed as a UI-only application that will integrate with the Luxe platform:

- **Future API integration** via SwiftOpenAPI client

- **Logging** using Swift-Log

- **Native macOS UI** with SwiftUI

## Development Notes

- Uses **SwiftUI** for native macOS interface

- Implements **MVVM pattern** with ObservableObject

- Follows **Swift Testing** framework patterns

- **Mock data** for development and testing

- **Real-time updates** planned for future versions

## Future Enhancements

- [ ] SwiftOpenAPI client integration for real-time data

- [ ] Real-time notifications via WebSocket

- [ ] Advanced email integration

- [ ] Custom keyboard shortcuts

- [ ] Dark mode support

- [ ] Export capabilities

- [ ] Advanced reporting dashboard

## Contributing

1. Follow the project's TDD approach
2. Write tests before implementation
3. Use Swift Testing framework
4. Follow existing code patterns
5. Update documentation as needed

For detailed development guidelines, see the main project's `CLAUDE.md` file.
