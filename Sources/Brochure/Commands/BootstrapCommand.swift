import ArgumentParser
import Foundation
import Logging

/// Command to create a new static site project from a template.
///
/// The bootstrap command generates a complete project structure for a static website
/// using predefined templates, including HTML, CSS, JavaScript, and configuration files.
struct BootstrapCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bootstrap",
        abstract: "Create a new static site project from a template",
        discussion: """
            Bootstrap creates a new static website project with a complete folder structure,
            starter files, and configuration based on the selected template.

            AVAILABLE TEMPLATES:

            • landing-page: Modern landing page with hero section, features, and CTA
            • blog: Static blog with posts, categories, and RSS feed support
            • portfolio: Professional portfolio with projects showcase
            • documentation: Technical documentation site with navigation
            • ecommerce: Basic e-commerce template with product pages

            EXAMPLES:

              # Create a landing page project
              swift run Brochure bootstrap MyWebsite

              # Use blog template
              swift run Brochure bootstrap MyBlog --template blog

              # Interactive setup
              swift run Brochure bootstrap MyProject --interactive

              # Skip git initialization
              swift run Brochure bootstrap MyProject --no-git-init

              # Specify custom directory
              swift run Brochure bootstrap MyProject --directory ~/Projects

            The generated project includes:
            - Complete folder structure (src, dist, assets)
            - HTML templates with semantic markup
            - Responsive CSS with modern design
            - JavaScript for interactivity
            - Configuration files (README.md, .gitignore)
            - Build scripts and deployment instructions
            """,
        subcommands: []
    )

    @Argument(help: "Name of the project to create")
    var projectName: String

    @Option(
        name: .long,
        help: "Template to use (landing-page, blog, portfolio, documentation, ecommerce)"
    )
    var template: String = "landing-page"

    @Flag(name: .long, help: "List all available templates and exit")
    var listTemplates = false

    @Option(name: .long, help: "Show detailed information about a specific template")
    var templateInfo: String?

    @Option(name: .long, help: "Directory to create project in")
    var directory: String = "."

    @Option(name: .long, help: "Project description")
    var description: String?

    @Option(name: .long, help: "Author name")
    var author: String?

    @Option(name: .long, help: "Author email")
    var email: String?

    @Option(name: .long, help: "Project tagline or subtitle")
    var tagline: String?

    @Flag(name: .long, help: "Interactive mode for guided setup")
    var interactive = false

    @Flag(name: .long, help: "Include analytics setup")
    var withAnalytics = false

    @Flag(name: .long, inversion: .prefixedNo, help: "Include SEO meta tags")
    var withSeo = true

    @Flag(name: .long, inversion: .prefixedNo, help: "Initialize git repository")
    var gitInit = true

    @Flag(name: .long, help: "Force overwrite if directory exists")
    var force = false

    @Flag(name: .shortAndLong, help: "Enable verbose output")
    var verbose = false

    @Flag(name: .shortAndLong, help: "Quiet mode - minimal output")
    var quiet = false

    mutating func run() async throws {
        var logger = Logger(label: "BootstrapCommand")
        logger.logLevel = quiet ? .error : (verbose ? .debug : .info)

        let templateManager = TemplateManager(logger: logger)
        let securityScanner = SecurityScanner(logger: logger)

        // Handle template listing and info requests first
        if listTemplates {
            printAvailableTemplates(templateManager: templateManager)
            return
        }

        if let templateId = templateInfo {
            try printTemplateInfo(templateId: templateId, templateManager: templateManager)
            return
        }

        // Validate project name with security scanning
        do {
            try validateProjectName(projectName)

            // Additional security validation
            let validationResult = securityScanner.validateUserInput(
                projectName,
                inputType: .projectName,
                context: "bootstrap project name"
            )

            if !validationResult.isValid {
                let violations = validationResult.violations.map { $0.description }.joined(separator: ", ")
                throw BootstrapError.invalidProjectName(
                    projectName,
                    reason: "Security validation failed: \(violations)"
                )
            }

            if validationResult.riskLevel != .none {
                logger.warning(
                    "⚠️ Project name has security concerns",
                    metadata: [
                        "project_name": .string(projectName),
                        "risk_level": .string(validationResult.riskLevel.rawValue),
                    ]
                )
            }

        } catch let error as BootstrapError {
            // Provide suggestions for better names
            if case .invalidProjectName(let name, let reason) = error {
                let suggestions = generateProjectNameSuggestions(from: name)
                if !suggestions.isEmpty {
                    let suggestionText = suggestions.joined(separator: ", ")
                    throw BootstrapError.invalidProjectName(
                        name,
                        reason: "\(reason)\n\nSuggestions: \(suggestionText)"
                    )
                }
            }
            throw error
        }

        // Validate all arguments
        try validateArguments()

        // Validate directory path
        try validateDirectoryPath(directory)

        // Load template
        guard let selectedTemplate = templateManager.template(withId: template) else {
            let availableTemplates = templateManager.availableTemplates()
                .map { "\($0.id) (\($0.name))" }
                .sorted()
                .joined(separator: ", ")
            throw BootstrapError.templateNotFound(
                template,
                available: availableTemplates
            )
        }

        if !quiet {
            logger.info("🚀 Creating project '\(projectName)' using '\(selectedTemplate.name)' template")
        }

        // Build template context
        var finalTemplate = selectedTemplate
        var context: TemplateContext
        if interactive {
            // In interactive mode, allow template selection if default is being used
            if template == "landing-page" && !CommandLine.arguments.contains("--template") {
                finalTemplate = try selectTemplateInteractively(templateManager: templateManager, logger: logger)
            }
            context = try await runInteractiveSetup(for: finalTemplate, logger: logger)
        } else {
            context = buildContext(for: finalTemplate)
        }

        // Determine project path
        let basePath = URL(fileURLWithPath: directory, isDirectory: true)
            .standardizedFileURL
        let projectPath = basePath.appendingPathComponent(projectName)

        // Check if directory exists
        if FileManager.default.fileExists(atPath: projectPath.path) {
            if force {
                logger.warning("⚠️  Directory exists, removing: \(projectPath.path)")
                try FileManager.default.removeItem(at: projectPath)
            } else {
                throw BootstrapError.directoryExists(projectPath.path)
            }
        }

        // Generate project
        logger.info("📁 Creating project structure...")
        let generator = ProjectGenerator(logger: logger)
        try await generator.generate(
            template: finalTemplate,
            at: projectPath,
            with: context
        )

        // Security scan the generated project
        logger.info("🔍 Performing security scan of generated project...")
        do {
            let scanResult = try await securityScanner.scanProjectDirectory(at: projectPath.path)

            if scanResult.hasIssues {
                let criticalIssues = scanResult.findingsBySeverity[SecuritySeverity.critical] ?? 0
                let highIssues = scanResult.findingsBySeverity[SecuritySeverity.high] ?? 0

                if criticalIssues > 0 || highIssues > 0 {
                    logger.error("🚨 Critical security issues found in generated project")

                    // Log critical and high severity issues
                    let criticalFindings = scanResult.allFindings.filter { $0.severity == SecuritySeverity.critical }
                    let highFindings = scanResult.allFindings.filter { $0.severity == SecuritySeverity.high }

                    for finding in criticalFindings + highFindings {
                        logger.error("  \(finding.severity.emoji) \(finding.description): \(finding.evidence)")
                    }

                    throw BootstrapError.securityScanFailed(
                        "Generated project contains \(criticalIssues) critical and \(highIssues) high-severity security issues"
                    )
                } else {
                    logger.warning(
                        "⚠️ Security issues found in generated project",
                        metadata: [
                            "total_findings": .stringConvertible(scanResult.totalFindings),
                            "severity": .string(scanResult.overallSeverity.rawValue),
                        ]
                    )

                    if verbose {
                        // Show details in verbose mode
                        for finding in scanResult.allFindings {
                            logger.debug("  \(finding.severity.emoji) \(finding.description) in \(finding.evidence)")
                        }
                    }
                }
            } else {
                logger.info("✅ Security scan passed - no issues found")
            }

        } catch let error as SecurityScanError {
            logger.warning(
                "⚠️ Security scan failed",
                metadata: [
                    "error": .string(error.localizedDescription)
                ]
            )
            // Don't fail the bootstrap command if security scan fails, just warn
        }

        // Initialize git if requested
        if gitInit {
            logger.info("📦 Initializing git repository...")
            do {
                try await initializeGit(at: projectPath, logger: logger)
            } catch {
                logger.warning("⚠️  Git initialization failed: \(error.localizedDescription)")
            }
        }

        // Success message
        if !quiet {
            printSuccessMessage(
                projectName: projectName,
                projectPath: projectPath.path,
                template: finalTemplate.name
            )
        }
    }

    private func validateProjectName(_ name: String) throws {
        // Check for empty or whitespace-only names
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw BootstrapError.invalidProjectName(
                name,
                reason: "Project name cannot be empty or contain only whitespace"
            )
        }

        // Check for reasonable length (more restrictive for better filesystem compatibility)
        guard trimmedName.count >= 2 && trimmedName.count <= 64 else {
            throw BootstrapError.invalidProjectName(
                name,
                reason: "Name must be between 2 and 64 characters for filesystem compatibility"
            )
        }

        // Check for valid characters (letters, numbers, hyphens, underscores, dots)
        let validCharacters = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "-_."))
        let nameCharacters = CharacterSet(charactersIn: trimmedName)

        guard validCharacters.isSuperset(of: nameCharacters) else {
            throw BootstrapError.invalidProjectName(
                name,
                reason: "Use only letters, numbers, hyphens, underscores, and dots"
            )
        }

        // Check doesn't start with special characters
        guard let firstChar = trimmedName.first,
            firstChar.isLetter || firstChar.isNumber
        else {
            throw BootstrapError.invalidProjectName(
                name,
                reason: "Name must start with a letter or number"
            )
        }

        // Check doesn't end with special characters (except dots for extensions)
        guard let lastChar = trimmedName.last,
            lastChar.isLetter || lastChar.isNumber || lastChar == "."
        else {
            throw BootstrapError.invalidProjectName(
                name,
                reason: "Name must end with a letter, number, or dot"
            )
        }

        // Check for reserved names (case-insensitive)
        let reservedNames = [
            // System directories
            "bin", "etc", "lib", "opt", "sbin", "tmp", "usr", "var", "dev", "proc", "sys",
            // Windows reserved names
            "con", "prn", "aux", "nul", "com1", "com2", "com3", "com4", "com5", "com6",
            "com7", "com8", "com9", "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6",
            "lpt7", "lpt8", "lpt9",
            // Common reserved names
            "node_modules", "package-lock", "yarn.lock", ".git", ".svn", ".hg",
            // Language-specific reserved
            "src", "dist", "build", "public", "static", "assets", "vendor", "target",
            // Our tool names
            "brochure", "luxe", "vegas", "bazaar", "palette", "dali", "bouncer",
        ]

        let lowercaseName = trimmedName.lowercased()
        if reservedNames.contains(lowercaseName) {
            throw BootstrapError.invalidProjectName(
                name,
                reason: "'\(trimmedName)' is a reserved name and cannot be used"
            )
        }

        // Check for names that could conflict with common tools/commands
        let conflictingNames = [
            "git", "npm", "yarn", "node", "python", "swift", "cargo", "make", "cmake",
            "docker", "kubernetes", "k8s", "aws", "gcp", "azure", "terraform",
        ]

        if conflictingNames.contains(lowercaseName) {
            throw BootstrapError.invalidProjectName(
                name,
                reason: "'\(trimmedName)' conflicts with common tools and should be avoided"
            )
        }

        // Check for consecutive special characters
        if trimmedName.contains("--") || trimmedName.contains("__") || trimmedName.contains("..") {
            throw BootstrapError.invalidProjectName(
                name,
                reason: "Consecutive special characters (--, __, ..) are not allowed"
            )
        }

        // Check for mixed case with hyphens (kebab-case validation)
        if trimmedName.contains("-") {
            let components = trimmedName.components(separatedBy: "-")
            for component in components {
                if component.isEmpty {
                    throw BootstrapError.invalidProjectName(
                        name,
                        reason: "Hyphens cannot be at the beginning, end, or consecutive"
                    )
                }
                // Recommend lowercase for kebab-case
                if component != component.lowercased() {
                    throw BootstrapError.invalidProjectName(
                        name,
                        reason: "Use lowercase letters with hyphens (kebab-case) for better compatibility"
                    )
                }
            }
        }

        // Platform-specific validation
        #if os(Windows)
        // Windows additional restrictions
        if trimmedName.contains(":") || trimmedName.contains("\\") || trimmedName.contains("/")
            || trimmedName.contains("*") || trimmedName.contains("?") || trimmedName.contains("\"")
            || trimmedName.contains("<") || trimmedName.contains(">") || trimmedName.contains("|")
        {
            throw BootstrapError.invalidProjectName(
                name,
                reason: "Name contains characters not allowed on Windows filesystems"
            )
        }
        #endif

        // Validate as potential URL component (for deployment compatibility)
        let urlSafeCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-."))
        if !urlSafeCharacters.isSuperset(of: nameCharacters) {
            throw BootstrapError.invalidProjectName(
                name,
                reason: "Name should be URL-safe for deployment compatibility"
            )
        }
    }

    private func generateProjectNameSuggestions(from name: String) -> [String] {
        var suggestions: [String] = []
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Convert to kebab-case
        let kebabCase =
            trimmedName
            .lowercased()
            .replacingOccurrences(of: "[ _]+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "^-+|-+$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)

        if !kebabCase.isEmpty && kebabCase != trimmedName.lowercased() {
            suggestions.append(kebabCase)
        }

        // Convert to snake_case
        let snakeCase =
            trimmedName
            .lowercased()
            .replacingOccurrences(of: "[ -]+", with: "_", options: .regularExpression)
            .replacingOccurrences(of: "[^a-z0-9_]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "^_+|_+$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "_+", with: "_", options: .regularExpression)

        if !snakeCase.isEmpty && snakeCase != kebabCase {
            suggestions.append(snakeCase)
        }

        // Add common prefixes/suffixes for different template types
        let cleanBase = kebabCase.isEmpty ? snakeCase : kebabCase
        if !cleanBase.isEmpty && cleanBase.count >= 2 {
            suggestions.append("\(cleanBase)-app")
            suggestions.append("\(cleanBase)-site")
            suggestions.append("my-\(cleanBase)")
        }

        // Remove duplicates and invalid suggestions
        return Array(Set(suggestions)).filter { suggestion in
            do {
                try validateProjectName(suggestion)
                return true
            } catch {
                return false
            }
        }.prefix(3).map { String($0) }
    }

    private func validateDirectoryPath(_ path: String) throws {
        // Expand tilde and resolve path
        let expandedPath = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)

        // Check if path is absolute or relative
        if !url.path.hasPrefix("/") && !path.hasPrefix(".") && path != "." {
            // Relative path without explicit current directory notation - this is fine
        }

        // Check if parent directory exists (if not current directory)
        if path != "." {
            let parentURL = url.deletingLastPathComponent()
            var isDirectory: ObjCBool = false

            if FileManager.default.fileExists(atPath: parentURL.path, isDirectory: &isDirectory) {
                if !isDirectory.boolValue {
                    throw BootstrapError.invalidDirectory(
                        path,
                        reason: "Parent path exists but is not a directory: \(parentURL.path)"
                    )
                }
            } else {
                // Parent directory doesn't exist
                throw BootstrapError.invalidDirectory(
                    path,
                    reason: "Parent directory does not exist: \(parentURL.path)"
                )
            }
        }

        // Check for write permissions in parent directory
        let testURL =
            (path == ".")
            ? URL(fileURLWithPath: FileManager.default.currentDirectoryPath) : url.deletingLastPathComponent()

        if !FileManager.default.isWritableFile(atPath: testURL.path) {
            throw BootstrapError.invalidDirectory(
                path,
                reason: "No write permission in directory: \(testURL.path)"
            )
        }

        // Validate path doesn't contain problematic characters
        let problematicChars = CharacterSet(charactersIn: "*?\"<>|")
        if expandedPath.rangeOfCharacter(from: problematicChars) != nil {
            throw BootstrapError.invalidDirectory(
                path,
                reason: "Directory path contains invalid characters"
            )
        }

        // Check path length (filesystem limitations)
        if expandedPath.count > 1024 {
            throw BootstrapError.invalidDirectory(
                path,
                reason: "Directory path is too long (max 1024 characters)"
            )
        }
    }

    private func validateArguments() throws {
        // Validate template name format
        if template.isEmpty {
            throw BootstrapError.invalidArgument("template", reason: "Template name cannot be empty")
        }

        // Validate description length if provided
        if let desc = description, desc.count > 500 {
            throw BootstrapError.invalidArgument("description", reason: "Description too long (max 500 characters)")
        }

        // Validate author name if provided
        if let auth = author {
            if auth.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw BootstrapError.invalidArgument("author", reason: "Author name cannot be empty or whitespace")
            }
            if auth.count > 100 {
                throw BootstrapError.invalidArgument("author", reason: "Author name too long (max 100 characters)")
            }
        }

        // Validate email format if provided
        if let email = email {
            let emailRegex = try NSRegularExpression(pattern: "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")
            let range = NSRange(location: 0, length: email.utf16.count)
            if emailRegex.firstMatch(in: email, range: range) == nil {
                throw BootstrapError.invalidArgument("email", reason: "Invalid email format")
            }
        }

        // Validate tagline length if provided
        if let tag = tagline, tag.count > 200 {
            throw BootstrapError.invalidArgument("tagline", reason: "Tagline too long (max 200 characters)")
        }

        // Validate conflicting flags
        if quiet && verbose {
            throw BootstrapError.invalidArgument("flags", reason: "Cannot use both --quiet and --verbose flags")
        }
    }

    private func buildContext(for template: Template) -> TemplateContext {
        var context = TemplateContext()

        // Required fields
        context[.projectName] = projectName
        context[.description] = description ?? "A static website built with Brochure"
        context[.author] = author ?? ProcessInfo.processInfo.environment["USER"] ?? "Unknown"

        // Optional fields
        if let email = email {
            context[.email] = email
        }

        if let tagline = tagline {
            context[.tagline] = tagline
        }

        // Feature flags
        if withAnalytics {
            context[.analytics] = true
            context[.analyticsId] = "GA_MEASUREMENT_ID"  // Placeholder
        }

        if withSeo {
            context[.seoEnabled] = true
        }

        // Template-specific defaults
        switch template.category {
        case .blog:
            context[.blogTitle] = context[.projectName] ?? "My Blog"
            context[.blogDescription] = context[.description] ?? "A blog about interesting topics"
            context[.rssEnabled] = true

        case .portfolio:
            context[.portfolioOwner] = context[.author] ?? "Portfolio Owner"

        case .documentation:
            context[.docsTitle] = context[.projectName] ?? "Documentation"
            context[.searchEnabled] = true

        case .ecommerce:
            context[.storeName] = context[.projectName] ?? "My Store"
            context[.currency] = "USD"

        default:
            break
        }

        return context
    }

    private func runInteractiveSetup(
        for template: Template,
        logger: Logger
    ) async throws -> TemplateContext {
        var context = TemplateContext()

        print("\n🎨 Interactive Project Setup")
        print("Template: \(template.name) - \(template.description)")
        print(String(repeating: "-", count: 50))
        print()

        // Show template features
        let featuresText = formatTemplateFeatures(template.features)
        print("✨ This template includes:")
        print(featuresText.replacingOccurrences(of: "\n            ", with: "\n   "))
        print()

        // Project name is already set from argument
        context[.projectName] = projectName

        // Collect common fields
        context[.description] = promptForInput(
            "Project description",
            defaultValue: "A static website built with Brochure"
        )

        context[.author] = promptForInput(
            "Author name",
            defaultValue: ProcessInfo.processInfo.environment["USER"] ?? "Unknown"
        )

        if let email = promptForOptionalInput("Author email") {
            context[.email] = email
        }

        if let tagline = promptForOptionalInput("Project tagline") {
            context[.tagline] = tagline
        }

        // Template-specific questions
        switch template.category {
        case .blog:
            print("\n📝 Blog Configuration")
            context[.blogTitle] = promptForInput(
                "Blog title",
                defaultValue: projectName
            )
            context[.blogDescription] = promptForInput(
                "Blog description",
                defaultValue: "A blog about interesting topics"
            )
            context[.rssEnabled] = promptForBool("Enable RSS feed?", defaultValue: true)

        case .portfolio:
            print("\n🎨 Portfolio Configuration")
            context[.portfolioOwner] = promptForInput(
                "Portfolio owner name",
                defaultValue: context[.author] as? String ?? "Portfolio Owner"
            )
            if let resumeUrl = promptForOptionalInput("Resume URL (optional)") {
                context[.resumeUrl] = resumeUrl
            }

        case .documentation:
            print("\n📚 Documentation Configuration")
            context[.docsTitle] = promptForInput(
                "Documentation title",
                defaultValue: projectName
            )
            context[.searchEnabled] = promptForBool("Enable search?", defaultValue: true)

        case .ecommerce:
            print("\n🛍️ E-commerce Configuration")
            context[.storeName] = promptForInput(
                "Store name",
                defaultValue: projectName
            )
            context[.currency] = promptForInput(
                "Currency code",
                defaultValue: "USD"
            )

        default:
            break
        }

        // Optional features
        print("\n⚙️  Optional Features")
        if promptForBool("Include analytics?", defaultValue: false) {
            context[.analytics] = true
            if let analyticsId = promptForOptionalInput("Analytics ID (or press enter to add later)") {
                context[.analyticsId] = analyticsId
            } else {
                context[.analyticsId] = "GA_MEASUREMENT_ID"  // Placeholder
            }
        }

        context[.seoEnabled] = promptForBool("Include SEO meta tags?", defaultValue: true)

        print()
        return context
    }

    private func promptForInput(_ prompt: String, defaultValue: String) -> String {
        print("\(prompt) [\(defaultValue)]: ", terminator: "")
        if let input = readLine(), !input.isEmpty {
            return input
        }
        return defaultValue
    }

    private func promptForOptionalInput(_ prompt: String) -> String? {
        print("\(prompt) (optional): ", terminator: "")
        if let input = readLine(), !input.isEmpty {
            return input
        }
        return nil
    }

    private func promptForBool(_ prompt: String, defaultValue: Bool) -> Bool {
        let defaultText = defaultValue ? "Y/n" : "y/N"
        print("\(prompt) [\(defaultText)]: ", terminator: "")
        if let input = readLine()?.lowercased() {
            if input == "y" || input == "yes" {
                return true
            } else if input == "n" || input == "no" {
                return false
            }
        }
        return defaultValue
    }

    private func initializeGit(at path: URL, logger: Logger) async throws {
        let process = Process()
        process.currentDirectoryURL = path
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")

        // Initialize repository
        process.arguments = ["init"]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw BootstrapError.gitInitFailed("Failed to initialize repository")
        }

        // Add all files
        process.arguments = ["add", "."]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw BootstrapError.gitInitFailed("Failed to add files")
        }

        // Create initial commit
        process.arguments = ["commit", "-m", "Initial commit - Bootstrap with Brochure CLI"]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            // This might fail if user hasn't configured git
            logger.debug("Initial commit failed - user may need to configure git")
            return
        }
    }

    private func printSuccessMessage(
        projectName: String,
        projectPath: String,
        template: String
    ) {
        print(
            """

            ✅ Project created successfully!

            📁 Location: \(projectPath)
            📄 Template: \(template)
            🎨 Project: \(projectName)

            Next steps:
            1. cd \(projectName)
            2. Review README.md for project-specific instructions
            3. Customize the template to your needs
            4. Build your static site
            5. Deploy with: brochure upload \(projectName)

            Useful commands:
            • Preview locally: python3 -m http.server 8000
            • Upload to S3: brochure upload \(projectName)
            • Verify deployment: brochure verify --self

            Happy building! 🎉
            """
        )
    }

    // MARK: - Template Selection Methods

    private func selectTemplateInteractively(
        templateManager: TemplateManager,
        logger: Logger
    ) throws -> Template {
        let templates = templateManager.availableTemplates().sorted { $0.id < $1.id }

        print("\n📋 Available Templates")
        print(String(repeating: "=", count: 50))

        for (index, template) in templates.enumerated() {
            let featuresText = template.features.prefix(3).map { feature in
                switch feature {
                case .responsive: return "📱 Responsive"
                case .seo: return "🔍 SEO"
                case .analytics: return "📊 Analytics"
                case .markdown: return "📝 Markdown"
                case .rss: return "📡 RSS"
                case .search: return "🔎 Search"
                case .categories: return "🏷️ Categories"
                case .gallery: return "🖼️ Gallery"
                case .contactForm: return "📧 Contact"
                case .resume: return "📄 Resume"
                case .darkMode: return "🌙 Dark Mode"
                case .multilingual: return "🌍 Multi-lang"
                case .comments: return "💬 Comments"
                case .newsletter: return "📬 Newsletter"
                case .socialSharing: return "📤 Social"
                }
            }.joined(separator: ", ")

            print("\(index + 1). \(template.name)")
            print("   \(template.description)")
            if !featuresText.isEmpty {
                print("   Features: \(featuresText)")
            }
            print()
        }

        while true {
            print("Select a template (1-\(templates.count)) [1]: ", terminator: "")
            let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if input.isEmpty {
                return templates[0]  // Default to first template
            }

            if let index = Int(input), index >= 1 && index <= templates.count {
                return templates[index - 1]
            }

            print("❌ Invalid selection. Please enter a number between 1 and \(templates.count).")
        }
    }

    private func printAvailableTemplates(templateManager: TemplateManager) {
        let templates = templateManager.availableTemplates().sorted { $0.id < $1.id }

        print(
            """

            📋 Available Templates
            =====================

            """
        )

        for template in templates {
            let featuresText = formatTemplateFeatures(template.features)
            print(
                """
                \(template.id)
                  Name: \(template.name)
                  Description: \(template.description)
                  Category: \(template.category.displayName)
                  Version: \(template.version.toString())
                  Features: \(featuresText)

                """
            )
        }

        print(
            """
            Usage Examples:

              # Use a specific template
              swift run Brochure bootstrap MyProject --template blog

              # Get detailed info about a template
              swift run Brochure bootstrap --template-info portfolio

              # Interactive setup with template selection
              swift run Brochure bootstrap MyProject --interactive

            """
        )
    }

    private func printTemplateInfo(templateId: String, templateManager: TemplateManager) throws {
        guard let template = templateManager.template(withId: templateId) else {
            let availableTemplates = templateManager.availableTemplates()
                .map { $0.id }
                .sorted()
                .joined(separator: ", ")
            throw BootstrapError.templateNotFound(
                templateId,
                available: availableTemplates
            )
        }

        let featuresText = formatTemplateFeatures(template.features)
        let requiredContext = template.requiredContext.map { $0.displayName }.joined(separator: ", ")
        let optionalContext = template.optionalContext.map { $0.displayName }.joined(separator: ", ")

        print(
            """

            📄 Template Details: \(template.name)
            =====================================

            ID: \(template.id)
            Name: \(template.name)
            Description: \(template.description)
            Category: \(template.category.displayName)
            Version: \(template.version.toString())

            Features:
            \(featuresText)

            Required Information:
            \(requiredContext.isEmpty ? "None" : requiredContext)

            Optional Information:
            \(optionalContext.isEmpty ? "None" : optionalContext)

            Directory Structure:
            """
        )

        // Show directory structure
        let directories = template.structure.directories.map { $0.path }.sorted()
        for directory in directories {
            print("  📁 \(directory)/")
        }

        print("\n            Key Files:")
        let keyFiles = template.structure.files
            .filter { !$0.path.hasPrefix(".") && $0.path != "README.md" }
            .map { $0.path }
            .sorted()
        for file in keyFiles {
            print("  📄 \(file)")
        }

        print(
            """

            Usage:
              swift run Brochure bootstrap MyProject --template \(template.id)

            """
        )
    }

    private func formatTemplateFeatures(_ features: Set<TemplateFeature>) -> String {
        if features.isEmpty {
            return "None"
        }

        let featureNames = features.map { feature in
            switch feature {
            case .responsive: return "📱 Responsive Design"
            case .seo: return "🔍 SEO Optimized"
            case .analytics: return "📊 Analytics Ready"
            case .markdown: return "📝 Markdown Support"
            case .rss: return "📡 RSS Feed"
            case .search: return "🔎 Search"
            case .categories: return "🏷️ Categories"
            case .gallery: return "🖼️ Image Gallery"
            case .contactForm: return "📧 Contact Form"
            case .resume: return "📄 Resume/CV"
            case .darkMode: return "🌙 Dark Mode"
            case .multilingual: return "🌍 Multi-language"
            case .comments: return "💬 Comments"
            case .newsletter: return "📬 Newsletter"
            case .socialSharing: return "📤 Social Sharing"
            }
        }.sorted()

        return featureNames.joined(separator: "\n            ")
    }
}

