import Elementary
import VaporElementary

struct ScorpioPage: HTMLDocument {
    var title: String { "Scorpio - Destined" }

    var head: some HTML {
        Elementary.title { title }
    }

    var body: some HTML {
        main {
            section {
                h1 { "Scorpio" }
                p {
                    """
                    Explore the depths of Scorpio energy through its various astrological placements. Scorpio represents
                    transformation, intensity, and the power of regeneration.
                    """
                }

                h2 { "Placements" }
                ul {
                    li {
                        a(.href("/scorpio/moon")) { "Scorpio Moon" }
                        " - The emotional depths and transformative power of Moon in Scorpio"
                    }
                }
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
