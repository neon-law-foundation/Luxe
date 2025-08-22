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
        // Ordered by most recent first (by creation date)
        BlogCard8()  // Nevada Virtual Creators - Jan 19, 2025
        BlogCard2()  // a16z Leaving Delaware - Jan 15, 2025
        BlogCard3()  // Digital Nomads - Jan 14, 2025
        BlogCard4()  // Cap Table Equity - Jan 12, 2025
        BlogCard5()  // Why Every Business Needs - Jan 11, 2025
        BlogCard7()  // One Year Cliff - Jan 10, 2025
        BlogCard6()  // Why Nevada - Jan 8, 2025
    }
}

// Ordered by most recent first
struct BlogCard8: HTML {  // Nevada Virtual Creators - Jan 19, 2025
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
                        p(.class("has-text-grey is-size-7")) { "Published: January 19, 2025" }
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

struct BlogCard2: HTML {  // Why Nevada - Jan 15, 2025
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
                        p(.class("has-text-grey is-size-7")) { "Published: January 15, 2025" }
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

struct BlogCard3: HTML {  // Digital Nomads - Jan 14, 2025
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
                        p(.class("has-text-grey is-size-7")) { "Published: January 14, 2025" }
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

struct BlogCard4: HTML {  // Cap Table Equity - Jan 12, 2025
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
                        p(.class("has-text-grey is-size-7")) { "Published: January 12, 2025" }
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

struct BlogCard5: HTML {  // Why Every Business Needs - Jan 11, 2025
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
                        p(.class("has-text-grey is-size-7")) { "Published: January 11, 2025" }
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

struct BlogCard7: HTML {  // One Year Cliff - Jan 10, 2025
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
                        p(.class("has-text-grey is-size-7")) { "Published: January 10, 2025" }
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

struct BlogCard6: HTML {  // Why Nevada - Jan 8, 2025
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
                        p(.class("has-text-grey is-size-7")) { "Published: January 8, 2025" }
                    }
                }
                footer(.class("card-footer")) {
                    a(.class("card-footer-item button is-primary"), .href("/blog/why-nevada")) { "Read More" }
                }
            }
        }
    }
}

extension DateFormatter {
    static let blogDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
