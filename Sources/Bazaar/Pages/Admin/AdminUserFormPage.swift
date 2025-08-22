import Bouncer
import Dali
import Elementary
import TouchMenu
import VaporElementary

struct AdminUserFormPage: HTMLDocument {
    let existingData: CreateUserFormData?
    let currentUser: User?

    var title: String { "Create New User - Admin" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        heroSection
        formSection
        FooterComponent.sagebrushFooter()
    }

    private var heroSection: some HTML {
        section(.class("hero is-primary")) {
            div(.class("hero-body")) {
                div(.class("container")) {
                    h1(.class("title is-1 has-text-white")) { title }
                    h2(.class("subtitle is-3 has-text-white")) {
                        "Create a new user account and associated person record"
                    }
                }
            }
        }
    }

    private var formSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                div(.class("columns is-centered")) {
                    div(.class("column is-8")) {
                        div(.class("card")) {
                            div(.class("card-header")) {
                                p(.class("card-header-title")) {
                                    "Create New User"
                                }
                            }
                            div(.class("card-content")) {
                                userForm
                            }
                        }
                    }
                }
            }
        }
    }

    private var userForm: some HTML {
        form(.method(.post), .action("/admin/users")) {
            div(.class("field")) {
                label(.class("label")) { "Full Name" }
                div(.class("control")) {
                    input(
                        .class("input"),
                        .type(.text),
                        .name("name"),
                        .value(existingData?.name ?? ""),
                        .required,
                        .placeholder("Enter the person's full name")
                    )
                }
                p(.class("help")) { "The person's full name as it should appear in the system" }
            }

            div(.class("field")) {
                label(.class("label")) { "Email Address" }
                div(.class("control")) {
                    input(
                        .class("input"),
                        .type(.email),
                        .name("email"),
                        .value(existingData?.email ?? ""),
                        .required,
                        .placeholder("Enter email address"),
                        .id("email-input")
                    )
                }
                p(.class("help")) { "The person's email address (will be normalized to lowercase)" }
                p(.class("help is-danger"), .id("email-error"), .style("display: none;")) {
                    "Please enter a valid email address"
                }
            }

            div(.class("field")) {
                label(.class("label")) { "User Role" }
                div(.class("control")) {
                    div(.class("select")) {
                        select(.name("role"), .required) {
                            if existingData?.role == nil {
                                option(.value(""), .disabled, .selected) {
                                    "Select a role"
                                }
                            } else {
                                option(.value(""), .disabled) {
                                    "Select a role"
                                }
                            }
                            for role in UserRole.allCases {
                                if existingData?.role == role.rawValue {
                                    option(.value(role.rawValue), .selected) {
                                        "\(role.displayName) - \(roleDescription(role))"
                                    }
                                } else {
                                    option(.value(role.rawValue)) {
                                        "\(role.displayName) - \(roleDescription(role))"
                                    }
                                }
                            }
                        }
                    }
                }
                p(.class("help")) { "The user's role determines their access level in the system" }
            }

            roleDescriptions
            formScripts

            div(.class("field is-grouped")) {
                div(.class("control")) {
                    button(.class("button is-primary is-rounded"), .type(.submit)) {
                        "Create User"
                    }
                }
                div(.class("control")) {
                    a(.class("button is-light is-rounded"), .href("/admin/users")) {
                        "Cancel"
                    }
                }
            }
        }
    }

    private var roleDescriptions: some HTML {
        div(.class("box has-background-light")) {
            h4(.class("title is-6")) { "Role Descriptions:" }
            div(.class("content")) {
                ul {
                    li {
                        strong { "Customer" }
                        " - Standard users who can access their own data and basic features"
                    }
                    li {
                        strong { "Staff" }
                        " - Employees with elevated access to manage customer data and operations"
                    }
                    li {
                        strong { "Admin" }
                        " - Full system access including user management and system configuration"
                    }
                }
            }
        }
    }

    private var formScripts: some HTML {
        script {
            """
            function validateEmail() {
                const emailInput = document.getElementById('email-input');
                const emailError = document.getElementById('email-error');
                const emailPattern = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$/;

                if (emailInput.value && !emailPattern.test(emailInput.value)) {
                    emailError.style.display = 'block';
                    emailInput.classList.add('is-danger');
                } else {
                    emailError.style.display = 'none';
                    emailInput.classList.remove('is-danger');
                }
            }

            // Validate email on input
            document.getElementById('email-input').addEventListener('input', validateEmail);
            """
        }
    }

    private func roleDescription(_ role: UserRole) -> String {
        switch role {
        case .customer: return "Standard user access"
        case .staff: return "Employee access"
        case .admin: return "Full administrative access"
        }
    }
}

/// Form data structure for creating users
struct CreateUserFormData {
    let name: String?
    let email: String?
    let role: String?
}
