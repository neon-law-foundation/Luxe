import Elementary
import Foundation
import TouchMenu
import VaporElementary

struct BlogPage: HTMLDocument {
    var title: String { "Blog - Sagebrush Physical Address" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation()
        BlogIndexContent()
        FooterComponent.sagebrushFooter()
    }
}

struct BlogIndexContent: HTML {
    var content: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                h1(.class("title is-1 has-text-primary has-text-centered")) { "Sagebrush Blog" }
                p(.class("subtitle has-text-centered")) { "Insights and tips for physical address services" }

                div(.class("columns is-multiline")) {
                    DynamicBlogCards()
                }
            }
        }
    }
}

struct DynamicBlogCards: HTML {
    var content: some HTML {
        BlogCard9()  // S Corp Election for LLCs
        BlogCard8()  // Nevada Virtual Creators
        BlogCard2()  // a16z Leaving Delaware
        BlogCard3()  // Digital Nomads
        BlogCard4()  // Cap Table Equity
        BlogCard5()  // Why Every Business Needs
        BlogCard7()  // One Year Cliff
        BlogCard6()  // Why Nevada
    }
}

struct BlogCard9: HTML {  // S Corp Election for LLCs
    var content: some HTML {
        div(.class("column is-half")) {
            div(.class("card")) {
                div(.class("card-header")) {
                    p(.class("card-header-title")) { "S Corp Election for LLCs: A Complete Guide to Form 2553" }
                }
                div(.class("card-content")) {
                    div(.class("content")) {
                        p {
                            "Learn how LLCs can elect S Corp tax treatment using Form 2553, including filing deadlines, requirements, and potential self-employment tax savings for profitable businesses..."
                        }
                        a(
                            .href(
                                "https://github.com/neon-law-foundation/Luxe/tree/main/Sources/Bazaar/Markdown/s-corp-election-llc-form-2553.md"
                            ),
                            .target("_blank"),
                            .rel("noreferrer"),
                            .class("has-text-primary is-size-7")
                        ) {
                            "View on GitHub"
                        }
                    }
                }
                footer(.class("card-footer")) {
                    a(.class("card-footer-item button is-primary"), .href("/blog/s-corp-election-llc-form-2553")) {
                        "Read More"
                    }
                }
            }
        }
    }
}

struct BlogCard8: HTML {  // Nevada Virtual Creators
    var content: some HTML {
        div(.class("column is-half")) {
            div(.class("card")) {
                div(.class("card-header")) {
                    p(.class("card-header-title")) { "Why Nevada is Perfect for Virtual Creators" }
                }
                div(.class("card-content")) {
                    div(.class("content")) {
                        p {
                            "Discover why Nevada offers unbeatable advantages for virtual creators, influencers, and content creators earning from Instagram, TikTok, OnlyFans, and other digital platforms..."
                        }
                        a(
                            .href(
                                "https://github.com/neon-law-foundation/Luxe/tree/main/Sources/Bazaar/Markdown/nevada-virtual-creators.md"
                            ),
                            .target("_blank"),
                            .rel("noreferrer"),
                            .class("has-text-primary is-size-7")
                        ) {
                            "View on GitHub"
                        }
                    }
                }
                footer(.class("card-footer")) {
                    a(.class("card-footer-item button is-primary"), .href("/blog/nevada-virtual-creators")) {
                        "Read More"
                    }
                }
            }
        }
    }
}

struct BlogCard2: HTML {  // Why Nevada
    var content: some HTML {
        div(.class("column is-half")) {
            div(.class("card")) {
                div(.class("card-header")) {
                    p(.class("card-header-title")) { "Why a16z is Leaving Delaware for Nevada" }
                }
                div(.class("card-content")) {
                    div(.class("content")) {
                        p {
                            "Andreessen Horowitz, the most reputable VC firm, is abandoning Delaware. Learn why Nevada's superior corporate framework makes it the clear choice for modern companies..."
                        }
                        a(
                            .href(
                                "https://github.com/neon-law-foundation/Luxe/tree/main/Sources/Bazaar/Markdown/a16z-leaving-delaware.md"
                            ),
                            .target("_blank"),
                            .rel("noreferrer"),
                            .class("has-text-primary is-size-7")
                        ) {
                            "View on GitHub"
                        }
                    }
                }
                footer(.class("card-footer")) {
                    a(.class("card-footer-item button is-primary"), .href("/blog/a16z-leaving-delaware")) {
                        "Read More"
                    }
                }
            }
        }
    }
}

