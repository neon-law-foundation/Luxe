import Foundation
import Testing

@testable import Brochure

@Suite("Bootstrap Command Tests")
struct BootstrapCommandTests {
    private let testDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("BrochureBootstrapTests")
        .appendingPathComponent(UUID().uuidString)

    init() throws {
        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    @Test("Should create landing page project with basic structure")
    func testBasicLandingPageGeneration() async throws {
        let projectName = "TestLandingPage"
        let projectPath = testDirectory.appendingPathComponent(projectName)

        defer {
            try? FileManager.default.removeItem(at: projectPath)
        }

        let templateManager = TemplateManager()
        let generator = ProjectGenerator()

        guard let template = templateManager.template(withId: "landing-page") else {
            throw BootstrapTestError.templateNotFound
        }

        var context = TemplateContext()
        context[.projectName] = projectName
        context[.description] = "Test landing page project"
        context[.author] = "Test Author"

        try await generator.generate(
            template: template,
            at: projectPath,
            with: context
        )

        // Verify directory structure was created
        #expect(FileManager.default.fileExists(atPath: projectPath.path))
        #expect(FileManager.default.fileExists(atPath: projectPath.appendingPathComponent("src").path))
        #expect(FileManager.default.fileExists(atPath: projectPath.appendingPathComponent("src/styles").path))
        #expect(FileManager.default.fileExists(atPath: projectPath.appendingPathComponent("src/scripts").path))
        #expect(FileManager.default.fileExists(atPath: projectPath.appendingPathComponent("src/assets").path))

        // Verify key files were created
        #expect(FileManager.default.fileExists(atPath: projectPath.appendingPathComponent("src/index.html").path))
        #expect(FileManager.default.fileExists(atPath: projectPath.appendingPathComponent("src/styles/main.css").path))
        #expect(FileManager.default.fileExists(atPath: projectPath.appendingPathComponent("src/scripts/main.js").path))
        #expect(FileManager.default.fileExists(atPath: projectPath.appendingPathComponent("README.md").path))
        #expect(FileManager.default.fileExists(atPath: projectPath.appendingPathComponent(".gitignore").path))

        // Verify content was processed
        let indexContent = try String(contentsOf: projectPath.appendingPathComponent("src/index.html"), encoding: .utf8)
        #expect(indexContent.contains(projectName))
        #expect(indexContent.contains("Test landing page project"))
        #expect(indexContent.contains("Test Author"))

        let readmeContent = try String(contentsOf: projectPath.appendingPathComponent("README.md"), encoding: .utf8)
        #expect(readmeContent.contains(projectName))
        #expect(readmeContent.contains("Test landing page project"))
    }

    @Test("Should create blog project with posts directory")
    func testBlogProjectGeneration() async throws {
        let projectName = "TestBlog"
        let projectPath = testDirectory.appendingPathComponent(projectName)

        let templateManager = TemplateManager()
        let generator = ProjectGenerator()

        guard let template = templateManager.template(withId: "blog") else {
            throw BootstrapTestError.templateNotFound
        }

        var context = TemplateContext()
        context[.projectName] = projectName
        context[.blogTitle] = "My Test Blog"
        context[.author] = "Blog Author"
        context[.blogDescription] = "A test blog created with Brochure CLI"

        try await generator.generate(
            template: template,
            at: projectPath,
            with: context
        )

        // Verify blog-specific structure
        #expect(FileManager.default.fileExists(atPath: projectPath.appendingPathComponent("src/posts").path))
        #expect(FileManager.default.fileExists(atPath: projectPath.appendingPathComponent("src/templates").path))
        #expect(FileManager.default.fileExists(atPath: projectPath.appendingPathComponent("src/posts/welcome.md").path))
        #expect(
            FileManager.default.fileExists(atPath: projectPath.appendingPathComponent("src/templates/post.html").path)
        )

        // Verify blog-specific content
        let indexContent = try String(contentsOf: projectPath.appendingPathComponent("src/index.html"), encoding: .utf8)
        #expect(indexContent.contains("My Test Blog"))
        #expect(indexContent.contains("A test blog created with Brochure CLI"))

        let welcomePost = try String(
            contentsOf: projectPath.appendingPathComponent("src/posts/welcome.md"),
            encoding: .utf8
        )
        #expect(welcomePost.contains("Welcome to Your Blog"))
        #expect(welcomePost.contains(projectName))
    }

    @Test("Should create portfolio project with projects directory")
    func testPortfolioProjectGeneration() async throws {
        let projectName = "TestPortfolio"
        let projectPath = testDirectory.appendingPathComponent(projectName)

        let templateManager = TemplateManager()
        let generator = ProjectGenerator()

        guard let template = templateManager.template(withId: "portfolio") else {
            throw BootstrapTestError.templateNotFound
        }

        var context = TemplateContext()
        context[.projectName] = projectName
        context[.portfolioOwner] = "Portfolio Owner"
        context[.author] = "Portfolio Author"
        context[.email] = "portfolio@example.com"

        try await generator.generate(
            template: template,
            at: projectPath,
            with: context
        )

        // Verify portfolio-specific structure
        #expect(FileManager.default.fileExists(atPath: projectPath.appendingPathComponent("src/projects").path))
        #expect(FileManager.default.fileExists(atPath: projectPath.appendingPathComponent("src/pages").path))
        #expect(FileManager.default.fileExists(atPath: projectPath.appendingPathComponent("src/assets/documents").path))
        #expect(
            FileManager.default.fileExists(atPath: projectPath.appendingPathComponent("src/pages/contact.html").path)
        )