// MARK: - Bootstrap Errors

enum BootstrapError: LocalizedError {
    case templateNotFound(String, available: String)
    case directoryExists(String)
    case invalidProjectName(String, reason: String)
    case invalidDirectory(String, reason: String)
    case invalidArgument(String, reason: String)
    case gitInitFailed(String)
    case templateGenerationFailed(String)
    case securityScanFailed(String)

    var errorDescription: String? {
        switch self {
        case .templateNotFound(let name, let available):
            return "Template '\(name)' not found. Available templates: \(available)"
        case .directoryExists(let path):
            return "Directory already exists: \(path). Use --force to overwrite."
        case .invalidProjectName(let name, let reason):
            return "Invalid project name '\(name)': \(reason)"
        case .invalidDirectory(let path, let reason):
            return "Invalid directory '\(path)': \(reason)"
        case .invalidArgument(let argument, let reason):
            return "Invalid argument '\(argument)': \(reason)"
        case .gitInitFailed(let message):
            return "Git initialization failed: \(message)"
        case .templateGenerationFailed(let message):
            return "Template generation failed: \(message)"
        case .securityScanFailed(let message):
            return "Security scan failed: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .templateNotFound:
            return "Use one of the available templates or check spelling"
        case .directoryExists:
            return "Choose a different name or use --force to overwrite"
        case .invalidProjectName:
            return "Use kebab-case (lowercase with hyphens) for best compatibility"
        case .invalidDirectory:
            return "Ensure the parent directory exists and you have write permissions"
        case .invalidArgument:
            return "Check the argument value and format"
        case .gitInitFailed:
            return "Ensure git is installed and configured with user.name and user.email"
        case .templateGenerationFailed:
            return "Check file permissions and available disk space"
        case .securityScanFailed:
            return "Review generated templates for security issues and modify template content if needed"
        }
    }
}
