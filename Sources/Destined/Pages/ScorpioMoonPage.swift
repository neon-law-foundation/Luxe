import Elementary
import TouchMenu
import VaporElementary

struct ScorpioMoonPage: HTMLDocument {
    var title: String { "Scorpio Moon - Destined" }

    var head: some HTML {
        Elementary.title { title }
    }

    var body: some HTML {
        main {
            section {
                MarkdownContent(filename: "astrology/scorpio-moon")
            }
        }
        customFooter
    }

    private var customFooter: some HTML {
        footer(.class("footer has-background-dark")) {
            div(.class("container has-text-centered")) {
                p(.class("has-text-grey-light")) {
                    "Destined is a Sagebrush Services powered company"
                }
            }
        }
    }
}
