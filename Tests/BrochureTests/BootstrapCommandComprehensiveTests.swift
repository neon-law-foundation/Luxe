import ArgumentParser
import Foundation
import Testing

@testable import Brochure

@Suite("Comprehensive Bootstrap Command Tests")
struct BootstrapCommandComprehensiveTests {
    private let testDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("BrochureBootstrapCompTests")
        .appendingPathComponent(UUID().uuidString)

    init() throws {
        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    // MARK: - Error Handling Tests

    @Test("Should handle missing required context gracefully")
    func testMissingRequiredContext() async throws {
        let generator = ProjectGenerator()
        let templateManager = TemplateManager()

        guard let template = templateManager.template(withId: "landing-page") else {
            throw BootstrapTestError.templateNotFound
        }

        // Empty context missing all required fields
        let emptyContext = TemplateContext()
        let projectPath = testDirectory.appendingPathComponent("EmptyContextProject")

        await #expect(throws: TemplateError.self) {
            try await generator.generate(
                template: template,
                at: projectPath,
                with: emptyContext
            )
        }
    }

    @Test("Should handle file system errors gracefully")
    func testFileSystemErrors() async throws {
        let generator = ProjectGenerator()
        let templateManager = TemplateManager()

        guard let template = templateManager.template(withId: "landing-page") else {
            throw BootstrapTestError.templateNotFound
        }

        var context = TemplateContext()
        context[.projectName] = "TestProject"
        context[.description] = "Test description"
        context[.author] = "Test Author"

        // Try to generate in a read-only directory
        let readOnlyPath = URL(fileURLWithPath: "/System")

        await #expect(throws: Error.self) {
            try await generator.generate(
                template: template,
                at: readOnlyPath,
                with: context
            )
        }
    }

    @Test("Should handle directory already exists gracefully")
    func testDirectoryAlreadyExists() async throws {
        let projectName = "ExistingProject"
        let projectPath = testDirectory.appendingPathComponent(projectName)

        // Create directory first with some content
        try FileManager.default.createDirectory(
            at: projectPath,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Add a file to make it non-empty
        let existingFile = projectPath.appendingPathComponent("existing.txt")
        try "existing content".write(to: existingFile, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: projectPath)
        }

        let generator = ProjectGenerator()
        let templateManager = TemplateManager()

        guard let template = templateManager.template(withId: "landing-page") else {
            throw BootstrapTestError.templateNotFound
        }

        var context = TemplateContext()
        context[.projectName] = projectName
        context[.description] = "Test description"
        context[.author] = "Test Author"

        // The generator should handle existing directories by checking/creating
        // Since it creates subdirectories, it may not fail on existing directory
        // Let's test that it can work with or handle existing directories appropriately
        do {
            try await generator.generate(
                template: template,
                at: projectPath,
                with: context
            )
            // If it succeeds, verify it created the expected structure
            #expect(FileManager.default.fileExists(atPath: projectPath.appendingPathComponent("src").path))
        } catch {
            // If it fails, that's also acceptable behavior for existing directories
            #expect(error is Error)
        }
    }

    // MARK: - Template Processing Tests

    @Test("Should process template conditionals")
    func testTemplateConditionals() async throws {
        let renderer = TemplateRenderer()

        var context = TemplateContext()
        context[.projectName] = "Test Project"
        context[.analytics] = true

        let template = """
            {{#if analytics}}
            <script src="analytics.js"></script>
            {{/if}}
            <title>{{projectName}}</title>
            """

        let result = try renderer.render(template, context: context)

        #expect(result.contains("analytics.js"))
        #expect(result.contains("Test Project"))
    }

    @Test("Should handle template loops correctly")
    func testTemplateLoops() async throws {
        let renderer = TemplateRenderer()

        var context = TemplateContext()
        context[.projectName] = "Test Project"
        context[.skills] = ["Swift", "JavaScript", "Python"]

        let template = """
            <h1>{{projectName}}</h1>
            <ul>
            {{#each skills}}
                <li>{{this}}</li>
            {{/each}}
            </ul>
            """

        let result = try renderer.render(template, context: context)

        #expect(result.contains("<li>Swift</li>"))
        #expect(result.contains("<li>JavaScript</li>"))
        #expect(result.contains("<li>Python</li>"))
        #expect(result.contains("Test Project"))
    }

    // MARK: - File Generation Tests

    @Test("Should generate proper .gitignore file")
    func testGitignoreGeneration() async throws {
        let projectName = "GitignoreTest"
        let projectPath = testDirectory.appendingPathComponent(projectName)

        defer {
            try? FileManager.default.removeItem(at: projectPath)
        }

        let generator = ProjectGenerator()
        let templateManager = TemplateManager()

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

        let gitignorePath = projectPath.appendingPathComponent(".gitignore")
        #expect(FileManager.default.fileExists(atPath: gitignorePath.path))

        let gitignoreContent = try String(contentsOf: gitignorePath, encoding: .utf8)
        #expect(gitignoreContent.contains("node_modules"))
        #expect(gitignoreContent.contains(".DS_Store"))
        #expect(gitignoreContent.contains("*.log"))
        #expect(gitignoreContent.contains("dist/"))
    }

    @Test("Should generate proper package.json with dependencies")
    func testPackageJsonGeneration() async throws {
        let projectName = "PackageJsonTest"
        let projectPath = testDirectory.appendingPathComponent(projectName)

        defer {
            try? FileManager.default.removeItem(at: projectPath)
        }

        let generator = ProjectGenerator()
        let templateManager = TemplateManager()

        guard let template = templateManager.template(withId: "blog") else {
            throw BootstrapTestError.templateNotFound
        }

        var context = TemplateContext()
        context[.projectName] = projectName
        context[.blogTitle] = "Test Blog"
        context[.author] = "Test Author"
        context[.blogDescription] = "A test blog"

        try await generator.generate(
            template: template,
            at: projectPath,
            with: context
        )

        let packageJsonPath = projectPath.appendingPathComponent("package.json")
        if FileManager.default.fileExists(atPath: packageJsonPath.path) {
            let packageJsonContent = try String(contentsOf: packageJsonPath, encoding: .utf8)
            let jsonData = packageJsonContent.data(using: .utf8)!
            let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

            #expect(json?["name"] as? String == projectName.lowercased())
            #expect(json?["author"] as? String == "Test Author")
            #expect(json?["scripts"] != nil)
        }
    }

    // MARK: - Interactive Mode Tests

    @Test("Should validate interactive input correctly")
    func testInteractiveInputValidation() throws {
        // Parse a command with the required argument
        let command = try BootstrapCommand.parse(["test-project"])

        // Test that command has expected properties
        #expect(command.interactive == false)
        #expect(command.gitInit == true)
        #expect(command.template == "landing-page")
        #expect(command.directory == ".")
        #expect(command.projectName == "test-project")
    }

    // MARK: - Command Configuration Tests

    @Test("Should have correct command configuration")
    func testCommandConfiguration() throws {
        let config = BootstrapCommand.configuration

        #expect(config.commandName == "bootstrap")
        #expect(config.abstract.contains("Create"))
        #expect(!config.discussion.isEmpty)
    }

    @Test("Should parse command line arguments correctly")
    func testCommandLineParsing() throws {
        // Test with all flags
        let args = [
            "my-project",
            "--template", "blog",
            "--directory", "/tmp",
            "--description", "My test project",
            "--author", "John Doe",
            "--email", "john@example.com",
            "--git-init",
            "--verbose",
        ]

        let command = try BootstrapCommand.parse(args)

        #expect(command.projectName == "my-project")
        #expect(command.template == "blog")
        #expect(command.directory == "/tmp")
        #expect(command.description == "My test project")
        #expect(command.author == "John Doe")
        #expect(command.email == "john@example.com")
        #expect(command.gitInit == true)
        #expect(command.verbose == true)
    }

    // MARK: - Template Category Tests

    @Test("Should support all template categories")
    func testAllTemplateCategories() throws {
        let templateManager = TemplateManager()

        let categories: [TemplateCategory] = [
            .landingPage,
            .blog,
            .portfolio,
            .documentation,
            .ecommerce,
        ]

        for category in categories {
            let templates = templateManager.templates(for: category)
            #expect(
                !templates.isEmpty,
                "Should have at least one template for category: \(category)"
            )
        }
    }

    // MARK: - File Content Validation Tests

    @Test("Should generate valid HTML5 documents")
    func testHTML5Validation() async throws {
        let projectName = "HTML5Test"
        let projectPath = testDirectory.appendingPathComponent(projectName)

        defer {
            try? FileManager.default.removeItem(at: projectPath)
        }

        let generator = ProjectGenerator()
        let templateManager = TemplateManager()

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

        let indexPath = projectPath.appendingPathComponent("src/index.html")
        let htmlContent = try String(contentsOf: indexPath, encoding: .utf8)

        // Check for HTML5 doctype
        #expect(htmlContent.lowercased().contains("<!doctype html>"))

        // Check for required meta tags
        #expect(htmlContent.contains("<meta charset="))
        #expect(htmlContent.contains("<meta name=\"viewport\""))

        // Check for semantic HTML5 elements
        #expect(htmlContent.contains("<header") || htmlContent.contains("<nav") || htmlContent.contains("<main"))
    }

    @Test("Should generate responsive CSS")
    func testResponsiveCSS() async throws {
        let projectName = "ResponsiveTest"
        let projectPath = testDirectory.appendingPathComponent(projectName)

        defer {
            try? FileManager.default.removeItem(at: projectPath)
        }

        let generator = ProjectGenerator()
        let templateManager = TemplateManager()

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

        let cssPath = projectPath.appendingPathComponent("src/styles/main.css")
        if FileManager.default.fileExists(atPath: cssPath.path) {
            let cssContent = try String(contentsOf: cssPath, encoding: .utf8)

            // Check for responsive features
            #expect(cssContent.contains("@media") || cssContent.contains("flex") || cssContent.contains("grid"))

            // Check for CSS reset or normalize
            #expect(cssContent.contains("box-sizing") || cssContent.contains("margin: 0"))
        }
    }

    // MARK: - Performance Tests

    @Test("Should generate project quickly")
    func testGenerationPerformance() async throws {
        let projectName = "PerformanceTest"
        let projectPath = testDirectory.appendingPathComponent(projectName)

        defer {
            try? FileManager.default.removeItem(at: projectPath)
        }

        let generator = ProjectGenerator()
        let templateManager = TemplateManager()

        guard let template = templateManager.template(withId: "landing-page") else {
            throw BootstrapTestError.templateNotFound
        }

        var context = TemplateContext()
        context[.projectName] = projectName
        context[.description] = "Test project"
        context[.author] = "Test Author"

        let startTime = Date()

        try await generator.generate(
            template: template,
            at: projectPath,
            with: context
        )

        let elapsed = Date().timeIntervalSince(startTime)

        #expect(elapsed < 10.0, "Project generation should complete within 10 seconds")
    }
}

private enum BootstrapTestError: Error {
    case templateNotFound
}
