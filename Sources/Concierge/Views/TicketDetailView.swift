#if os(macOS)
import SwiftUI

struct TicketDetailView: View {
    let ticketId: UUID
    @StateObject private var viewModel = TicketDetailViewModel()
    @State private var isComposingReply = false
    @State private var replyText = ""
    @State private var isInternalNote = false

    var body: some View {
        if let ticket = viewModel.ticket {
            VStack(spacing: 0) {
                // Header
                TicketHeaderView(ticket: ticket)

                Divider()

                // Conversation thread
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Initial ticket description
                        ConversationMessageView(
                            message: TicketConversation(
                                id: ticket.id,
                                ticketId: ticket.id,
                                authorName: ticket.requester,
                                content: ticket.description,
                                contentType: "text",
                                isInternal: false,
                                isSystemMessage: false,
                                messageType: .comment,
                                createdAt: ticket.createdAt
                            )
                        )

                        Divider()
                            .padding(.vertical)

                        // Conversation messages
                        ForEach(viewModel.conversations) { message in
                            ConversationMessageView(message: message)

                            if message.id != viewModel.conversations.last?.id {
                                Divider()
                                    .padding(.vertical)
                            }
                        }
                    }
                    .padding()
                }

                Divider()

                // Reply compose area
                if isComposingReply {
                    ReplyComposeView(
                        replyText: $replyText,
                        isInternalNote: $isInternalNote,
                        onSend: {
                            Task {
                                await viewModel.sendReply(
                                    content: replyText,
                                    isInternal: isInternalNote
                                )
                                replyText = ""
                                isComposingReply = false
                            }
                        },
                        onCancel: {
                            replyText = ""
                            isComposingReply = false
                        }
                    )
                } else {
                    // Action toolbar
                    TicketActionToolbar(
                        ticket: ticket,
                        onReply: { isComposingReply = true },
                        viewModel: viewModel
                    )
                }
            }
            .task {
                await viewModel.loadTicket(id: ticketId)
            }
        } else if viewModel.isLoading {
            ProgressView("Loading ticket...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.error {
            Text("Error: \(error)")
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct TicketHeaderView: View {
    let ticket: TicketDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Subject and ticket number
            HStack {
                Text(ticket.subject)
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Text(ticket.ticketNumber)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // Metadata
            HStack(spacing: 16) {
                Label(ticket.requester, systemImage: "person.circle")
                    .font(.subheadline)

                if let email = ticket.requesterEmail {
                    Text(email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                PriorityBadge(priority: ticket.priority)
                StatusBadge(status: ticket.status)
            }

            // Tags
            if !ticket.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ticket.tags, id: \.self) { tag in
                            TagView(tag: tag)
                        }
                    }
                }
            }

            // Assignee and dates
            HStack {
                if let assignee = ticket.assignee {
                    Label(assignee, systemImage: "person.badge.shield.checkmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Label("Unassigned", systemImage: "person.crop.circle.badge.questionmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("Created \(ticket.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct ConversationMessageView: View {
    let message: TicketConversation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: message.isSystemMessage ? "gear" : "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(message.isInternal ? .orange : .blue)

                VStack(alignment: .leading) {
                    HStack {
                        Text(message.authorName)
                            .fontWeight(.medium)

                        if message.isInternal {
                            Text("Internal Note")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .clipShape(Capsule())
                        }

                        Spacer()

                        Text(message.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if message.isSystemMessage {
                        Text(systemMessageText(for: message))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }

            if !message.isSystemMessage {
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(.leading, 40)
            }
        }
    }

    private func systemMessageText(for message: TicketConversation) -> String {
        switch message.messageType {
        case .statusChange:
            return "changed the status"
        case .assignmentChange:
            return "changed the assignment"
        default:
            return message.content
        }
    }
}

struct ReplyComposeView: View {
    @Binding var replyText: String
    @Binding var isInternalNote: Bool
    let onSend: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle("Internal Note", isOn: $isInternalNote)
                    .toggleStyle(.checkbox)

                Spacer()

                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)

                Button("Send", action: onSend)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(replyText.isEmpty)
            }
            .padding()

            Divider()

            TextEditor(text: $replyText)
                .font(.body)
                .padding(8)
                .background(isInternalNote ? Color.orange.opacity(0.05) : Color.clear)
                .frame(minHeight: 100)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct TicketActionToolbar: View {
    let ticket: TicketDetail
    let onReply: () -> Void
    @ObservedObject var viewModel: TicketDetailViewModel

    var body: some View {
        HStack {
            Button(action: onReply) {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }

            Divider()
                .frame(height: 20)

            Menu {
                ForEach(TicketStatus.allCases, id: \.self) { status in
                    Button(status.displayName) {
                        Task {
                            await viewModel.updateStatus(status)
                        }
                    }
                }
            } label: {
                Label("Status", systemImage: "circle.hexagongrid")
            }

            Menu {
                ForEach(TicketPriority.allCases, id: \.self) { priority in
                    Button(priority.displayName) {
                        Task {
                            await viewModel.updatePriority(priority)
                        }
                    }
                }
            } label: {
                Label("Priority", systemImage: "flag")
            }

            Divider()
                .frame(height: 20)

            Button(action: {}) {
                Label("Assign", systemImage: "person.badge.plus")
            }

            Button(action: {}) {
                Label("Add Tag", systemImage: "tag")
            }

            Spacer()

            Button(action: {}) {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct TagView: View {
    let tag: String

    var body: some View {
        Text(tag)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

@MainActor
class TicketDetailViewModel: ObservableObject {
    @Published var ticket: TicketDetail?
    @Published var conversations: [TicketConversation] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var newMessageContent = ""
    @Published var isInternalNote = false

    func loadTicket(id: UUID) async {
        isLoading = true
        error = nil

        // In a real implementation, this would fetch from the database
        // For now, we'll use mock data
        do {
            try await Task.sleep(nanoseconds: 500_000_000)  // Simulate network delay

            ticket = TicketDetail(
                id: id,
                ticketNumber: "TKT-000042",
                subject: "Unable to access account after password reset",
                description:
                    "I followed the password reset instructions sent to my email, but I'm still unable to log in to my account. I've tried multiple times and even requested a new password reset link, but nothing seems to work. This is urgent as I need to access my account for an important deadline.",
                requester: "Jane Smith",
                requesterEmail: "jane.smith@example.com",
                assignee: "Support Team",
                priority: .high,
                status: .open,
                source: .email,
                tags: ["billing", "urgent", "account-access"],
                createdAt: Date().addingTimeInterval(-3600),
                updatedAt: Date().addingTimeInterval(-1800)
            )

            conversations = [
                TicketConversation(
                    id: UUID(),
                    ticketId: id,
                    authorName: "Support Team",
                    content:
                        "Thank you for reaching out. I understand how frustrating this must be. Let me help you regain access to your account. Can you please confirm the email address associated with your account?",
                    contentType: "text",
                    isInternal: false,
                    isSystemMessage: false,
                    messageType: .comment,
                    createdAt: Date().addingTimeInterval(-1700)
                ),
                TicketConversation(
                    id: UUID(),
                    ticketId: id,
                    authorName: "System",
                    content: "Status changed from New to Open",
                    contentType: "text",
                    isInternal: false,
                    isSystemMessage: true,
                    messageType: .statusChange,
                    createdAt: Date().addingTimeInterval(-1650)
                ),
                TicketConversation(
                    id: UUID(),
                    ticketId: id,
                    authorName: "Support Team",
                    content:
                        "Customer's account shows multiple failed login attempts. Checking for potential security flags.",
                    contentType: "text",
                    isInternal: true,
                    isSystemMessage: false,
                    messageType: .comment,
                    createdAt: Date().addingTimeInterval(-1600)
                ),
            ]

            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }

    func sendReply(content: String, isInternal: Bool) async {
        guard let ticket = ticket else { return }

        let newMessage = TicketConversation(
            id: UUID(),
            ticketId: ticket.id,
            authorName: "Current User",
            content: content,
            contentType: "text",
            isInternal: isInternal,
            isSystemMessage: false,
            messageType: .comment,
            createdAt: Date()
        )

        conversations.append(newMessage)
    }

    func updateStatus(_ status: TicketStatus) async {
        guard var ticket = ticket else { return }

        let oldStatus = ticket.status
        ticket.status = status
        self.ticket = ticket

        let statusMessage = TicketConversation(
            id: UUID(),
            ticketId: ticket.id,
            authorName: "System",
            content: "Status changed from \(oldStatus.displayName) to \(status.displayName)",
            contentType: "text",
            isInternal: false,
            isSystemMessage: true,
            messageType: .statusChange,
            createdAt: Date()
        )

        conversations.append(statusMessage)
    }

    func updatePriority(_ priority: TicketPriority) async {
        guard var ticket = ticket else { return }
        ticket.priority = priority
        self.ticket = ticket
    }
}
#endif
