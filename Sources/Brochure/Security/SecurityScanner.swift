import Foundation
import Logging

/// Comprehensive security scanner for template content and user input validation.
///
/// `SecurityScanner` provides protection against various security threats including:
/// - Code injection attacks
/// - Cross-site scripting (XSS)
/// - Path traversal attacks
/// - Malicious content in templates
/// - Unsafe user input patterns
///
/// ## Key Features
///
/// - **Template Content Scanning**: Analyzes generated templates for security vulnerabilities
/// - **Input Validation**: Validates user-provided input for malicious patterns
/// - **XSS Prevention**: Detects and prevents cross-site scripting vulnerabilities
/// - **Path Traversal Protection**: Prevents directory traversal attacks
/// - **Content Security Policy**: Validates CSP compliance in generated content
/// - **Configurable Rules**: Extensible security rule engine
///
/// ## Usage Examples
///
/// ```swift
/// let scanner = SecurityScanner()
///
/// // Scan template content
/// let templateContent = "<script>alert('xss')</script>"
/// let scanResult = scanner.scanTemplateContent(templateContent, templateType: .html)
///
/// // Validate user input
/// let userInput = "../../etc/passwd"
/// let validationResult = scanner.validateUserInput(userInput, inputType: .projectName)
///
/// // Scan entire project directory
/// let projectScanResult = try await scanner.scanProjectDirectory(at: projectPath)
/// ```
public struct SecurityScanner {
    private let logger: Logger
    private let configuration: SecurityConfiguration

    /// Initializes the security scanner with configuration.
    ///
    /// - Parameters:
    ///   - logger: Logger for security events
    ///   - configuration: Security scanning configuration
    public init(
        logger: Logger = Logger(label: "SecurityScanner"),
        configuration: SecurityConfiguration = .default
    ) {
        self.logger = logger
        self.configuration = configuration
    }

    /// Scans template content for security vulnerabilities.
    ///
    /// This method analyzes template content for various security threats including
    /// XSS vulnerabilities, code injection, and unsafe content patterns.
    ///
    /// - Parameters:
    ///   - content: Template content to scan
    ///   - templateType: Type of template being scanned
    ///   - fileName: Optional file name for context
    /// - Returns: Security scan result with findings
    public func scanTemplateContent(
        _ content: String,
        templateType: TemplateType,
        fileName: String? = nil
    ) -> SecurityScanResult {
        logger.debug(
            "🔍 Scanning template content",
            metadata: [
                "template_type": .string(templateType.rawValue),
                "file_name": .string(fileName ?? "unknown"),
                "content_length": .stringConvertible(content.count),
            ]
        )

        var findings: [SecurityFinding] = []

        // Scan for XSS vulnerabilities
        findings.append(contentsOf: scanForXSSVulnerabilities(content, templateType: templateType))

        // Scan for code injection patterns
        findings.append(contentsOf: scanForCodeInjection(content, templateType: templateType))

        // Scan for unsafe external references
        findings.append(contentsOf: scanForUnsafeExternalReferences(content))

        // Scan for hardcoded credentials
        findings.append(contentsOf: scanForHardcodedCredentials(content))

        // Template-specific scans
        switch templateType {
        case .html:
            findings.append(contentsOf: scanHTMLSpecificVulnerabilities(content))
        case .css:
            findings.append(contentsOf: scanCSSSpecificVulnerabilities(content))
        case .javascript:
            findings.append(contentsOf: scanJavaScriptSpecificVulnerabilities(content))
        case .json:
            findings.append(contentsOf: scanJSONSpecificVulnerabilities(content))
        case .markdown:
            findings.append(contentsOf: scanMarkdownSpecificVulnerabilities(content))
        case .xml:
            findings.append(contentsOf: scanXMLSpecificVulnerabilities(content))
        case .text:
            // Basic text scanning for credentials and patterns
            break
        case .unknown:
            // Generic content scanning only
            break
        }

        let severityLevel = determineSeverityLevel(findings)

        logger.info(
            "🔒 Template security scan completed",
            metadata: [
                "findings_count": .stringConvertible(findings.count),
                "severity_level": .string(severityLevel.rawValue),
                "file_name": .string(fileName ?? "unknown"),
            ]
        )

        return SecurityScanResult(
            fileName: fileName,
            templateType: templateType,
            findings: findings,
            overallSeverity: severityLevel,
            scanTimestamp: Date()
        )
    }

