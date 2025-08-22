import Foundation
import Logging

/// Manages available templates and provides access to them.
public struct TemplateManager {
    private let logger: Logger
    private let templates: [Template]

    public init(logger: Logger? = nil) {
        self.logger = logger ?? Logger(label: "TemplateManager")
        self.templates = Self.loadBuiltInTemplates()
    }

    /// Get a template by its ID.
    public func template(withId id: String) -> Template? {
        templates.first { $0.id == id }
    }

    /// Get all available templates.
    public func availableTemplates() -> [Template] {
        templates
    }

    /// Get templates for a specific category.
    public func templates(for category: TemplateCategory) -> [Template] {
        templates.filter { $0.category == category }
    }

    /// Load all built-in templates.
    private static func loadBuiltInTemplates() -> [Template] {
        [
            landingPageTemplate(),
            blogTemplate(),
            portfolioTemplate(),
            documentationTemplate(),
            ecommerceTemplate(),
        ]
    }

    // MARK: - Built-in Templates

    /// Landing page template with hero section, features, and CTA.
    private static func landingPageTemplate() -> Template {
        Template(
            id: "landing-page",
            name: "Landing Page",
            description: "Modern landing page with hero section, features, and CTA",
            category: .landingPage,
            structure: TemplateStructure(
                directories: [
                    DirectoryTemplate(path: "src"),
                    DirectoryTemplate(path: "src/styles"),
                    DirectoryTemplate(path: "src/scripts"),
                    DirectoryTemplate(path: "src/assets"),
                    DirectoryTemplate(path: "src/assets/images"),
                    DirectoryTemplate(path: "dist"),
                ],
                files: [
                    FileTemplate(
                        path: "src/index.html",
                        content: .template(TemplateContent.landingPageHTML)
                    ),
                    FileTemplate(
                        path: "src/styles/main.css",
                        content: .template(TemplateContent.landingPageCSS)
                    ),
                    FileTemplate(
                        path: "src/scripts/main.js",
                        content: .template(TemplateContent.landingPageJS)
                    ),
                    FileTemplate(
                        path: "README.md",
                        content: .template(TemplateContent.readmeMD)
                    ),
                    FileTemplate(
                        path: ".gitignore",
                        content: .static(TemplateContent.gitignore)
                    ),
                    FileTemplate(
                        path: "robots.txt",
                        content: .static(TemplateContent.robotsTxt)
                    ),
                ]
            ),
            features: [.responsive, .seo, .analytics],
            requiredContext: [.projectName, .description, .author],
            optionalContext: [.tagline, .email, .analytics, .analyticsId],
            version: TemplateVersion(major: 1, minor: 0, patch: 0)
        )
    }

    /// Blog template with posts, categories, and RSS feed.
    private static func blogTemplate() -> Template {
        Template(
            id: "blog",
            name: "Blog",
            description: "Static blog with posts, categories, and RSS feed support",
            category: .blog,
            structure: TemplateStructure(
                directories: [
                    DirectoryTemplate(path: "src"),
                    DirectoryTemplate(path: "src/posts"),
                    DirectoryTemplate(path: "src/pages"),
                    DirectoryTemplate(path: "src/templates"),
                    DirectoryTemplate(path: "src/styles"),
                    DirectoryTemplate(path: "src/scripts"),
                    DirectoryTemplate(path: "src/assets"),
                    DirectoryTemplate(path: "dist"),
                ],
                files: [
                    FileTemplate(
                        path: "src/index.html",
                        content: .template(TemplateContent.blogIndexHTML)
                    ),
                    FileTemplate(
                        path: "src/templates/post.html",
                        content: .template(TemplateContent.blogPostTemplate)
                    ),
                    FileTemplate(
                        path: "src/posts/welcome.md",
                        content: .template(TemplateContent.welcomePostMD)
                    ),
                    FileTemplate(
                        path: "src/styles/blog.css",
                        content: .template(TemplateContent.blogCSS)
                    ),
                    FileTemplate(
                        path: "src/scripts/blog.js",
                        content: .template(TemplateContent.blogJS)
                    ),
                    FileTemplate(
                        path: "src/pages/about.html",
                        content: .template(TemplateContent.aboutPageHTML)
                    ),
                    FileTemplate(
                        path: "README.md",
                        content: .template(TemplateContent.blogReadmeMD)
                    ),
                    FileTemplate(
                        path: ".gitignore",
                        content: .static(TemplateContent.gitignore)
                    ),
                ]
            ),
            features: [.markdown, .rss, .search, .categories, .responsive],
            requiredContext: [.projectName, .blogTitle, .author],
            optionalContext: [.blogDescription, .rssEnabled, .email],
            version: TemplateVersion(major: 1, minor: 1, patch: 0)
        )
    }