struct BlogCard3: HTML {  // Digital Nomads
    var content: some HTML {
        div(.class("column is-half")) {
            div(.class("card")) {
                div(.class("card-header")) {
                    p(.class("card-header-title")) { "Why Digital Nomads Need Physical Address Services" }
                }
                div(.class("card-content")) {
                    div(.class("content")) {
                        p {
                            "Discover how physical address services enable true location independence for entrepreneurs working from Bali, Vietnam, and beyond..."
                        }
                        a(
                            .href(
                                "https://github.com/neon-law-foundation/Luxe/tree/main/Sources/Bazaar/Markdown/digital-nomad-virtual-mailbox.md"
                            ),
                            .target("_blank"),
                            .rel("noreferrer"),
                            .class("has-text-primary is-size-7")
                        ) {
                            "View on GitHub"
                        }
                    }
                }
                footer(.class("card-footer")) {
                    a(.class("card-footer-item button is-primary"), .href("/blog/digital-nomad-virtual-mailbox")) {
                        "Read More"
                    }
                }
            }
        }
    }
}

struct BlogCard4: HTML {  // Cap Table Equity
    var content: some HTML {
        div(.class("column is-half")) {
            div(.class("card")) {
                div(.class("card-header")) {
                    p(.class("card-header-title")) { "Understanding Cap Tables and Equity Sharing in Nevada" }
                }
                div(.class("card-content")) {
                    div(.class("content")) {
                        p {
                            "Learn how cap tables work and why transparent equity sharing matters for Nevada LLCs and C-Corps. From vesting schedules to fair compensation..."
                        }
                        a(
                            .href(
                                "https://github.com/neon-law-foundation/Luxe/tree/main/Sources/Bazaar/Markdown/cap-table-equity.md"
                            ),
                            .target("_blank"),
                            .rel("noreferrer"),
                            .class("has-text-primary is-size-7")
                        ) {
                            "View on GitHub"
                        }
                    }
                }
                footer(.class("card-footer")) {
                    a(.class("card-footer-item button is-primary"), .href("/blog/cap-table-equity")) {
                        "Read More"
                    }
                }
            }
        }
    }
}

struct BlogCard5: HTML {  // Why Every Business Needs
    var content: some HTML {
        div(.class("column is-half")) {
            div(.class("card")) {
                div(.class("card-header")) {
                    p(.class("card-header-title")) { "Why Every Business Needs a Cap Table" }
                }
                div(.class("card-content")) {
                    div(.class("content")) {
                        p {
                            "Every business is unique, and transparent equity management is the foundation of successful partnerships. Learn why clear rules and responsibilities matter from day one..."
                        }
                        a(
                            .href(
                                "https://github.com/neon-law-foundation/Luxe/tree/main/Sources/Bazaar/Markdown/why-every-business-needs-cap-table.md"
                            ),
                            .target("_blank"),
                            .rel("noreferrer"),
                            .class("has-text-primary is-size-7")
                        ) {
                            "View on GitHub"
                        }
                    }
                }
                footer(.class("card-footer")) {
                    a(.class("card-footer-item button is-primary"), .href("/blog/why-every-business-needs-cap-table")) {
                        "Read More"
                    }
                }
            }
        }
    }
}

struct BlogCard7: HTML {  // One Year Cliff
    var content: some HTML {
        div(.class("column is-half")) {
            div(.class("card")) {
                div(.class("card-header")) {
                    p(.class("card-header-title")) { "Why the One-Year Cliff is Essential for Protecting Your Startup" }
                }
                div(.class("card-content")) {
                    div(.class("content")) {
                        p {
                            "Learn why the one-year cliff protects startups and how Nevada's business-friendly environment makes it ideal for equity management through Sagebrush's Reno headquarters..."
                        }
                        a(
                            .href(
                                "https://github.com/neon-law-foundation/Luxe/tree/main/Sources/Bazaar/Markdown/one-year-cliff.md"
                            ),
                            .target("_blank"),
                            .rel("noreferrer"),
                            .class("has-text-primary is-size-7")
                        ) {
                            "View on GitHub"
                        }
                    }
                }
                footer(.class("card-footer")) {
                    a(.class("card-footer-item button is-primary"), .href("/blog/one-year-cliff")) {
                        "Read More"
                    }
                }
            }
        }
    }
}

struct BlogCard6: HTML {  // Why Nevada
    var content: some HTML {
        div(.class("column is-half")) {
            div(.class("card")) {
                div(.class("card-header")) {
                    p(.class("card-header-title")) { "Why Nevada for Your Physical Address" }
                }
                div(.class("card-content")) {
                    div(.class("content")) {
                        p {
                            "Learn why Nevada is the ideal state for your physical address service. From business-friendly laws to strategic location..."
                        }
                        a(
                            .href(
                                "https://github.com/neon-law-foundation/Luxe/tree/main/Sources/Bazaar/Markdown/why-nevada.md"
                            ),
                            .target("_blank"),
                            .rel("noreferrer"),
                            .class("has-text-primary is-size-7")
                        ) {
                            "View on GitHub"
                        }
                    }
                }
                footer(.class("card-footer")) {
                    a(.class("card-footer-item button is-primary"), .href("/blog/why-nevada")) { "Read More" }
                }
            }
        }
    }
}
