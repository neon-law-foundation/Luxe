import Bouncer
import Dali
import Elementary
import TouchMenu
import VaporElementary

struct AdminQuestionDetailPage: HTMLDocument {
    let question: Question
    let currentUser: User?

    var title: String { "\(question.prompt) - Question Details" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        breadcrumbSection
        heroSection
        detailSection
        FooterComponent.sagebrushFooter()
    }

    private var breadcrumbSection: some HTML {
        section(.class("section is-small")) {
            div(.class("container")) {
                BreadcrumbComponent.adminQuestionDetail(questionPrompt: question.prompt)
            }
        }
    }

    private var heroSection: some HTML {
        section(.class("hero is-primary")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { question.prompt }
                    h2(.class("subtitle is-3 has-text-white")) { "Question Details" }
                }
            }
        }
    }

    private var detailSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                div(.class("columns")) {
                    div(.class("column is-8")) {
                        div(.class("card")) {
                            div(.class("card-header")) {
                                p(.class("card-header-title")) { "Question Information" }
                            }
                            div(.class("card-content")) {
                                questionFields
                            }
                        }
                    }
                    div(.class("column is-4")) {
                        div(.class("card")) {
                            div(.class("card-header")) {
                                p(.class("card-header-title")) { "Actions" }
                            }
                            div(.class("card-content")) {
                                actionButtons
                            }
                        }
                    }
                }
            }
        }
    }

    private var questionFields: some HTML {
        div(.class("content")) {
            div(.class("field")) {
                label(.class("label")) { "ID" }
                div(.class("control")) {
                    input(
                        .class("input"),
                        .type(.text),
                        .value((try? question.requireID())?.uuidString ?? "Unknown"),
                        .disabled
                    )
                }
            }

            div(.class("field")) {
                label(.class("label")) { "Prompt" }
                div(.class("control")) {
                    input(.class("input"), .type(.text), .value(question.prompt), .disabled)
                }
            }

            div(.class("field")) {
                label(.class("label")) { "Question Type" }
                div(.class("control")) {
                    input(.class("input"), .type(.text), .value(question.questionType.rawValue), .disabled)
                }
            }

            div(.class("field")) {
                label(.class("label")) { "Code" }
                div(.class("control")) {
                    input(.class("input"), .type(.text), .value(question.code), .disabled)
                }
            }

            if let helpText = question.helpText, !helpText.isEmpty {
                div(.class("field")) {
                    label(.class("label")) { "Help Text" }
                    div(.class("control")) {
                        textarea(.class("textarea"), .disabled) { helpText }
                    }
                }
            }

            if !question.choices.options.isEmpty {
                div(.class("field")) {
                    label(.class("label")) { "Choices" }
                    div(.class("control")) {
                        div(.class("content")) {
                            ul {
                                ForEach(question.choices.options) { choice in
                                    li { choice }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var actionButtons: some HTML {
        div(.class("content")) {
            a(.class("button is-light is-fullwidth"), .href("/admin/questions")) {
                "← Back to Questions List"
            }
        }
    }
}
