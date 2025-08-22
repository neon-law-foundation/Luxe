import Foundation

// MARK: - Core Security Types

/// Security severity levels for findings and violations.
public enum SecuritySeverity: String, Codable, CaseIterable, Sendable {
    case none = "none"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    public var emoji: String {
        switch self {
        case .none: return "✅"
        case .low: return "🟡"
        case .medium: return "🟠"
        case .high: return "🔴"
        case .critical: return "🚨"
        }
    }

    public var priority: Int {
        switch self {
        case .none: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

/// Security risk levels for input validation.
public enum SecurityRisk: String, Codable, CaseIterable, Sendable {
    case none = "none"
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"

    public var emoji: String {
        switch self {
        case .none: return "✅"
        case .low: return "⚠️"
        case .medium: return "🔸"
        case .high: return "🔺"
        case .critical: return "🛑"
        }
    }
}

/// Template types for security scanning.
public enum TemplateType: String, Codable, CaseIterable, Sendable {
    case html = "html"
    case css = "css"
    case javascript = "javascript"
    case json = "json"
    case markdown = "markdown"
    case xml = "xml"
    case text = "text"
    case unknown = "unknown"

    /// Determines template type from file extension.
    public static func fromFileExtension(_ extension: String) -> TemplateType {
        switch `extension`.lowercased() {
        case "html", "htm":
            return .html
        case "css":
            return .css
        case "js", "mjs", "ts":
            return .javascript
        case "json":
            return .json
        case "md", "markdown":
            return .markdown
        case "xml", "xhtml":
            return .xml
        case "txt":
            return .text
        default:
            return .unknown
        }
    }
}

/// Input types for validation.
public enum InputType: String, Codable, CaseIterable, Sendable {
    case projectName = "project_name"
    case templateName = "template_name"
    case fileName = "file_name"
    case directoryPath = "directory_path"
    case url = "url"
    case emailAddress = "email_address"
    case customContent = "custom_content"
}

/// Security finding types.
public enum SecurityFindingType: String, Codable, CaseIterable, Sendable {
    case crossSiteScripting = "xss"
    case codeInjection = "code_injection"
    case unsafeExternalReference = "unsafe_external_reference"
    case hardcodedCredentials = "hardcoded_credentials"
    case missingSecurityHeaders = "missing_security_headers"
    case unsafeInlineStyles = "unsafe_inline_styles"
    case cssInjection = "css_injection"
    case dangerousJavaScript = "dangerous_javascript"
    case malformedContent = "malformed_content"
    case unsafeMarkdownContent = "unsafe_markdown_content"
    case sensitiveFileExposed = "sensitive_file_exposed"
}

/// Security violation types.
public enum SecurityViolationType: String, Codable, CaseIterable, Sendable {
    case inputTooLong = "input_too_long"
    case invalidCharacters = "invalid_characters"
    case pathTraversal = "path_traversal"
    case injectionAttempt = "injection_attempt"
    case invalidFormat = "invalid_format"
    case absolutePath = "absolute_path"
    case unsecureProtocol = "unsecure_protocol"
    case dangerousProtocol = "dangerous_protocol"
    case dangerousContent = "dangerous_content"
}

// MARK: - Security Finding Structures

/// Represents a security finding in template content.
public struct SecurityFinding: Codable, Sendable {
    public let type: SecurityFindingType
    public let severity: SecuritySeverity
    public let description: String
    public let location: SecurityLocation
    public let evidence: String
    public let recommendation: String

    public init(
        type: SecurityFindingType,
        severity: SecuritySeverity,
        description: String,
        location: SecurityLocation,
        evidence: String,
        recommendation: String
    ) {
        self.type = type
        self.severity = severity
        self.description = description
        self.location = location
        self.evidence = evidence
        self.recommendation = recommendation
    }
}

/// Location information for security findings.
public struct SecurityLocation: Codable, Sendable {
    public let line: Int
    public let column: Int
    public let length: Int

    public init(line: Int, column: Int, length: Int) {
        self.line = line
        self.column = column
        self.length = length
    }
}

/// Represents a security violation in user input.
public struct SecurityViolation: Codable, Sendable {
    public let type: SecurityViolationType
    public let severity: SecuritySeverity
    public let description: String
    public let violatingInput: String
    public let expectedFormat: String
    public let recommendation: String

    public init(
        type: SecurityViolationType,
        severity: SecuritySeverity,
        description: String,
        violatingInput: String,
        expectedFormat: String,
        recommendation: String
    ) {
        self.type = type
        self.severity = severity
        self.description = description
        self.violatingInput = violatingInput
        self.expectedFormat = expectedFormat
        self.recommendation = recommendation
    }
}

// MARK: - Scan Result Structures

/// Result of scanning template content for security issues.
public struct SecurityScanResult: Codable, Sendable {
    public let fileName: String?
    public let templateType: TemplateType
    public let findings: [SecurityFinding]
    public let overallSeverity: SecuritySeverity
    public let scanTimestamp: Date

    public init(
        fileName: String?,
        templateType: TemplateType,
        findings: [SecurityFinding],
        overallSeverity: SecuritySeverity,
        scanTimestamp: Date
    ) {
        self.fileName = fileName
        self.templateType = templateType
        self.findings = findings
        self.overallSeverity = overallSeverity
        self.scanTimestamp = scanTimestamp
    }

    /// Whether the scan found any security issues.
    public var hasIssues: Bool {
        !findings.isEmpty
    }

    /// Count of findings by severity level.
    public var findingsBySeverity: [SecuritySeverity: Int] {
        var counts: [SecuritySeverity: Int] = [:]
        for finding in findings {
            counts[finding.severity, default: 0] += 1
        }
        return counts
    }
}

/// Result of validating user input.
public struct InputValidationResult: Codable, Sendable {
    public let input: String
    public let inputType: InputType
    public let isValid: Bool
    public let violations: [SecurityViolation]
    public let riskLevel: SecurityRisk
    public let validationTimestamp: Date

    public init(
        input: String,
        inputType: InputType,
        isValid: Bool,
        violations: [SecurityViolation],
        riskLevel: SecurityRisk,
        validationTimestamp: Date
    ) {
        self.input = input
        self.inputType = inputType
        self.isValid = isValid
        self.violations = violations
        self.riskLevel = riskLevel
        self.validationTimestamp = validationTimestamp
    }

    /// Count of violations by severity level.
    public var violationsBySeverity: [SecuritySeverity: Int] {
        var counts: [SecuritySeverity: Int] = [:]
        for violation in violations {
            counts[violation.severity, default: 0] += 1
        }
        return counts
    }
}

/// Result of scanning an entire project directory.
public struct ProjectSecurityScanResult: Codable, Sendable {
    public let projectPath: String
    public let fileResults: [SecurityScanResult]
    public let projectFindings: [SecurityFinding]
    public let scanErrors: [SecurityScanError]
    public let overallSeverity: SecuritySeverity
    public let scanTimestamp: Date

    public init(
        projectPath: String,
        fileResults: [SecurityScanResult],
        projectFindings: [SecurityFinding],
        scanErrors: [SecurityScanError],
        overallSeverity: SecuritySeverity,
        scanTimestamp: Date
    ) {
        self.projectPath = projectPath
        self.fileResults = fileResults
        self.projectFindings = projectFindings
        self.scanErrors = scanErrors
        self.overallSeverity = overallSeverity
        self.scanTimestamp = scanTimestamp
    }

    /// Total number of files scanned.
    public var totalFilesScanned: Int {
        fileResults.count
    }

    /// Total number of security findings across all files.
    public var totalFindings: Int {
        fileResults.reduce(0) { $0 + $1.findings.count } + projectFindings.count
    }

    /// Whether the project scan found any security issues.
    public var hasIssues: Bool {
        totalFindings > 0
    }

    /// All security findings from files and project-level scans.
    public var allFindings: [SecurityFinding] {
        fileResults.flatMap { $0.findings } + projectFindings
    }

    /// Count of all findings by severity level.
    public var findingsBySeverity: [SecuritySeverity: Int] {
        var counts: [SecuritySeverity: Int] = [:]
        for finding in allFindings {
            counts[finding.severity, default: 0] += 1
        }
        return counts
    }
}

// MARK: - Security Configuration

/// Configuration for security scanning behavior.
public struct SecurityConfiguration: Sendable {
    public let maxInputLengths: [InputType: Int]
    public let allowedCharacterSets: [InputType: CharacterSet]
    public let enableStrictMode: Bool
    public let customRules: [String: String]

    public init(
        maxInputLengths: [InputType: Int] = [:],
        allowedCharacterSets: [InputType: CharacterSet] = [:],
        enableStrictMode: Bool = true,
        customRules: [String: String] = [:]
    ) {
        self.maxInputLengths = maxInputLengths
        self.allowedCharacterSets = allowedCharacterSets
        self.enableStrictMode = enableStrictMode
        self.customRules = customRules
    }

    /// Default security configuration with reasonable defaults.
    public static let `default` = SecurityConfiguration(
        maxInputLengths: [
            .projectName: 100,
            .templateName: 50,
            .fileName: 255,
            .directoryPath: 1000,
            .url: 2000,
            .emailAddress: 254,
            .customContent: 10000,
        ],
        allowedCharacterSets: [
            .projectName: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_")),
            .templateName: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_")),
            .fileName: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.")),
            .directoryPath: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_/.")),
            .url: CharacterSet.urlPathAllowed,
            .emailAddress: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "@.-_+")),
            .customContent: CharacterSet.alphanumerics.union(CharacterSet.punctuationCharacters).union(
                CharacterSet.whitespaces
            ),
        ],
        enableStrictMode: true
    )

    /// Strict security configuration for high-security environments.
    public static let strict = SecurityConfiguration(
        maxInputLengths: [
            .projectName: 50,
            .templateName: 30,
            .fileName: 100,
            .directoryPath: 500,
            .url: 1000,
            .emailAddress: 100,
            .customContent: 5000,
        ],
        allowedCharacterSets: [
            .projectName: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")),
            .templateName: CharacterSet.alphanumerics,
            .fileName: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.")),
            .directoryPath: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_/")),
            .url: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_/:?")),
            .emailAddress: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "@.-")),
            .customContent: CharacterSet.alphanumerics.union(CharacterSet.whitespaces).union(
                CharacterSet(charactersIn: ".,!?-")
            ),
        ],
        enableStrictMode: true
    )

    /// Gets the maximum input length for a given input type.
    public func maxInputLength(for inputType: InputType) -> Int {
        maxInputLengths[inputType] ?? 1000
    }

    /// Gets the allowed character set for a given input type.
    public func allowedCharacters(for inputType: InputType) -> CharacterSet {
        allowedCharacterSets[inputType] ?? CharacterSet.alphanumerics
    }
}

