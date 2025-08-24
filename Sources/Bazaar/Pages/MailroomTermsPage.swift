import Elementary
import TouchMenu
import VaporElementary

struct MailroomTermsPage: HTMLDocument {
    var title: String { "Mailroom Terms and Conditions - Sagebrush Services" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation()
        div(.class("container")) {
            div(.class("content section")) {
                MarkdownContent(filename: "mailroom-terms")
            }
        }
        FooterComponent.sagebrushFooter()
    }
}