        // Verify portfolio-specific content
        let contactContent = try String(
            contentsOf: projectPath.appendingPathComponent("src/pages/contact.html"),
            encoding: .utf8
        )
        #expect(contactContent.contains("Portfolio Author"))
        #expect(contactContent.contains("portfolio@example.com"))
    }

    @Test("Should handle template rendering with conditionals")
    func testTemplateConditionalRendering() async throws {
        let renderer = TemplateRenderer()

        var context = TemplateContext()
        context[.analytics] = true
        context[.analyticsId] = "GA-12345"
        context[.projectName] = "Test Project"

        let template = """
            <title>{{projectName}}</title>
            {{#if analytics}}
            <script src="https://www.googletagmanager.com/gtag/js?id={{analyticsId}}"></script>
            {{/if}}
            {{#unless analytics}}
            <meta name="no-analytics" content="true">
            {{/unless}}
            """

        let result = try renderer.render(template, context: context)

        #expect(result.contains("<title>Test Project</title>"))
        #expect(result.contains("https://www.googletagmanager.com/gtag/js?id=GA-12345"))
        #expect(!result.contains("no-analytics"))
    }

    @Test("Should handle template rendering with defaults")
    func testTemplateDefaultValues() async throws {
        let renderer = TemplateRenderer()

        var context = TemplateContext()
        context[.projectName] = "Test Project"
        // Don't set blogTitle to test default

        let template = """
            <h1>{{blogTitle|default:projectName}}</h1>
            <p>{{description|default:No description provided}}</p>
            """

        let result = try renderer.render(template, context: context)

        #expect(result.contains("<h1>Test Project</h1>"))
        #expect(result.contains("<p>No description provided</p>"))
    }

    @Test("Should validate required template context")
    func testTemplateContextValidation() async throws {
        let templateManager = TemplateManager()
        let generator = ProjectGenerator()

        guard let template = templateManager.template(withId: "landing-page") else {
            throw BootstrapTestError.templateNotFound
        }

        let projectPath = testDirectory.appendingPathComponent("InvalidProject")

        // Missing required context
        var incompleteContext = TemplateContext()
        // Only set projectName, missing description and author
        incompleteContext[.projectName] = "Test"

        await #expect(throws: TemplateError.self) {
            try await generator.generate(
                template: template,
                at: projectPath,
                with: incompleteContext
            )
        }
    }

    @Test("Should list all available templates")
    func testTemplateManagerListsAllTemplates() throws {
        let templateManager = TemplateManager()
        let templates = templateManager.availableTemplates()

        #expect(templates.count >= 5)  // Should have at least 5 built-in templates

        let templateIds = templates.map(\.id)
        #expect(templateIds.contains("landing-page"))
        #expect(templateIds.contains("blog"))
        #expect(templateIds.contains("portfolio"))
        #expect(templateIds.contains("documentation"))
        #expect(templateIds.contains("ecommerce"))
    }

    @Test("Should filter templates by category")
    func testTemplateManagerFiltersByCategory() throws {
        let templateManager = TemplateManager()

        let landingPageTemplates = templateManager.templates(for: .landingPage)
        #expect(landingPageTemplates.count >= 1)
        #expect(landingPageTemplates.allSatisfy { $0.category == .landingPage })

        let blogTemplates = templateManager.templates(for: .blog)
        #expect(blogTemplates.count >= 1)
        #expect(blogTemplates.allSatisfy { $0.category == .blog })
    }

    @Test("Should handle system context values")
    func testSystemContextValues() throws {
        let context = TemplateContext()

        // System values should be automatically set
        #expect(context[.currentYear] != nil)
        #expect(context[.generatedDate] != nil)
        #expect(context[.generatorVersion] != nil)
        #expect(context[.generatorName] != nil)

        let currentYear = Calendar.current.component(.year, from: Date())
        #expect(context[.currentYear] as? Int == currentYear)
        #expect(context[.generatorName] as? String == "Brochure CLI")
    }

    @Test("Should create proper file permissions")
    func testFilePermissions() async throws {
        let projectName = "PermissionTest"
        let projectPath = testDirectory.appendingPathComponent(projectName)

        let templateManager = TemplateManager()
        let generator = ProjectGenerator()

        guard let template = templateManager.template(withId: "landing-page") else {
            throw BootstrapTestError.templateNotFound
        }

        var context = TemplateContext()
        context[.projectName] = projectName
        context[.description] = "Test project"
        context[.author] = "Test Author"

        try await generator.generate(
            template: template,
            at: projectPath,
            with: context
        )

        // Verify files are readable
        let indexPath = projectPath.appendingPathComponent("src/index.html")
        #expect(FileManager.default.isReadableFile(atPath: indexPath.path))

        let cssPath = projectPath.appendingPathComponent("src/styles/main.css")
        #expect(FileManager.default.isReadableFile(atPath: cssPath.path))
    }
}

private enum BootstrapTestError: Error {
    case templateNotFound
}
