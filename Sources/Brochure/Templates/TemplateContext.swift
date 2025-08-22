import Foundation

/// Context for template variable substitution and rendering.
public struct TemplateContext: Sendable {
    private var values: [ContextKey: any Sendable]

    public init(values: [ContextKey: any Sendable] = [:]) {
        self.values = values

        // Add system default values
        self.values[.currentYear] = Calendar.current.component(.year, from: Date())
        self.values[.generatedDate] = ISO8601DateFormatter().string(from: Date())
        self.values[.generatorVersion] = "1.0.0"  // TODO: Use actual version
        self.values[.generatorName] = "Brochure CLI"
    }

    public subscript(key: ContextKey) -> (any Sendable)? {
        get { values[key] }
        set { values[key] = newValue }
    }

    /// Validate that all required keys are present.
    public func validate(requiredKeys: [ContextKey]) throws {
        for key in requiredKeys {
            guard values[key] != nil else {
                throw TemplateError.missingContextValue(key)
            }
        }
    }

    /// Get a string value for a key, with optional default.
    public func string(for key: ContextKey, default defaultValue: String? = nil) -> String? {
        if let value = values[key] as? String {
            return value
        }
        if let value = values[key] {
            return String(describing: value)
        }
        return defaultValue
    }

    /// Get a boolean value for a key, with optional default.
    public func bool(for key: ContextKey, default defaultValue: Bool = false) -> Bool {
        values[key] as? Bool ?? defaultValue
    }

    /// Merge another context into this one.
    public mutating func merge(_ other: TemplateContext) {
        for (key, value) in other.values {
            values[key] = value
        }
    }

    /// Create a copy with additional values.
    public func with(_ additionalValues: [ContextKey: any Sendable]) -> TemplateContext {
        var newContext = self
        for (key, value) in additionalValues {
            newContext.values[key] = value
        }
        return newContext
    }
}

/// Keys for template context values.
public enum ContextKey: String, CaseIterable, Sendable {
    // MARK: - Required Common
    case projectName
    case description
    case author

    // MARK: - Optional Common
    case tagline
    case email
    case githubUrl
    case twitterHandle
    case linkedinUrl
    case website

    // MARK: - Blog Specific
    case blogTitle
    case blogDescription
    case rssEnabled
    case commentsEnabled
    case disqusShortname
    case postsPerPage

    // MARK: - Portfolio Specific
    case portfolioOwner
    case resumeUrl
    case skills
    case experience
    case education

    // MARK: - Documentation Specific
    case docsTitle
    case searchEnabled
    case apiReference
    case tutorialsEnabled

    // MARK: - E-commerce Specific
    case storeName
    case currency
    case stripePublicKey
    case shippingEnabled
    case taxRate

    // MARK: - Features
    case analytics
    case analyticsId
    case seoEnabled
    case darkModeEnabled
    case multilingualEnabled
    case newsletterEnabled

    // MARK: - SEO
    case metaTitle
    case metaDescription
    case metaKeywords
    case ogImage
    case twitterCard

    // MARK: - System
    case currentYear
    case generatedDate
    case generatorVersion
    case generatorName

    // MARK: - Customization
    case primaryColor
    case secondaryColor
    case fontFamily
    case logoUrl
    case faviconUrl

    public var displayName: String {
        switch self {
        case .projectName: return "Project Name"
        case .description: return "Description"
        case .author: return "Author"
        case .tagline: return "Tagline"
        case .email: return "Email"
        case .githubUrl: return "GitHub URL"
        case .twitterHandle: return "Twitter Handle"
        case .linkedinUrl: return "LinkedIn URL"
        case .website: return "Website"
        case .blogTitle: return "Blog Title"
        case .blogDescription: return "Blog Description"
        case .rssEnabled: return "RSS Enabled"
        case .commentsEnabled: return "Comments Enabled"
        case .disqusShortname: return "Disqus Shortname"
        case .postsPerPage: return "Posts Per Page"
        case .portfolioOwner: return "Portfolio Owner"
        case .resumeUrl: return "Resume URL"
        case .skills: return "Skills"
        case .experience: return "Experience"
        case .education: return "Education"
        case .docsTitle: return "Documentation Title"
        case .searchEnabled: return "Search Enabled"
        case .apiReference: return "API Reference"
        case .tutorialsEnabled: return "Tutorials Enabled"
        case .storeName: return "Store Name"
        case .currency: return "Currency"
        case .stripePublicKey: return "Stripe Public Key"
        case .shippingEnabled: return "Shipping Enabled"
        case .taxRate: return "Tax Rate"
        case .analytics: return "Analytics"
        case .analyticsId: return "Analytics ID"
        case .seoEnabled: return "SEO Enabled"
        case .darkModeEnabled: return "Dark Mode Enabled"
        case .multilingualEnabled: return "Multilingual Enabled"
        case .newsletterEnabled: return "Newsletter Enabled"
        case .metaTitle: return "Meta Title"
        case .metaDescription: return "Meta Description"
        case .metaKeywords: return "Meta Keywords"
        case .ogImage: return "Open Graph Image"
        case .twitterCard: return "Twitter Card"
        case .currentYear: return "Current Year"
        case .generatedDate: return "Generated Date"
        case .generatorVersion: return "Generator Version"
        case .generatorName: return "Generator Name"
        case .primaryColor: return "Primary Color"
        case .secondaryColor: return "Secondary Color"
        case .fontFamily: return "Font Family"
        case .logoUrl: return "Logo URL"
        case .faviconUrl: return "Favicon URL"
        }
    }

    public var isRequired: Bool {
        switch self {
        case .projectName, .description, .author:
            return true
        default:
            return false
        }
    }
}

/// Errors that can occur during template processing.
public enum TemplateError: LocalizedError, Sendable {
    case missingContextValue(ContextKey)
    case invalidTemplate(String)
    case renderingFailed(String)
    case fileWriteFailed(String, Error)

    public var errorDescription: String? {
        switch self {
        case .missingContextValue(let key):
            return "Missing required template value: \(key.displayName)"
        case .invalidTemplate(let reason):
            return "Invalid template: \(reason)"
        case .renderingFailed(let reason):
            return "Template rendering failed: \(reason)"
        case .fileWriteFailed(let path, let error):
            return "Failed to write file '\(path)': \(error.localizedDescription)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .missingContextValue(let key):
            return "Provide a value for '\(key.rawValue)' using --\(key.rawValue) or interactive mode"
        case .invalidTemplate:
            return "Check the template syntax and structure"
        case .renderingFailed:
            return "Verify template variables and syntax"
        case .fileWriteFailed:
            return "Check file permissions and available disk space"
        }
    }
}
