import Foundation
import Testing

@testable import Brochure

@Suite("Template Selection Tests")
struct TemplateSelectionTests {

    @Test("Should list all available templates")
    func testListTemplates() throws {
        let command = try BootstrapCommand.parse(["test-project", "--list-templates"])

        let templateManager = TemplateManager()
        let templates = templateManager.availableTemplates()

        // Should have all expected templates
        #expect(templates.count == 5, "Should have 5 built-in templates")

        let templateIds = templates.map { $0.id }.sorted()
        let expectedIds = ["blog", "documentation", "ecommerce", "landing-page", "portfolio"]
        #expect(templateIds == expectedIds, "Should have all expected template IDs")

        // Each template should have required fields
        for template in templates {
            #expect(!template.id.isEmpty, "Template ID should not be empty")
            #expect(!template.name.isEmpty, "Template name should not be empty")
            #expect(!template.description.isEmpty, "Template description should not be empty")
            #expect(!template.features.isEmpty, "Template should have at least one feature")
        }
    }

    @Test("Should get template info for valid template")
    func testTemplateInfo() throws {
        let templateManager = TemplateManager()

        // Test landing-page template info
        let landingPageTemplate = templateManager.template(withId: "landing-page")
        #expect(landingPageTemplate != nil, "Landing page template should exist")
        #expect(landingPageTemplate?.name == "Landing Page")
        #expect(landingPageTemplate?.category == .landingPage)
        #expect(landingPageTemplate?.features.contains(.responsive) == true)
        #expect(landingPageTemplate?.features.contains(.seo) == true)

        // Test blog template info
        let blogTemplate = templateManager.template(withId: "blog")
        #expect(blogTemplate != nil, "Blog template should exist")
        #expect(blogTemplate?.name == "Blog")
        #expect(blogTemplate?.category == .blog)
        #expect(blogTemplate?.features.contains(.markdown) == true)
        #expect(blogTemplate?.features.contains(.rss) == true)
    }

    @Test("Should return nil for invalid template")
    func testInvalidTemplateInfo() throws {
        let templateManager = TemplateManager()

        let invalidTemplate = templateManager.template(withId: "non-existent")
        #expect(invalidTemplate == nil, "Should return nil for non-existent template")
    }

    @Test("Should validate template selection correctly")
    func testTemplateValidation() throws {
        // Valid template - should pass
        let validCommand = try BootstrapCommand.parse(["test-project", "--template", "landing-page"])
        #expect(throws: Never.self) {
            try validCommand.validateTemplateSelection()
        }

        // Invalid template - should fail with helpful error
        let invalidCommand = try BootstrapCommand.parse(["test-project", "--template", "invalid-template"])
        #expect(throws: BootstrapError.self) {
            try invalidCommand.validateTemplateSelection()
        }
    }

    @Test("Should get templates by category")
    func testTemplatesByCategory() throws {
        let templateManager = TemplateManager()

        let landingPageTemplates = templateManager.templates(for: .landingPage)
        #expect(landingPageTemplates.count == 1)
        #expect(landingPageTemplates.first?.id == "landing-page")

        let blogTemplates = templateManager.templates(for: .blog)
        #expect(blogTemplates.count == 1)
        #expect(blogTemplates.first?.id == "blog")

        let portfolioTemplates = templateManager.templates(for: .portfolio)
        #expect(portfolioTemplates.count == 1)
        #expect(portfolioTemplates.first?.id == "portfolio")
    }

    @Test("Should format template information correctly")
    func testTemplateInfoFormatting() throws {
        let templateManager = TemplateManager()
        let template = templateManager.template(withId: "landing-page")!

        let formattedInfo = formatTemplateInfo(template)

        #expect(formattedInfo.contains("Landing Page"))
        #expect(formattedInfo.contains("landing-page"))
        #expect(formattedInfo.contains("Modern landing page"))
        #expect(formattedInfo.contains("Features:"))
        #expect(formattedInfo.contains("Responsive"))
        #expect(formattedInfo.contains("SEO"))
    }

    @Test("Should handle template selection in interactive mode")
    func testInteractiveTemplateSelection() throws {
        // This would test interactive selection, but requires user input simulation
        // For now, we'll test the template validation logic

        let templateManager = TemplateManager()
        let availableTemplates = templateManager.availableTemplates()

        // All template IDs should be valid
        for template in availableTemplates {
            #expect(throws: Never.self) {
                let foundTemplate = templateManager.template(withId: template.id)
                #expect(foundTemplate != nil)
            }
        }
    }

    @Test("Should display template features correctly")
    func testTemplateFeatureDisplay() throws {
        let templateManager = TemplateManager()

        let blogTemplate = templateManager.template(withId: "blog")!
        let featureDescriptions = formatTemplateFeatures(blogTemplate.features)

        #expect(featureDescriptions.contains("Markdown"))
        #expect(featureDescriptions.contains("RSS"))
        #expect(featureDescriptions.contains("Search"))

        let ecommerceTemplate = templateManager.template(withId: "ecommerce")!
        let ecommerceFeatures = formatTemplateFeatures(ecommerceTemplate.features)

        #expect(ecommerceFeatures.contains("Responsive"))
        #expect(ecommerceFeatures.contains("Gallery"))
    }
}

// Helper functions for testing
private func formatTemplateInfo(_ template: Template) -> String {
    var info = """
        \(template.name) (\(template.id))
        \(template.description)

        Category: \(template.category.displayName)

        """

    if !template.features.isEmpty {
        info += "Features: \(formatTemplateFeatures(template.features))\n"
    }

    info += "\nRequired Context: \(template.requiredContext.map { $0.displayName }.joined(separator: ", "))"

    if !template.optionalContext.isEmpty {
        info += "\nOptional Context: \(template.optionalContext.map { $0.displayName }.joined(separator: ", "))"
    }

    return info
}

private func formatTemplateFeatures(_ features: Set<TemplateFeature>) -> String {
    let featureNames = features.map { feature in
        switch feature {
        case .responsive: return "Responsive Design"
        case .seo: return "SEO Optimized"
        case .analytics: return "Analytics Ready"
        case .markdown: return "Markdown Support"
        case .rss: return "RSS Feed"
        case .search: return "Search"
        case .categories: return "Categories"
        case .gallery: return "Image Gallery"
        case .contactForm: return "Contact Form"
        case .resume: return "Resume/CV"
        case .darkMode: return "Dark Mode"
        case .multilingual: return "Multi-language"
        case .comments: return "Comments"
        case .newsletter: return "Newsletter"
        case .socialSharing: return "Social Sharing"
        }
    }.sorted()

    return featureNames.joined(separator: ", ")
}

// Extension to support testing
extension BootstrapCommand {
    func validateTemplateSelection() throws {
        let templateManager = TemplateManager()
        guard templateManager.template(withId: template) != nil else {
            let availableTemplates = templateManager.availableTemplates()
                .map { $0.id }
                .sorted()
                .joined(separator: ", ")
            throw BootstrapError.templateNotFound(
                template,
                available: availableTemplates
            )
        }
    }
}
