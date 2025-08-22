import Elementary
import Foundation
import TouchMenu

/// Navigation component for Standards section
struct StandardsNavigation: HTML {
    var content: some HTML {
        nav(.class("navbar is-primary")) {
            div(.class("navbar-brand")) {
                a(.class("navbar-item"), .href("/standards")) {
                    strong { "Sagebrush Standards" }
                }
            }
            div(.class("navbar-menu")) {
                div(.class("navbar-start")) {
                    a(.class("navbar-item"), .href("/standards")) { "Home" }
                    a(.class("navbar-item"), .href("/standards/spec")) { "Specification" }
                    a(.class("navbar-item"), .href("/standards/notations")) { "Notations" }
                }
                div(.class("navbar-end")) {
                    div(.class("navbar-item")) {
                        div(.class("buttons")) {
                            a(.class("button is-light is-rounded"), .href("/")) { "Back to Sagebrush" }
                            a(.class("button is-light is-rounded"), .href("mailto:standards@sagebrush.services")) {
                                "Contact"
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Footer component for Standards section
struct StandardsFooterComponent {
    static func standardsFooter() -> some HTML {
        footer(.class("footer has-background-dark has-text-light")) {
            div(.class("container")) {
                div(.class("columns")) {
                    div(.class("column is-half")) {
                        h4(.class("title is-5 has-text-light")) { "Our Network" }
                        div(.class("content")) {
                            ul {
                                li {
                                    a(.class("has-text-light"), .href("https://www.neonlaw.com"), .target("_blank")) {
                                        "Neon Law"
                                    }
                                }
                                li {
                                    a(.class("has-text-light"), .href("https://www.neonlaw.org"), .target("_blank")) {
                                        "Neon Law Foundation"
                                    }
                                }
                                li {
                                    a(
                                        .class("has-text-light"),
                                        .href("https://www.sagebrush.services"),
                                        .target("_blank")
                                    ) { "Sagebrush Services" }
                                }
                                li {
                                    a(
                                        .class("has-text-light"),
                                        .href("https://standards.sagebrush.services"),
                                        .target("_blank")
                                    ) { "Sagebrush Standards" }
                                }
                            }
                        }
                    }
                    div(.class("column is-half")) {
                        h4(.class("title is-5 has-text-light")) { "Contact" }
                        div(.class("content")) {
                            p {
                                "Support: "
                                a(.class("has-text-light"), .href("mailto:support@sagebrush.services")) {
                                    "support@sagebrush.services"
                                }
                            }
                        }
                    }
                }
                hr(.class("has-background-grey"))
                div(.class("has-text-centered")) {
                    p(.class("has-text-grey-light")) { "© 2025 Sagebrush. All rights reserved." }
                }
            }
        }
    }
}

/// Header component for Standards section
struct StandardsHeaderComponent {
    static func standardsTheme() -> some HTML {
        style {
            """
            :root {
                --primary-color: #663399;
                --secondary-color: #FFB6C1;
            }
            .hero.is-primary {
                background-color: var(--primary-color) !important;
            }
            .button.is-primary {
                background-color: var(--primary-color) !important;
                border-color: var(--primary-color) !important;
            }
            .button.is-info {
                background-color: var(--secondary-color) !important;
                border-color: var(--secondary-color) !important;
                color: #363636 !important;
            }
            .navbar.is-primary {
                background-color: var(--primary-color) !important;
            }
            .has-text-primary {
                color: var(--primary-color) !important;
            }
            .has-background-primary {
                background-color: var(--primary-color) !important;
            }
            pre {
                max-height: 500px;
                overflow-y: auto;
                font-family: "Monaco", monospace;
            }
            code {
                white-space: pre-wrap;
                word-wrap: break-word;
                font-family: "Monaco", monospace;
            }
            """
        }
    }
}

/// Component for rendering markdown files as HTML content
struct StandardsMarkdownContent: HTML {
    let filename: String

    var content: some HTML {
        let standardsStyle = TouchMenu.MarkdownContent.StyleOptions(
            headingClass: "title has-text-primary",
            paragraphClass: "content",
            linkClass: "has-text-primary",
            listClass: "content",
            codeClass: "has-background-light",
            preClass: "code"
        )

        return TouchMenu.MarkdownContent(
            filename: filename,
            bundle: .module,
            subdirectory: "Markdown",
            style: standardsStyle
        )
    }
}

/// Component for rendering YAML files as formatted code blocks
struct StandardsYAMLContent: HTML {
    let filepath: String

    var content: some HTML {
        // Load from filesystem - look for Notations directory relative to current working directory
        let currentDir = FileManager.default.currentDirectoryPath
        let notationsPath = URL(fileURLWithPath: currentDir)
            .appendingPathComponent("Sources")
            .appendingPathComponent("SagebrushWeb")
            .appendingPathComponent("Notations")
            .appendingPathComponent("\(filepath).yaml")

        if let yamlContent = try? String(contentsOf: notationsPath, encoding: .utf8) {
            div(.class("content")) {
                h3(.class("title is-4 has-text-primary")) { "YAML Configuration: \(filepath)" }
                pre(.class("has-background-light")) {
                    code(.class("language-yaml")) {
                        yamlContent
                    }
                }
            }
        } else {
            div(.class("notification is-danger")) {
                "Error: Could not load YAML file at \(filepath).yaml from \(notationsPath.path)"
            }
        }
    }
}
