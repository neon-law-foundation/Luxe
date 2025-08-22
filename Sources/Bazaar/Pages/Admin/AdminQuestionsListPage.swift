import Bouncer
import Dali
import Elementary
import TouchMenu
import VaporElementary

struct AdminQuestionsListPage: HTMLDocument {
    let questions: [Question]
    let currentUser: User?

    var title: String { "Questions Management - Admin" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        breadcrumbSection
        heroSection
        questionsSection
        FooterComponent.sagebrushFooter()
    }

    private var breadcrumbSection: some HTML {
        section(.class("section is-small")) {
            div(.class("container")) {
                BreadcrumbComponent.adminQuestions()
            }
        }
    }

    private var heroSection: some HTML {
        section(.class("hero is-primary")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { "Questions Management" }
                    h2(.class("subtitle is-3 has-text-white")) { "Manage all questions in the system" }
                }
            }
        }
    }

    private var questionsSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                h2(.class("title is-3")) { "All Questions" }

                if questions.isEmpty {
                    div(.class("notification is-info")) {
                        "No questions found."
                    }
                } else {
                    div(.class("table-container")) {
                        table(.class("table is-fullwidth is-hoverable")) {
                            thead {
                                tr {
                                    th { "Prompt" }
                                    th { "Type" }
                                    th { "Code" }
                                    th { "Actions" }
                                }
                            }
                            tbody {
                                questionsRowsContent
                            }
                        }
                    }
                }
            }
        }
    }

    private var questionsRowsContent: some HTML {
        ForEach(questions) { question in
            questionRow(question)
        }
    }

    private func questionRow(_ question: Question) -> some HTML {
        tr {
            td {
                a(.href("/admin/questions/\((try? question.requireID())?.uuidString ?? "")")) {
                    question.prompt
                }
            }
            td { question.questionType.rawValue }
            td { question.code }
            td {
                div(.class("buttons")) {
                    a(
                        .class("button is-small is-info"),
                        .href("/admin/questions/\((try? question.requireID())?.uuidString ?? "")")
                    ) {
                        "View"
                    }
                }
            }
        }
    }
}