    /// Portfolio template with projects showcase.
    private static func portfolioTemplate() -> Template {
        Template(
            id: "portfolio",
            name: "Portfolio",
            description: "Professional portfolio with projects showcase",
            category: .portfolio,
            structure: TemplateStructure(
                directories: [
                    DirectoryTemplate(path: "src"),
                    DirectoryTemplate(path: "src/projects"),
                    DirectoryTemplate(path: "src/pages"),
                    DirectoryTemplate(path: "src/styles"),
                    DirectoryTemplate(path: "src/scripts"),
                    DirectoryTemplate(path: "src/assets"),
                    DirectoryTemplate(path: "src/assets/images"),
                    DirectoryTemplate(path: "src/assets/documents"),
                    DirectoryTemplate(path: "dist"),
                ],
                files: [
                    FileTemplate(
                        path: "src/index.html",
                        content: .template(TemplateContent.portfolioIndexHTML)
                    ),
                    FileTemplate(
                        path: "src/pages/about.html",
                        content: .template(TemplateContent.portfolioAboutHTML)
                    ),
                    FileTemplate(
                        path: "src/pages/contact.html",
                        content: .template(TemplateContent.contactPageHTML)
                    ),
                    FileTemplate(
                        path: "src/projects/project-template.html",
                        content: .template(TemplateContent.projectTemplateHTML)
                    ),
                    FileTemplate(
                        path: "src/styles/portfolio.css",
                        content: .template(TemplateContent.portfolioCSS)
                    ),
                    FileTemplate(
                        path: "src/scripts/portfolio.js",
                        content: .template(TemplateContent.portfolioJS)
                    ),
                    FileTemplate(
                        path: "README.md",
                        content: .template(TemplateContent.portfolioReadmeMD)
                    ),
                    FileTemplate(
                        path: ".gitignore",
                        content: .static(TemplateContent.gitignore)
                    ),
                ]
            ),
            features: [.gallery, .contactForm, .resume, .responsive],
            requiredContext: [.projectName, .portfolioOwner, .author],
            optionalContext: [.email, .resumeUrl, .githubUrl, .linkedinUrl],
            version: TemplateVersion(major: 1, minor: 0, patch: 1)
        )
    }

    /// Documentation template with navigation and search.
    private static func documentationTemplate() -> Template {
        Template(
            id: "documentation",
            name: "Documentation",
            description: "Technical documentation site with navigation and search",
            category: .documentation,
            structure: TemplateStructure(
                directories: [
                    DirectoryTemplate(path: "src"),
                    DirectoryTemplate(path: "src/docs"),
                    DirectoryTemplate(path: "src/api"),
                    DirectoryTemplate(path: "src/tutorials"),
                    DirectoryTemplate(path: "src/styles"),
                    DirectoryTemplate(path: "src/scripts"),
                    DirectoryTemplate(path: "src/assets"),
                    DirectoryTemplate(path: "dist"),
                ],
                files: [
                    FileTemplate(
                        path: "src/index.html",
                        content: .template(TemplateContent.docsIndexHTML)
                    ),
                    FileTemplate(
                        path: "src/docs/getting-started.md",
                        content: .template(TemplateContent.gettingStartedMD)
                    ),
                    FileTemplate(
                        path: "src/styles/docs.css",
                        content: .template(TemplateContent.docsCSS)
                    ),
                    FileTemplate(
                        path: "src/scripts/docs.js",
                        content: .template(TemplateContent.docsJS)
                    ),
                    FileTemplate(
                        path: "README.md",
                        content: .template(TemplateContent.docsReadmeMD)
                    ),
                    FileTemplate(
                        path: ".gitignore",
                        content: .static(TemplateContent.gitignore)
                    ),
                ]
            ),
            features: [.search, .markdown, .responsive, .darkMode],
            requiredContext: [.projectName, .docsTitle, .author],
            optionalContext: [.description, .searchEnabled, .githubUrl],
            version: TemplateVersion(major: 1, minor: 2, patch: 0)
        )
    }

    /// E-commerce template with product pages.
    private static func ecommerceTemplate() -> Template {
        Template(
            id: "ecommerce",
            name: "E-commerce",
            description: "Basic e-commerce template with product pages",
            category: .ecommerce,
            structure: TemplateStructure(
                directories: [
                    DirectoryTemplate(path: "src"),
                    DirectoryTemplate(path: "src/products"),
                    DirectoryTemplate(path: "src/pages"),
                    DirectoryTemplate(path: "src/styles"),
                    DirectoryTemplate(path: "src/scripts"),
                    DirectoryTemplate(path: "src/assets"),
                    DirectoryTemplate(path: "src/assets/images"),
                    DirectoryTemplate(path: "dist"),
                ],
                files: [
                    FileTemplate(
                        path: "src/index.html",
                        content: .template(TemplateContent.ecommerceIndexHTML)
                    ),
                    FileTemplate(
                        path: "src/products/product-template.html",
                        content: .template(TemplateContent.productTemplateHTML)
                    ),
                    FileTemplate(
                        path: "src/pages/cart.html",
                        content: .template(TemplateContent.cartPageHTML)
                    ),
                    FileTemplate(
                        path: "src/pages/checkout.html",
                        content: .template(TemplateContent.checkoutPageHTML)
                    ),
                    FileTemplate(
                        path: "src/styles/store.css",
                        content: .template(TemplateContent.storeCSS)
                    ),
                    FileTemplate(
                        path: "src/scripts/store.js",
                        content: .template(TemplateContent.storeJS)
                    ),
                    FileTemplate(
                        path: "README.md",
                        content: .template(TemplateContent.ecommerceReadmeMD)
                    ),
                    FileTemplate(
                        path: ".gitignore",
                        content: .static(TemplateContent.gitignore)
                    ),
                ]
            ),
            features: [.responsive, .search, .gallery],
            requiredContext: [.projectName, .storeName, .author],
            optionalContext: [.currency, .stripePublicKey, .shippingEnabled],
            version: TemplateVersion(major: 1, minor: 0, patch: 2)
        )
    }
}