// MARK: - Security Errors

/// Errors that can occur during security scanning.
public enum SecurityScanError: Error, LocalizedError, Codable, Sendable {
    case directoryNotFound(String)
    case fileReadError(String, String)
    case enumerationFailed(String)
    case configurationError(String)
    case scanTimeout(String)

    public var errorDescription: String? {
        switch self {
        case .directoryNotFound(let path):
            return "Directory not found: \(path)"
        case .fileReadError(let path, let errorDescription):
            return "Failed to read file at \(path): \(errorDescription)"
        case .enumerationFailed(let path):
            return "Failed to enumerate files in directory: \(path)"
        case .configurationError(let message):
            return "Security configuration error: \(message)"
        case .scanTimeout(let details):
            return "Security scan timed out: \(details)"
        }
    }
}

// MARK: - Security Report Generation

/// Generates human-readable security reports.
public struct SecurityReportGenerator {

    /// Generates a summary report for a security scan result.
    public static func generateSummaryReport(for result: SecurityScanResult) -> String {
        var report = "# Security Scan Report\n\n"

        report += "**File:** \(result.fileName ?? "Unknown")\n"
        report += "**Template Type:** \(result.templateType.rawValue)\n"
        report +=
            "**Overall Severity:** \(result.overallSeverity.emoji) \(result.overallSeverity.rawValue.capitalized)\n"
        report += "**Scan Date:** \(DateFormatter.securityReport.string(from: result.scanTimestamp))\n\n"

        if result.findings.isEmpty {
            report += "✅ **No security issues found.**\n"
        } else {
            report += "## Security Findings (\(result.findings.count))\n\n"

            let findingsBySeverity = result.findingsBySeverity
            for severity in SecuritySeverity.allCases.reversed() {
                if let count = findingsBySeverity[severity], count > 0 {
                    report += "- \(severity.emoji) **\(severity.rawValue.capitalized):** \(count)\n"
                }
            }

            report += "\n### Detailed Findings\n\n"

            for (index, finding) in result.findings.enumerated() {
                report += "#### \(index + 1). \(finding.description)\n"
                report += "**Severity:** \(finding.severity.emoji) \(finding.severity.rawValue.capitalized)\n"
                report += "**Type:** \(finding.type.rawValue)\n"
                report += "**Location:** Line \(finding.location.line), Column \(finding.location.column)\n"
                report += "**Evidence:** `\(finding.evidence)`\n"
                report += "**Recommendation:** \(finding.recommendation)\n\n"
            }
        }

        return report
    }

