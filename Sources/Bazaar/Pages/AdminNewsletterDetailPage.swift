import Bouncer
import Dali
import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct AdminNewsletterDetailPage: HTMLDocument {
    let newsletter: Newsletter
    let currentUser: User?

    var title: String { "Newsletter Details - Admin" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        section(.class("section")) {
            div(.class("container")) {
                h1(.class("title")) { "Newsletter Details" }
                p(.class("subtitle")) { newsletter.subjectLine }

                div(.class("card")) {
                    header(.class("card-header")) {
                        p(.class("card-header-title")) { "Newsletter Information" }
                    }
                    div(.class("card-content")) {
                        div(.class("content")) {
                            p { "Type: \(newsletterTypeName(newsletter.name))" }
                            p { "Subject: \(newsletter.subjectLine)" }
                            p { "Created: \(formatDate(newsletter.createdAt))" }
                            if let sentAt = newsletter.sentAt {
                                p { "Sent: \(formatDate(sentAt))" }
                            }
                        }
                    }
                }

                div(.class("card mt-5")) {
                    header(.class("card-header")) {
                        p(.class("card-header-title")) { "Content" }
                    }
                    div(.class("card-content")) {
                        pre {
                            newsletter.markdownContent
                        }
                    }
                }

                div(.class("buttons mt-5")) {
                    if newsletter.sentAt == nil {
                        button(.class("button is-success"), .id("send-btn")) {
                            "📨 Send Newsletter"
                        }
                    }

                    a(.class("button is-info"), .href("/admin/newsletters/\(newsletter.id.uuidString)/edit")) {
                        "✏️ Edit Newsletter"
                    }

                    a(.class("button"), .href("/admin/newsletters")) {
                        "← Back to Newsletters"
                    }
                }
            }
        }
        FooterComponent.sagebrushFooter()

        if newsletter.sentAt == nil {
            script {
                """
                document.getElementById('send-btn').onclick = function() {
                    if (confirm('Are you sure you want to send this newsletter?')) {
                        fetch('/api/admin/newsletters/\(newsletter.id.uuidString)/send', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' }
                        })
                        .then(response => {
                            if (response.ok) {
                                alert('Newsletter sent successfully!');
                                location.reload();
                            } else {
                                alert('Error sending newsletter');
                            }
                        })
                        .catch(() => alert('Error sending newsletter'));
                    }
                }
                """
            }
        }
    }

    private func newsletterTypeName(_ type: Newsletter.NewsletterName) -> String {
        switch type {
        case .nvSciTech: return "🔬 NV Sci Tech"
        case .sagebrush: return "🌾 Sagebrush"
        case .neonLaw: return "⚖️ Neon Law"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
