import Foundation

/// Semantic version for templates following semver.org
public struct TemplateVersion: Sendable, Comparable, Equatable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = max(0, major)
        self.minor = max(0, minor)
        self.patch = max(0, patch)
    }

    public init(fromString versionString: String) throws {
        let components = versionString.split(separator: ".").map(String.init)

        guard components.count == 3 else {
            throw TemplateVersionError.invalidFormat("Version must be in format major.minor.patch")
        }

        guard let major = Int(components[0]),
            let minor = Int(components[1]),
            let patch = Int(components[2]),
            major >= 0, minor >= 0, patch >= 0
        else {
            throw TemplateVersionError.invalidFormat("All version components must be non-negative integers")
        }

        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public func toString() -> String {
        "\(major).\(minor).\(patch)"
    }

    /// Check if this version is compatible with another version
    /// Compatible means same major version (according to semver)
    public func isCompatible(with other: TemplateVersion) -> Bool {
        self.major == other.major
    }

    public static func < (lhs: TemplateVersion, rhs: TemplateVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }

    public static func == (lhs: TemplateVersion, rhs: TemplateVersion) -> Bool {
        lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
    }
}

/// Migration information between template versions
public struct TemplateMigrationInfo: Sendable {
    public let fromVersion: TemplateVersion
    public let toVersion: TemplateVersion
    public let isBreakingChange: Bool
    public let canAutoMigrate: Bool
    public let migrationNotes: String?

    public init(
        from: TemplateVersion,
        to: TemplateVersion,
        migrationNotes: String? = nil
    ) {
        self.fromVersion = from
        self.toVersion = to

        // Breaking change if major version changes
        self.isBreakingChange = from.major != to.major

        // Can auto-migrate if compatible (same major version)
        self.canAutoMigrate = from.isCompatible(with: to)

        self.migrationNotes = migrationNotes
    }
}

/// Errors related to template versioning
public enum TemplateVersionError: LocalizedError, Sendable {
    case invalidFormat(String)
    case incompatibleVersion(String)

    public var errorDescription: String? {
        switch self {
        case .invalidFormat(let message):
            return "Invalid version format: \(message)"
        case .incompatibleVersion(let message):
            return "Incompatible version: \(message)"
        }
    }
}

/// Represents a project template for the bootstrap command.
public struct Template: Sendable {
    /// Unique identifier for the template
    public let id: String

    /// Human-readable name
    public let name: String

    /// Description of what the template provides
    public let description: String

    /// Category of the template
    public let category: TemplateCategory

    /// File and directory structure
    public let structure: TemplateStructure

    /// Features included in the template
    public let features: Set<TemplateFeature>

    /// Required context keys for this template
    public let requiredContext: [ContextKey]

    /// Optional context keys that enhance the template
    public let optionalContext: [ContextKey]

    /// Version of the template
    public let version: TemplateVersion

    public init(
        id: String,
        name: String,
        description: String,
        category: TemplateCategory,
        structure: TemplateStructure,
        features: Set<TemplateFeature> = [],
        requiredContext: [ContextKey] = [],
        optionalContext: [ContextKey] = [],
        version: TemplateVersion = TemplateVersion(major: 1, minor: 0, patch: 0)
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.structure = structure
        self.features = features
        self.requiredContext = requiredContext
        self.optionalContext = optionalContext
        self.version = version
    }

    /// Check if this template is compatible with a specific version
    public func isCompatible(withVersion targetVersion: TemplateVersion) -> Bool {
        version.isCompatible(with: targetVersion)
    }

    /// Generate migration information to another version
    public func migrationInfo(to targetVersion: TemplateVersion) -> TemplateMigrationInfo {
        TemplateMigrationInfo(
            from: self.version,
            to: targetVersion,
            migrationNotes: generateMigrationNotes(to: targetVersion)
        )
    }

    /// Generate version metadata for the template
    public func versionMetadata() -> [String: Any] {
        [
            "version": version.toString(),
            "major": version.major,
            "minor": version.minor,
            "patch": version.patch,
            "template_id": id,
            "template_name": name,
            "category": category.rawValue,
        ]
    }

    private func generateMigrationNotes(to targetVersion: TemplateVersion) -> String? {
        if version.major < targetVersion.major {
            return "Major version upgrade may include breaking changes. Manual review recommended."
        } else if version.minor < targetVersion.minor {
            return "Minor version upgrade includes new features and improvements."
        } else if version.patch < targetVersion.patch {
            return "Patch version upgrade includes bug fixes and minor improvements."
        } else if version == targetVersion {
            return "No migration needed - versions are identical."
        } else {
            return "Downgrade detected - this may remove features or cause compatibility issues."
        }
    }
}

/// Category of template
public enum TemplateCategory: String, Sendable, CaseIterable {
    case landingPage = "landing-page"
    case blog = "blog"
    case portfolio = "portfolio"
    case documentation = "documentation"
    case ecommerce = "ecommerce"

    public var displayName: String {
        switch self {
        case .landingPage: return "Landing Page"
        case .blog: return "Blog"
        case .portfolio: return "Portfolio"
        case .documentation: return "Documentation"
        case .ecommerce: return "E-commerce"
        }
    }
}

/// Features that can be included in a template
public enum TemplateFeature: String, Sendable {
    case responsive
    case seo
    case analytics
    case markdown
    case rss
    case search
    case categories
    case gallery
    case contactForm
    case resume
    case darkMode
    case multilingual
    case comments
    case newsletter
    case socialSharing
}

/// Structure of directories and files in a template
public struct TemplateStructure: Sendable {
    public let directories: [DirectoryTemplate]
    public let files: [FileTemplate]
    public let assets: [AssetTemplate]

    public init(
        directories: [DirectoryTemplate] = [],
        files: [FileTemplate] = [],
        assets: [AssetTemplate] = []
    ) {
        self.directories = directories
        self.files = files
        self.assets = assets
    }
}

/// Template for a directory to create
public struct DirectoryTemplate: Sendable {
    public let path: String
    public let permissions: FilePermissions

    public init(path: String, permissions: FilePermissions = .default) {
        self.path = path
        self.permissions = permissions
    }
}

/// Template for a file to generate
public struct FileTemplate: Sendable {
    public let path: String
    public let content: FileContent
    public let encoding: String.Encoding
    public let permissions: FilePermissions

    public init(
        path: String,
        content: FileContent,
        encoding: String.Encoding = .utf8,
        permissions: FilePermissions = .default
    ) {
        self.path = path
        self.content = content
        self.encoding = encoding
        self.permissions = permissions
    }
}

/// Content type for file templates
public enum FileContent: Sendable {
    /// Template string that will be processed with variable substitution
    case template(String)

    /// Static content that will be written as-is
    case `static`(String)

    /// Binary data content
    case binary(Data)
}

/// Template for an asset to include
public struct AssetTemplate: Sendable {
    public let path: String
    public let content: AssetContent
    public let permissions: FilePermissions

    public init(
        path: String,
        content: AssetContent,
        permissions: FilePermissions = .default
    ) {
        self.path = path
        self.content = content
        self.permissions = permissions
    }
}

/// Content type for asset templates
public enum AssetContent: Sendable {
    /// Embedded data
    case embedded(Data)

    /// Base64 encoded string
    case base64(String)

    /// Reference to external resource
    case external(URL)
}

/// File permissions
public struct FilePermissions: OptionSet, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public static let `default` = FilePermissions(rawValue: 0o644)
    public static let executable = FilePermissions(rawValue: 0o755)
    public static let readonly = FilePermissions(rawValue: 0o444)
    public static let directory = FilePermissions(rawValue: 0o755)
}