    /// Generates a summary report for an input validation result.
    public static func generateValidationReport(for result: InputValidationResult) -> String {
        var report = "# Input Validation Report\n\n"

        report += "**Input Type:** \(result.inputType.rawValue)\n"
        report += "**Valid:** \(result.isValid ? "✅ Yes" : "❌ No")\n"
        report += "**Risk Level:** \(result.riskLevel.emoji) \(result.riskLevel.rawValue.capitalized)\n"
        report += "**Validation Date:** \(DateFormatter.securityReport.string(from: result.validationTimestamp))\n\n"

        if result.violations.isEmpty {
            report += "✅ **Input passed all validation checks.**\n"
        } else {
            report += "## Validation Violations (\(result.violations.count))\n\n"

            for (index, violation) in result.violations.enumerated() {
                report += "#### \(index + 1). \(violation.description)\n"
                report += "**Severity:** \(violation.severity.emoji) \(violation.severity.rawValue.capitalized)\n"
                report += "**Type:** \(violation.type.rawValue)\n"
                report += "**Expected Format:** \(violation.expectedFormat)\n"
                report += "**Recommendation:** \(violation.recommendation)\n\n"
            }
        }

        return report
    }

    /// Generates a comprehensive report for a project security scan.
    public static func generateProjectReport(for result: ProjectSecurityScanResult) -> String {
        var report = "# Project Security Scan Report\n\n"

        report += "**Project Path:** \(result.projectPath)\n"
        report += "**Files Scanned:** \(result.totalFilesScanned)\n"
        report += "**Total Findings:** \(result.totalFindings)\n"
        report +=
            "**Overall Severity:** \(result.overallSeverity.emoji) \(result.overallSeverity.rawValue.capitalized)\n"
        report += "**Scan Date:** \(DateFormatter.securityReport.string(from: result.scanTimestamp))\n\n"

        if result.hasIssues {
            report += "## Summary by Severity\n\n"
            let findingsBySeverity = result.findingsBySeverity
            for severity in SecuritySeverity.allCases.reversed() {
                if let count = findingsBySeverity[severity], count > 0 {
                    report += "- \(severity.emoji) **\(severity.rawValue.capitalized):** \(count)\n"
                }
            }
            report += "\n"
        }

        if !result.scanErrors.isEmpty {
            report += "## Scan Errors (\(result.scanErrors.count))\n\n"
            for error in result.scanErrors {
                report += "- ❌ \(error.localizedDescription)\n"
            }
            report += "\n"
        }

        if result.hasIssues {
            report += "## File-Specific Issues\n\n"
            for fileResult in result.fileResults.filter({ $0.hasIssues }) {
                report += "### \(fileResult.fileName ?? "Unknown File")\n"
                report += "**Template Type:** \(fileResult.templateType.rawValue)\n"
                report += "**Findings:** \(fileResult.findings.count)\n"
                report +=
                    "**Severity:** \(fileResult.overallSeverity.emoji) \(fileResult.overallSeverity.rawValue.capitalized)\n\n"

                for finding in fileResult.findings {
                    report += "- \(finding.severity.emoji) **\(finding.description)** (Line \(finding.location.line))\n"
                }
                report += "\n"
            }

            if !result.projectFindings.isEmpty {
                report += "## Project-Level Issues\n\n"
                for finding in result.projectFindings {
                    report += "- \(finding.severity.emoji) **\(finding.description):** \(finding.evidence)\n"
                }
                report += "\n"
            }
        } else {
            report += "✅ **No security issues found in the project.**\n"
        }

        return report
    }
}

// MARK: - Date Formatter Extension

extension DateFormatter {
    static let securityReport: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
