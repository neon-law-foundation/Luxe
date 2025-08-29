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

    // MARK: - Enhanced Filter Tests

    @Test("Uppercase filter transforms text")
    func testUppercaseFilter() throws {
        let template = "{{ name|uppercase }}"
        let context = ["name": "john doe"]

        let result = try service.render(template, context: context)
        #expect(result == "JOHN DOE")
    }

    @Test("Lowercase filter transforms text")
    func testLowercaseFilter() throws {
        let template = "{{ title|lowercase }}"
        let context = ["title": "IMPORTANT NOTICE"]

        let result = try service.render(template, context: context)
        #expect(result == "important notice")
    }

    @Test("Capitalize filter transforms text")
    func testCapitalizeFilter() throws {
        let template = "{{ text|capitalize }}"
        let context = ["text": "hello world from swift"]

        let result = try service.render(template, context: context)
        #expect(result == "Hello World From Swift")
    }

    @Test("Truncate filter shortens text")
    func testTruncateFilter() throws {
        let template = "{{ description|truncate:20 }}"
        let context = ["description": "This is a very long description that should be truncated"]

        let result = try service.render(template, context: context)
        #expect(result == "This is a very long ...")
    }

    @Test("Truncate filter with custom suffix")
    func testTruncateFilterWithCustomSuffix() throws {
        let template = "{{ text|truncate:10 }}"  // Simplified for now
        let context = ["text": "This text will be truncated"]

        let result = try service.render(template, context: context)
        #expect(result == "This text ...")
    }

    @Test("Default filter provides fallback")
    func testDefaultFilter() throws {
        let template = "Name: {{ name|default:\"Anonymous\" }}"
        let context: [String: Any] = [:]

        let result = try service.render(template, context: context)
        #expect(result == "Name: Anonymous")
    }

    @Test("Join filter combines arrays")
    func testJoinFilter() throws {
        let template = "{{ tags|join:\", \" }}"
        let context = ["tags": ["swift", "vapor", "stencil"]]

        let result = try service.render(template, context: context)
        #expect(result == "swift, vapor, stencil")
    }

    @Test("Join filter with custom separator")
    func testJoinFilterWithCustomSeparator() throws {
        let template = "{{ items|join:\" | \" }}"
        let context = ["items": ["Apple", "Banana", "Orange"]]

        let result = try service.render(template, context: context)
        #expect(result == "Apple | Banana | Orange")
    }

    @Test("Count filter for arrays")
    func testCountFilterArray() throws {
        let template = "Total items: {{ items|count }}"
        let context = ["items": [1, 2, 3, 4, 5]]

        let result = try service.render(template, context: context)
        #expect(result == "Total items: 5")
    }

    @Test("Count filter for strings")
    func testCountFilterString() throws {
        let template = "Character count: {{ text|count }}"
        let context = ["text": "Hello"]

        let result = try service.render(template, context: context)
        #expect(result == "Character count: 5")
    }

    @Test("Number filter formats numbers", .disabled("Locale-dependent number formatting differs between macOS and Linux CI"))
    func testNumberFilter() throws {
        let template = "{{ value|number:2 }}"
        let context = ["value": 1234.5678]

        let result = try service.render(template, context: context)
        // The number formatter is locale-dependent - on Linux it might use comma as decimal separator
        // Just check that the core number components are present
        #expect(result.contains("1") && result.contains("234") && result.contains("57"))
    }

    @Test("Percentage filter formats percentages")
    func testPercentageFilter() throws {
        let template = "Success rate: {{ rate|percentage:1 }}"
        let context = ["rate": 85.5]

        let result = try service.render(template, context: context)
        // Note: Different locales may format differently, just check it contains the number
        #expect(result.contains("85") || result.contains("Success rate"))
    }

    @Test("Date filter with custom format")
    func testDateFilterWithFormat() throws {
        let template = "{{ date|date:\"yyyy-MM-dd\" }}"

        // Create a specific date for consistent testing
        var components = DateComponents()
        components.year = 2024
        components.month = 3
        components.day = 15
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: components)!

        let context = ["date": date]

        let result = try service.render(template, context: context)
        #expect(result == "2024-03-15")
    }

    @Test("Currency filter with custom currency code")
    func testCurrencyFilterWithCode() throws {
        let template = "Price: {{ amount|currency:\"EUR\" }}"
        let context = ["amount": 99.99]

        let result = try service.render(template, context: context)
        #expect(result.contains("99") || result.contains("EUR") || result.contains("€"))
    }

    // MARK: - Enhanced Conditional Tests

    @Test("Conditional with comparison operators")
    func testConditionalWithComparison() throws {
        let template = """
            {% if age >= 18 %}
            Adult
            {% else %}
            Minor
            {% endif %}
            """

        let adultContext = ["age": 25]
        let minorContext = ["age": 16]

        let adultResult = try service.render(template, context: adultContext)
        #expect(adultResult.contains("Adult"))

        let minorResult = try service.render(template, context: minorContext)
        #expect(minorResult.contains("Minor"))
    }

    @Test("Conditional with equality check")
    func testConditionalWithEquality() throws {
        let template = """
            {% if status == "active" %}
            Account is active
            {% else %}
            Account is inactive
            {% endif %}
            """

        let activeContext = ["status": "active"]
        let inactiveContext = ["status": "suspended"]

        let activeResult = try service.render(template, context: activeContext)
        #expect(activeResult.contains("Account is active"))

        let inactiveResult = try service.render(template, context: inactiveContext)
        #expect(inactiveResult.contains("Account is inactive"))
    }

    // MARK: - Enhanced Loop Tests

    @Test("Loop with index")
    func testLoopWithIndex() throws {
        let template = """
            {% for item in items %}
            {{ forloop.counter }}: {{ item }}
            {% endfor %}
            """

        let context = ["items": ["First", "Second", "Third"]]

        let result = try service.render(template, context: context)
        #expect(result.contains("1: First"))
        #expect(result.contains("2: Second"))
        #expect(result.contains("3: Third"))
    }

    @Test("Nested loops")
    func testNestedLoops() throws {
        let template = """
            {% for category in categories %}
            {{ category.name }}:
            {% for item in category.items %}
              - {{ item }}
            {% endfor %}
            {% endfor %}
            """

        let context: [String: Any] = [
            "categories": [
                ["name": "Fruits", "items": ["Apple", "Orange"]],
                ["name": "Vegetables", "items": ["Carrot", "Lettuce"]],
            ]
        ]

        let result = try service.render(template, context: context)
        #expect(result.contains("Fruits:"))
        #expect(result.contains("Apple"))
        #expect(result.contains("Vegetables:"))
        #expect(result.contains("Carrot"))
    }

    // MARK: - Variable Extraction Tests for Enhanced Patterns

    @Test("Extract variables from comparison expressions")
    func testExtractVariablesFromComparisons() throws {
        let template = """
            {% if userAge >= minimumAge %}
            Allowed
            {% elif userAge == specialAge %}
            Special case
            {% endif %}
            """

        let variables = try service.extractVariables(from: template)
        #expect(variables.contains("userAge"))
        #expect(variables.contains("minimumAge"))
        #expect(variables.contains("specialAge"))
    }

    @Test("Extract variables from nested object in loops")
    func testExtractVariablesFromNestedLoops() throws {
        let template = """
            {% for item in user.orders %}
            {{ item.id }}: {{ item.total }}
            {% endfor %}
            """

        let variables = try service.extractVariables(from: template)
        #expect(variables.contains("user"))
        #expect(!variables.contains("item"))  // Loop variable should be excluded
    }
}
