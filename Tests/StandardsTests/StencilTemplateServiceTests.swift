import Foundation
import Testing

@testable import Standards

@Suite("StencilTemplateService")
struct StencilTemplateServiceTests {
    let service = StandardsTemplateService()

    @Test("Renders simple variable interpolation")
    func testSimpleVariableInterpolation() throws {
        let template = "Hello {{ name }}, welcome to {{ place }}!"
        let context = [
            "name": "John",
            "place": "Standards",
        ]

        let result = try service.render(template, context: context)
        #expect(result == "Hello John, welcome to Standards!")
    }

    @Test("Renders with missing variables shows empty")
    func testRenderWithMissingVariable() throws {
        let template = "Hello {{ name }}, your age is {{ age }}"
        let context = ["name": "Alice"]

        let result = try service.render(template, context: context)
        #expect(result == "Hello Alice, your age is ")
    }

    @Test("Extracts variables from template")
    func testExtractVariables() throws {
        let template = """
            Dear {{ client_name }},

            Your organization {{ organization_name }} has requested {{ service_type }}.

            The effective date will be {{ start_date }}.
            """

        let variables = try service.extractVariables(from: template)
        #expect(variables == ["client_name", "organization_name", "service_type", "start_date"])
    }

    @Test("Extracts variables with dot notation")
    func testExtractVariablesWithDotNotation() throws {
        let template = """
            Name: {{ user.name }}
            Email: {{ user.email }}
            Company: {{ user.company.name }}
            """

        let variables = try service.extractVariables(from: template)
        #expect(variables == ["user"])
    }

    @Test("Validates context with all variables present")
    func testValidateContextAllPresent() throws {
        let template = "Hello {{ name }}, you are {{ age }} years old"
        let context: [String: Any] = [
            "name": "Bob",
            "age": 30,
        ]

        let result = try service.validateContext(template, context: context)
        #expect(result.isValid == true)
        #expect(result.missingVariables.isEmpty == true)
    }

    @Test("Validates context with missing variables")
    func testValidateContextWithMissing() throws {
        let template = "{{ firstName }} {{ lastName }} from {{ company }}"
        let context = [
            "firstName": "Jane"
        ]

        let result = try service.validateContext(template, context: context)
        #expect(result.isValid == false)
        #expect(result.missingVariables == ["lastName", "company"])
    }

    @Test("Renders with conditional blocks")
    func testConditionalRendering() throws {
        let template = """
            {% if isPremium %}
            Welcome Premium Member!
            {% else %}
            Welcome Standard Member!
            {% endif %}
            """

        let premiumContext = ["isPremium": true]
        let standardContext = ["isPremium": false]

        let premiumResult = try service.render(template, context: premiumContext)
        #expect(premiumResult.contains("Welcome Premium Member!"))

        let standardResult = try service.render(template, context: standardContext)
        #expect(standardResult.contains("Welcome Standard Member!"))
    }

    @Test("Renders with for loops")
    func testForLoopRendering() throws {
        let template = """
            {% for item in items %}
            - {{ item }}
            {% endfor %}
            """

        let context = [
            "items": ["Apple", "Banana", "Orange"]
        ]

        let result = try service.render(template, context: context)
        #expect(result.contains("- Apple"))
        #expect(result.contains("- Banana"))
        #expect(result.contains("- Orange"))
    }

    @Test("Renders with date filter")
    func testDateFilter() throws {
        let template = "The meeting is on {{ meetingDate|date }}"

        let date = Date(timeIntervalSince1970: 1_609_459_200)  // 2021-01-01 00:00:00 UTC
        let context = ["meetingDate": date]

        let result = try service.render(template, context: context)
        #expect(result.contains("2021") || result.contains("2020"))  // Handles timezone differences
    }

    @Test("Renders with currency filter")
    func testCurrencyFilter() throws {
        let template = "Total amount: {{ amount|currency }}"
        let context = ["amount": 1234.56]

        let result = try service.render(template, context: context)
        #expect(result.contains("1,234") || result.contains("1234"))  // Handles locale differences
    }

    @Test("Extracts variables from conditional blocks")
    func testExtractVariablesFromConditionals() throws {
        let template = """
            {% if user_type == "admin" %}
            Admin panel for {{ admin_name }}
            {% elif user_type == "moderator" %}
            Moderator panel for {{ mod_name }}
            {% else %}
            User panel for {{ user_name }}
            {% endif %}
            """

        let variables = try service.extractVariables(from: template)
        #expect(variables.contains("user_type"))
        #expect(variables.contains("admin_name"))
        #expect(variables.contains("mod_name"))
        #expect(variables.contains("user_name"))
    }

    @Test("Complex template with mixed features")
    func testComplexTemplate() throws {
        let template = """
            Dear {{ client.name }},

            {% if services %}
            Your requested services:
            {% for service in services %}
            - {{ service.name }}: {{ service.price|currency }}
            {% endfor %}
            {% endif %}

            Total: {{ total|currency }}
            Due date: {{ due_date|date }}

            {% if discount > 0 %}
            Discount applied: {{ discount }}%
            {% endif %}
            """

        let context: [String: Any] = [
            "client": ["name": "Acme Corp"],
            "services": [
                ["name": "Consulting", "price": 1000.0],
                ["name": "Development", "price": 2000.0],
            ],
            "total": 3000.0,
            "due_date": Date(),
            "discount": 10,
        ]

        let result = try service.render(template, context: context)
        #expect(result.contains("Dear Acme Corp"))
        #expect(result.contains("Consulting"))
        #expect(result.contains("Development"))
        #expect(result.contains("Discount applied: 10%"))
    }
}
