import Bouncer
import Dali
import Elementary
import TouchMenu
import VaporElementary

struct AdminPeopleListPage: HTMLDocument {
    let people: [Person]
    let currentUser: User?

    var title: String { "People Management - Admin" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        breadcrumbSection
        heroSection
        peopleSection
        FooterComponent.sagebrushFooter()
    }

    private var breadcrumbSection: some HTML {
        section(.class("section is-small")) {
            div(.class("container")) {
                BreadcrumbComponent.adminPeople()
            }
        }
    }

    private var heroSection: some HTML {
        section(.class("hero is-primary")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { "People Management" }
                    h2(.class("subtitle is-3 has-text-white")) { "Manage all people in the system" }
                }
            }
        }
    }

    private var peopleSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                div(.class("level")) {
                    div(.class("level-left")) {
                        h2(.class("title is-3")) { "All People" }
                    }
                    div(.class("level-right")) {
                        a(.class("button is-primary"), .href("/admin/people/new")) {
                            "Add New Person"
                        }
                    }
                }

                if people.isEmpty {
                    div(.class("notification is-info")) {
                        "No people found. "
                        a(.href("/admin/people/new")) { "Create the first person" }
                        "."
                    }
                } else {
                    div(.class("table-container")) {
                        table(.class("table is-fullwidth is-hoverable")) {
                            thead {
                                tr {
                                    th { "Name" }
                                    th { "Email" }
                                    th { "Actions" }
                                }
                            }
                            tbody {
                                peopleRowsContent
                            }
                        }
                    }
                }
            }
        }
    }

    private var peopleRowsContent: some HTML {
        ForEach(people) { person in
            personRow(person)
        }
    }

    private func personRow(_ person: Person) -> some HTML {
        tr {
            td {
                a(.href("/admin/people/\((try? person.requireID())?.uuidString ?? "")")) {
                    person.name
                }
            }
            td { person.email }
            td {
                div(.class("buttons")) {
                    a(
                        .class("button is-small is-info"),
                        .href("/admin/people/\((try? person.requireID())?.uuidString ?? "")")
                    ) {
                        "View"
                    }
                    a(
                        .class("button is-small is-warning"),
                        .href("/admin/people/\((try? person.requireID())?.uuidString ?? "")/edit")
                    ) {
                        "Edit"
                    }
                    a(
                        .class("button is-small is-danger"),
                        .href("/admin/people/\((try? person.requireID())?.uuidString ?? "")/delete")
                    ) {
                        "Delete"
                    }
                }
            }
        }
    }
}