    /// Validates user input for security threats.
    ///
    /// This method validates various types of user input to prevent security
    /// vulnerabilities such as path traversal, injection attacks, and malicious content.
    ///
    /// - Parameters:
    ///   - input: User input to validate
    ///   - inputType: Type of input being validated
    ///   - context: Optional context for validation
    /// - Returns: Input validation result
    public func validateUserInput(
        _ input: String,
        inputType: InputType,
        context: String? = nil
    ) -> InputValidationResult {
        logger.debug(
            "🔍 Validating user input",
            metadata: [
                "input_type": .string(inputType.rawValue),
                "input_length": .stringConvertible(input.count),
                "context": .string(context ?? "none"),
            ]
        )

        var violations: [SecurityViolation] = []

        // Common validations for all input types
        violations.append(contentsOf: validateInputLength(input, inputType: inputType))
        violations.append(contentsOf: validateCharacterRestrictions(input, inputType: inputType))
        violations.append(contentsOf: validatePathTraversalAttempts(input))
        violations.append(contentsOf: validateInjectionAttempts(input))

        // Input-specific validations
        switch inputType {
        case .projectName:
            violations.append(contentsOf: validateProjectName(input))
        case .templateName:
            violations.append(contentsOf: validateTemplateName(input))
        case .fileName:
            violations.append(contentsOf: validateFileName(input))
        case .directoryPath:
            violations.append(contentsOf: validateDirectoryPath(input))
        case .url:
            violations.append(contentsOf: validateURL(input))
        case .emailAddress:
            violations.append(contentsOf: validateEmailAddress(input))
        case .customContent:
            violations.append(contentsOf: validateCustomContent(input))
        }

        let isValid = violations.isEmpty
        let riskLevel = determineRiskLevel(violations)

        logger.info(
            "🔒 User input validation completed",
            metadata: [
                "is_valid": .stringConvertible(isValid),
                "violations_count": .stringConvertible(violations.count),
                "risk_level": .string(riskLevel.rawValue),
                "input_type": .string(inputType.rawValue),
            ]
        )

        return InputValidationResult(
            input: input,
            inputType: inputType,
            isValid: isValid,
            violations: violations,
            riskLevel: riskLevel,
            validationTimestamp: Date()
        )
    }

    /// Scans an entire project directory for security issues.
    ///
    /// This method performs a comprehensive security scan of all files in a project
    /// directory, checking for various security vulnerabilities and misconfigurations.
    ///
    /// - Parameter projectPath: Path to the project directory
    /// - Returns: Comprehensive project security scan result
    /// - Throws: SecurityScanError if scanning fails
    public func scanProjectDirectory(at projectPath: String) async throws -> ProjectSecurityScanResult {
        logger.info(
            "🔍 Starting comprehensive project security scan",
            metadata: [
                "project_path": .string(projectPath)
            ]
        )

        let projectURL = URL(fileURLWithPath: projectPath)

        // Verify project directory exists
        guard FileManager.default.fileExists(atPath: projectPath) else {
            throw SecurityScanError.directoryNotFound(projectPath)
        }

        var allResults: [SecurityScanResult] = []
        var scanErrors: [SecurityScanError] = []

        // Get all files in the project directory
        let fileURLs = try getProjectFiles(at: projectURL)

        logger.debug(
            "📁 Found files to scan",
            metadata: [
                "file_count": .stringConvertible(fileURLs.count)
            ]
        )

        // Scan each file
        for fileURL in fileURLs {
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                let templateType = TemplateType.fromFileExtension(fileURL.pathExtension)

                let scanResult = scanTemplateContent(
                    content,
                    templateType: templateType,
                    fileName: fileURL.lastPathComponent
                )

                allResults.append(scanResult)

            } catch {
                let scanError = SecurityScanError.fileReadError(fileURL.path, error.localizedDescription)
                scanErrors.append(scanError)

                logger.warning(
                    "⚠️ Failed to scan file",
                    metadata: [
                        "file_path": .string(fileURL.path),
                        "error": .string(error.localizedDescription),
                    ]
                )
            }
        }

        // Analyze overall project security
        let projectFindings = analyzeProjectStructure(at: projectURL)
        let overallSeverity = determineProjectSeverity(allResults, projectFindings: projectFindings)

        logger.info(
            "🔒 Project security scan completed",
            metadata: [
                "scanned_files": .stringConvertible(allResults.count),
                "scan_errors": .stringConvertible(scanErrors.count),
                "overall_severity": .string(overallSeverity.rawValue),
            ]
        )

        return ProjectSecurityScanResult(
            projectPath: projectPath,
            fileResults: allResults,
            projectFindings: projectFindings,
            scanErrors: scanErrors,
            overallSeverity: overallSeverity,
            scanTimestamp: Date()
        )
    }

    // MARK: - Private Security Scanning Methods

    private func scanForXSSVulnerabilities(_ content: String, templateType: TemplateType) -> [SecurityFinding] {
        var findings: [SecurityFinding] = []

        // Common XSS patterns
        let xssPatterns = [
            #"<script[^>]*>.*?</script>"#,
            #"javascript:"#,
            #"on\w+\s*="#,
            #"eval\s*\("#,
            #"document\.write"#,
            #"innerHTML\s*="#,
            #"outerHTML\s*="#,
            #"<iframe[^>]*>"#,
            #"<object[^>]*>"#,
            #"<embed[^>]*>"#,
        ]

        for pattern in xssPatterns {
            if let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            ) {
                let matches = regex.matches(in: content, range: NSRange(location: 0, length: content.count))

                for match in matches {
                    if let range = Range(match.range, in: content) {
                        let matchedContent = String(content[range])

                        findings.append(
                            SecurityFinding(
                                type: .crossSiteScripting,
                                severity: .high,
                                description: "Potential XSS vulnerability detected",
                                location: SecurityLocation(
                                    line: self.lineNumber(in: content, at: match.range.location),
                                    column: self.columnNumber(in: content, at: match.range.location),
                                    length: match.range.length
                                ),
                                evidence: matchedContent,
                                recommendation: "Remove or properly escape dangerous HTML/JavaScript content"
                            )
                        )
                    }
                }
            }
        }

        return findings
    }

    private func scanForCodeInjection(_ content: String, templateType: TemplateType) -> [SecurityFinding] {
        var findings: [SecurityFinding] = []

        // Code injection patterns
        let injectionPatterns = [
            #"\$\{.*?\}"#,  // Template literal injection
            #"<%.*?%>"#,  // Server-side template injection
            #"\{\{.*?\}\}"#,  // Handlebars/Mustache injection
            #"\[\[.*?\]\]"#,  // Angular-style injection
            #"exec\s*\("#,  // Command execution
            #"system\s*\("#,  // System command execution
            #"require\s*\("#,  // Module injection
            #"import\s*\("#,  // Dynamic import injection
        ]

        for pattern in injectionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: content, range: NSRange(location: 0, length: content.count))

                for match in matches {
                    if let range = Range(match.range, in: content) {
                        let matchedContent = String(content[range])

                        findings.append(
                            SecurityFinding(
                                type: .codeInjection,
                                severity: .high,
                                description: "Potential code injection vulnerability detected",
                                location: SecurityLocation(
                                    line: self.lineNumber(in: content, at: match.range.location),
                                    column: self.columnNumber(in: content, at: match.range.location),
                                    length: match.range.length
                                ),
                                evidence: matchedContent,
                                recommendation: "Use proper input validation and escaping for dynamic content"
                            )
                        )
                    }
                }
            }
        }

        return findings
    }

    private func scanForUnsafeExternalReferences(_ content: String) -> [SecurityFinding] {
        var findings: [SecurityFinding] = []

        // Unsafe external reference patterns
        let unsafePatterns = [
            #"http://[^\s\"\']+(?!localhost)"#,  // Unencrypted HTTP (except localhost)
            #"src\s*=\s*[\"\']*javascript:"#,  // JavaScript in src attributes
            #"href\s*=\s*[\"\']*javascript:"#,  // JavaScript in href attributes
            #"src\s*=\s*[\"\']*data:"#,  // Data URLs in src
            #"ftp://[^\s\"\']+""#,  // Unsafe FTP references
        ]

        for pattern in unsafePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: content, range: NSRange(location: 0, length: content.count))

                for match in matches {
                    if let range = Range(match.range, in: content) {
                        let matchedContent = String(content[range])

                        findings.append(
                            SecurityFinding(
                                type: .unsafeExternalReference,
                                severity: .medium,
                                description: "Unsafe external reference detected",
                                location: SecurityLocation(
                                    line: self.lineNumber(in: content, at: match.range.location),
                                    column: self.columnNumber(in: content, at: match.range.location),
                                    length: match.range.length
                                ),
                                evidence: matchedContent,
                                recommendation: "Use HTTPS for external references and avoid inline JavaScript URLs"
                            )
                        )
                    }
                }
            }
        }

        return findings
    }

    private func scanForHardcodedCredentials(_ content: String) -> [SecurityFinding] {
        var findings: [SecurityFinding] = []

        // Credential patterns
        let credentialPatterns = [
            #"password\s*[=:]\s*[\"\']\w+"#,
            #"api[_-]?key\s*[=:]\s*[\"\']\w+"#,
            #"secret[_-]?key\s*[=:]\s*[\"\']\w+"#,
            #"access[_-]?token\s*[=:]\s*[\"\']\w+"#,
            #"auth[_-]?token\s*[=:]\s*[\"\']\w+"#,
            #"private[_-]?key\s*[=:]\s*[\"\']\w+"#,
            #"AKIA[A-Z0-9]{16}"#,  // AWS Access Key
            #"github_pat_[a-zA-Z0-9_]+"#,  // GitHub Personal Access Token
        ]

        for pattern in credentialPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: content, range: NSRange(location: 0, length: content.count))

                for match in matches {
                    if Range(match.range, in: content) != nil {
                        // Redact the actual credential value for evidence
                        let evidence = "***REDACTED***"

                        findings.append(
                            SecurityFinding(
                                type: .hardcodedCredentials,
                                severity: .critical,
                                description: "Hardcoded credentials detected",
                                location: SecurityLocation(
                                    line: self.lineNumber(in: content, at: match.range.location),
                                    column: self.columnNumber(in: content, at: match.range.location),
                                    length: match.range.length
                                ),
                                evidence: evidence,
                                recommendation:
                                    "Remove hardcoded credentials and use environment variables or secure credential storage"
                            )
                        )
                    }
                }
            }
        }

        return findings
    }

    // MARK: - Template-Specific Scanning Methods

    private func scanHTMLSpecificVulnerabilities(_ content: String) -> [SecurityFinding] {
        var findings: [SecurityFinding] = []

        // Check for missing CSP headers
        if !content.contains("Content-Security-Policy") {
            findings.append(
                SecurityFinding(
                    type: .missingSecurityHeaders,
                    severity: .medium,
                    description: "Missing Content Security Policy",
                    location: SecurityLocation(line: 1, column: 1, length: 0),
                    evidence: "No CSP meta tag found",
                    recommendation: "Add Content-Security-Policy meta tag to prevent XSS attacks"
                )
            )
        }

        // Check for unsafe inline styles
        let inlineStylePattern = #"style\s*=\s*[\"\''][^\"\']*[\"\'']"#
        if let regex = try? NSRegularExpression(pattern: inlineStylePattern) {
            let matches = regex.matches(in: content, range: NSRange(location: 0, length: content.count))

            for match in matches {
                if let range = Range(match.range, in: content) {
                    let matchedContent = String(content[range])

                    findings.append(
                        SecurityFinding(
                            type: .unsafeInlineStyles,
                            severity: .low,
                            description: "Inline styles detected",
                            location: SecurityLocation(
                                line: self.lineNumber(in: content, at: match.range.location),
                                column: self.columnNumber(in: content, at: match.range.location),
                                length: match.range.length
                            ),
                            evidence: matchedContent,
                            recommendation: "Move inline styles to external CSS files for better CSP compliance"
                        )
                    )
                }
            }
        }

        return findings
    }

    private func scanCSSSpecificVulnerabilities(_ content: String) -> [SecurityFinding] {
        var findings: [SecurityFinding] = []

        // Check for CSS injection patterns
        let cssInjectionPatterns = [
            #"expression\s*\("#,
            #"javascript\s*:"#,
            #"@import\s+url\s*\(\s*[\"\']*javascript:"#,
            #"behavior\s*:"#,
        ]

        for pattern in cssInjectionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: content, range: NSRange(location: 0, length: content.count))

                for match in matches {
                    if let range = Range(match.range, in: content) {
                        let matchedContent = String(content[range])

                        findings.append(
                            SecurityFinding(
                                type: .cssInjection,
                                severity: .medium,
                                description: "Potential CSS injection vulnerability",
                                location: SecurityLocation(
                                    line: self.lineNumber(in: content, at: match.range.location),
                                    column: self.columnNumber(in: content, at: match.range.location),
                                    length: match.range.length
                                ),
                                evidence: matchedContent,
                                recommendation: "Remove dangerous CSS expressions and JavaScript URLs"
                            )
                        )
                    }
                }
            }
        }

        return findings
    }

    private func scanJavaScriptSpecificVulnerabilities(_ content: String) -> [SecurityFinding] {
        var findings: [SecurityFinding] = []

        // Check for dangerous JavaScript patterns
        let dangerousJSPatterns = [
            #"eval\s*\("#,
            #"Function\s*\("#,
            #"setTimeout\s*\(\s*[\"\''][^\"\']*[\"\'']"#,
            #"setInterval\s*\(\s*[\"\''][^\"\']*[\"\'']"#,
            #"document\.write"#,
            #"localStorage\.setItem"#,
            #"sessionStorage\.setItem"#,
        ]

        for pattern in dangerousJSPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: content, range: NSRange(location: 0, length: content.count))

                for match in matches {
                    if let range = Range(match.range, in: content) {
                        let matchedContent = String(content[range])

                        findings.append(
                            SecurityFinding(
                                type: .dangerousJavaScript,
                                severity: .high,
                                description: "Dangerous JavaScript pattern detected",
                                location: SecurityLocation(
                                    line: self.lineNumber(in: content, at: match.range.location),
                                    column: self.columnNumber(in: content, at: match.range.location),
                                    length: match.range.length
                                ),
                                evidence: matchedContent,
                                recommendation: "Avoid using eval(), Function(), and string-based timers"
                            )
                        )
                    }
                }
            }
        }

        return findings
    }

    private func scanJSONSpecificVulnerabilities(_ content: String) -> [SecurityFinding] {
        var findings: [SecurityFinding] = []

        // Validate JSON structure
        do {
            _ = try JSONSerialization.jsonObject(with: content.data(using: .utf8) ?? Data())
        } catch {
            findings.append(
                SecurityFinding(
                    type: .malformedContent,
                    severity: .medium,
                    description: "Malformed JSON content",
                    location: SecurityLocation(line: 1, column: 1, length: content.count),
                    evidence: error.localizedDescription,
                    recommendation: "Ensure JSON content is properly formatted"
                )
            )
        }

        return findings
    }

    private func scanXMLSpecificVulnerabilities(_ content: String) -> [SecurityFinding] {
        var findings: [SecurityFinding] = []

        // Check for XML external entity (XXE) vulnerabilities
        let xxePatterns = [
            #"<!ENTITY[^>]*>"#,  // Entity declarations
            #"<!DOCTYPE[^>]*ENTITY[^>]*>"#,  // DOCTYPE with entities
            #"SYSTEM\s+[\"'][^\"']*[\"']"#,  // System references
        ]

        for pattern in xxePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: content, range: NSRange(location: 0, length: content.count))

                for match in matches {
                    let matchText = String(content[Range(match.range, in: content)!])

                    findings.append(
                        SecurityFinding(
                            type: .codeInjection,
                            severity: .high,
                            description: "Potential XML External Entity (XXE) vulnerability",
                            location: SecurityLocation(
                                line: self.lineNumber(in: content, at: match.range.location),
                                column: self.columnNumber(in: content, at: match.range.location),
                                length: match.range.length
                            ),
                            evidence: matchText,
                            recommendation: "Remove or sanitize external entity references in XML"
                        )
                    )
                }
            }
        }

        return findings
    }

    private func scanMarkdownSpecificVulnerabilities(_ content: String) -> [SecurityFinding] {
        var findings: [SecurityFinding] = []

        // Check for embedded HTML/JavaScript in Markdown
        let htmlPatterns = [
            #"<script[^>]*>.*?</script>"#,
            #"<iframe[^>]*>"#,
            #"<object[^>]*>"#,
            #"javascript:"#,
        ]

        for pattern in htmlPatterns {
            if let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            ) {
                let matches = regex.matches(in: content, range: NSRange(location: 0, length: content.count))

                for match in matches {
                    if let range = Range(match.range, in: content) {
                        let matchedContent = String(content[range])

                        findings.append(
                            SecurityFinding(
                                type: .unsafeMarkdownContent,
                                severity: .medium,
                                description: "Potentially unsafe HTML in Markdown",
                                location: SecurityLocation(
                                    line: self.lineNumber(in: content, at: match.range.location),
                                    column: self.columnNumber(in: content, at: match.range.location),
                                    length: match.range.length
                                ),
                                evidence: matchedContent,
                                recommendation: "Sanitize or remove embedded HTML/JavaScript in Markdown content"
                            )
                        )
                    }
                }
            }
        }

        return findings
    }

    // MARK: - Input Validation Methods

    private func validateInputLength(_ input: String, inputType: InputType) -> [SecurityViolation] {
        let maxLength = configuration.maxInputLength(for: inputType)

        guard input.count <= maxLength else {
            return [
                SecurityViolation(
                    type: .inputTooLong,
                    severity: .medium,
                    description: "Input exceeds maximum allowed length",
                    violatingInput: String(input.prefix(100)) + (input.count > 100 ? "..." : ""),
                    expectedFormat: "Maximum \(maxLength) characters",
                    recommendation: "Reduce input length to \(maxLength) characters or less"
                )
            ]
        }

        return []
    }

    private func validateCharacterRestrictions(_ input: String, inputType: InputType) -> [SecurityViolation] {
        let allowedCharacters = configuration.allowedCharacters(for: inputType)
        let disallowedCharacters = CharacterSet(charactersIn: input).subtracting(allowedCharacters)

        guard disallowedCharacters.isEmpty else {
            return [
                SecurityViolation(
                    type: .invalidCharacters,
                    severity: .medium,
                    description: "Input contains disallowed characters",
                    violatingInput: input,
                    expectedFormat: "Only letters, numbers, and safe punctuation",
                    recommendation: "Remove special characters and use only alphanumeric characters"
                )
            ]
        }

        return []
    }

    private func validatePathTraversalAttempts(_ input: String) -> [SecurityViolation] {
        let pathTraversalPatterns = [
            "../",
            "..\\",
            "%2e%2e%2f",
            "%2e%2e\\",
            "..%2f",
            "..%5c",
        ]

        let lowercaseInput = input.lowercased()

        for pattern in pathTraversalPatterns {
            if lowercaseInput.contains(pattern) {
                return [
                    SecurityViolation(
                        type: .pathTraversal,
                        severity: .high,
                        description: "Path traversal attempt detected",
                        violatingInput: input,
                        expectedFormat: "Simple file/directory names without path traversal",
                        recommendation: "Remove path traversal sequences (../) from input"
                    )
                ]
            }
        }

        return []
    }

    private func validateInjectionAttempts(_ input: String) -> [SecurityViolation] {
        let injectionPatterns = [
            "<script",
            "javascript:",
            "eval(",
            "exec(",
            "${",
            "<%",
            "{{",
            "[[",
            "'; DROP",
            "\" OR 1=1",
        ]

        let lowercaseInput = input.lowercased()

        for pattern in injectionPatterns {
            if lowercaseInput.contains(pattern.lowercased()) {
                return [
                    SecurityViolation(
                        type: .injectionAttempt,
                        severity: .high,
                        description: "Code injection attempt detected",
                        violatingInput: input,
                        expectedFormat: "Plain text without code injection patterns",
                        recommendation: "Remove code injection patterns from input"
                    )
                ]
            }
        }

        return []
    }

    private func validateProjectName(_ input: String) -> [SecurityViolation] {
        // Project name should be alphanumeric with hyphens and underscores
        let validPattern = "^[a-zA-Z0-9][a-zA-Z0-9_-]*[a-zA-Z0-9]$"

        guard let regex = try? NSRegularExpression(pattern: validPattern),
            regex.firstMatch(in: input, range: NSRange(location: 0, length: input.count)) != nil
        else {
            return [
                SecurityViolation(
                    type: .invalidFormat,
                    severity: .medium,
                    description: "Invalid project name format",
                    violatingInput: input,
                    expectedFormat: "Alphanumeric characters, hyphens, and underscores only",
                    recommendation: "Use only letters, numbers, hyphens, and underscores"
                )
            ]
        }

        return []
    }

    private func validateTemplateName(_ input: String) -> [SecurityViolation] {
        // Template name should be simple alphanumeric
        let validPattern = "^[a-zA-Z][a-zA-Z0-9_-]*$"

        guard let regex = try? NSRegularExpression(pattern: validPattern),
            regex.firstMatch(in: input, range: NSRange(location: 0, length: input.count)) != nil
        else {
            return [
                SecurityViolation(
                    type: .invalidFormat,
                    severity: .medium,
                    description: "Invalid template name format",
                    violatingInput: input,
                    expectedFormat: "Alphanumeric characters starting with a letter",
                    recommendation:
                        "Use template names starting with a letter and containing only letters, numbers, hyphens, and underscores"
                )
            ]
        }

        return []
    }

    private func validateFileName(_ input: String) -> [SecurityViolation] {
        // File name validation
        let invalidFileNamePatterns = [
            "^\\.",  // Hidden files
            "\\.$",  // Files ending with dot
            "[\\/\\\\]",  // Path separators
            "[<>:\"|?*]",  // Windows invalid characters
        ]

        for pattern in invalidFileNamePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
                regex.firstMatch(in: input, range: NSRange(location: 0, length: input.count)) != nil
            {
                return [
                    SecurityViolation(
                        type: .invalidFormat,
                        severity: .medium,
                        description: "Invalid file name format",
                        violatingInput: input,
                        expectedFormat: "Valid file name without path separators or special characters",
                        recommendation: "Use simple file names without special characters"
                    )
                ]
            }
        }

        return []
    }

    private func validateDirectoryPath(_ input: String) -> [SecurityViolation] {
        // Directory path should not contain dangerous patterns
        var violations: [SecurityViolation] = []

        // Check for absolute paths (which might be dangerous)
        if input.hasPrefix("/") || input.contains(":\\") {
            violations.append(
                SecurityViolation(
                    type: .absolutePath,
                    severity: .medium,
                    description: "Absolute path detected",
                    violatingInput: input,
                    expectedFormat: "Relative paths only",
                    recommendation: "Use relative paths instead of absolute paths"
                )
            )
        }

        return violations
    }

    private func validateURL(_ input: String) -> [SecurityViolation] {
        // URL validation
        guard let url = URL(string: input) else {
            return [
                SecurityViolation(
                    type: .invalidFormat,
                    severity: .medium,
                    description: "Malformed URL",
                    violatingInput: input,
                    expectedFormat: "Valid URL format",
                    recommendation: "Provide a valid URL"
                )
            ]
        }

        var violations: [SecurityViolation] = []

        // Check for secure schemes
        if let scheme = url.scheme?.lowercased() {
            if scheme == "http" && url.host != "localhost" && !url.host!.hasPrefix("127.") {
                violations.append(
                    SecurityViolation(
                        type: .unsecureProtocol,
                        severity: .medium,
                        description: "Unsecure HTTP protocol for external URL",
                        violatingInput: input,
                        expectedFormat: "HTTPS URLs for external resources",
                        recommendation: "Use HTTPS instead of HTTP for external URLs"
                    )
                )
            }

            if ["javascript", "data", "vbscript"].contains(scheme) {
                violations.append(
                    SecurityViolation(
                        type: .dangerousProtocol,
                        severity: .high,
                        description: "Dangerous URL scheme detected",
                        violatingInput: input,
                        expectedFormat: "HTTP or HTTPS URLs only",
                        recommendation: "Use only HTTP or HTTPS URLs"
                    )
                )
            }
        }

        return violations
    }

    private func validateEmailAddress(_ input: String) -> [SecurityViolation] {
        // Basic email validation
        let emailPattern = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"

        guard let regex = try? NSRegularExpression(pattern: emailPattern),
            regex.firstMatch(in: input, range: NSRange(location: 0, length: input.count)) != nil
        else {
            return [
                SecurityViolation(
                    type: .invalidFormat,
                    severity: .low,
                    description: "Invalid email address format",
                    violatingInput: input,
                    expectedFormat: "Valid email address (user@domain.com)",
                    recommendation: "Provide a valid email address"
                )
            ]
        }

        return []
    }

    private func validateCustomContent(_ input: String) -> [SecurityViolation] {
        // Custom content validation - more permissive but still secure
        var violations: [SecurityViolation] = []

        // Check for script tags
        if input.lowercased().contains("<script") {
            violations.append(
                SecurityViolation(
                    type: .dangerousContent,
                    severity: .high,
                    description: "Script tags detected in content",
                    violatingInput: input,
                    expectedFormat: "Plain text without script tags",
                    recommendation: "Remove script tags from content"
                )
            )
        }

        return violations
    }

    // MARK: - Helper Methods

    private func getLineNumber(for location: Int, in content: String) -> Int {
        let beforeLocation = String(content.prefix(location))
        return beforeLocation.components(separatedBy: .newlines).count
    }

    private func getColumnNumber(for location: Int, in content: String) -> Int {
        let beforeLocation = String(content.prefix(location))
        if let lastNewline = beforeLocation.lastIndex(of: "\n") {
            return beforeLocation.distance(from: lastNewline, to: beforeLocation.endIndex)
        } else {
            return location + 1
        }
    }

    private func determineSeverityLevel(_ findings: [SecurityFinding]) -> SecuritySeverity {
        if findings.contains(where: { $0.severity == .critical }) {
            return .critical
        } else if findings.contains(where: { $0.severity == .high }) {
            return .high
        } else if findings.contains(where: { $0.severity == .medium }) {
            return .medium
        } else if !findings.isEmpty {
            return .low
        } else {
            return .none
        }
    }

    private func determineRiskLevel(_ violations: [SecurityViolation]) -> SecurityRisk {
        if violations.contains(where: { $0.severity == .critical }) {
            return .critical
        } else if violations.contains(where: { $0.severity == .high }) {
            return .high
        } else if violations.contains(where: { $0.severity == .medium }) {
            return .medium
        } else if !violations.isEmpty {
            return .low
        } else {
            return .none
        }
    }

    private func getProjectFiles(at projectURL: URL) throws -> [URL] {
        let fileManager = FileManager.default
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey]

        guard
            let enumerator = fileManager.enumerator(
                at: projectURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: nil
            )
        else {
            throw SecurityScanError.enumerationFailed(projectURL.path)
        }

        var fileURLs: [URL] = []

        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                if resourceValues.isRegularFile == true {
                    fileURLs.append(fileURL)
                }
            } catch {
                logger.warning(
                    "⚠️ Failed to get resource values",
                    metadata: [
                        "file_url": .string(fileURL.path),
                        "error": .string(error.localizedDescription),
                    ]
                )
            }
        }

        return fileURLs
    }

    private func analyzeProjectStructure(at projectURL: URL) -> [SecurityFinding] {
        var findings: [SecurityFinding] = []

        // Check for common security misconfigurations
        let potentiallyDangerousFiles = [
            ".env",
            ".env.local",
            ".env.production",
            "config.json",
            "secrets.json",
            "private.key",
            "id_rsa",
        ]

        for dangerousFile in potentiallyDangerousFiles {
            let fileURL = projectURL.appendingPathComponent(dangerousFile)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                findings.append(
                    SecurityFinding(
                        type: .sensitiveFileExposed,
                        severity: .high,
                        description: "Potentially sensitive file found",
                        location: SecurityLocation(line: 0, column: 0, length: 0),
                        evidence: dangerousFile,
                        recommendation: "Remove or secure sensitive configuration files"
                    )
                )
            }
        }

        return findings
    }

    private func determineProjectSeverity(
        _ fileResults: [SecurityScanResult],
        projectFindings: [SecurityFinding]
    ) -> SecuritySeverity {
        let allFindings = fileResults.flatMap { $0.findings } + projectFindings
        return determineSeverityLevel(allFindings)
    }

    /// Helper method to calculate line number for a given string position
    private func lineNumber(in content: String, at position: Int) -> Int {
        let substring = String(content.prefix(position))
        return substring.components(separatedBy: .newlines).count
    }

    /// Helper method to calculate column number for a given string position
    private func columnNumber(in content: String, at position: Int) -> Int {
        let substring = String(content.prefix(position))
        if let lastNewlineIndex = substring.lastIndex(of: "\n") {
            return substring.distance(from: lastNewlineIndex, to: substring.endIndex) - 1
        }
        return position + 1
    }
}
