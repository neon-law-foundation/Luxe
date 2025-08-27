import Foundation
import Stencil
import Yams

/// Processes Standards documents with Stencil templating
final class TemplateProcessor {
    private let templateService: StencilTemplateService

    init(templateService: StencilTemplateService? = nil) {
        self.templateService = templateService ?? StandardsTemplateService()
    }

    /// Process a Standards document with YAML frontmatter and Stencil templating
    /// - Parameters:
    ///   - content: The full document content including YAML frontmatter and markdown body
    ///   - additionalContext: Additional context values to merge with YAML data
    /// - Returns: ProcessedDocument with rendered content
    /// - Throws: TemplateProcessingError if processing fails
    func processDocument(_ content: String, additionalContext: [String: Any] = [:]) throws -> ProcessedDocument {
        // Extract YAML frontmatter and markdown content
        let (frontmatter, markdownContent) = try extractFrontmatterAndContent(from: content)

        // Parse YAML frontmatter
        let yamlData = try parseYAML(frontmatter)

        // Merge YAML data with additional context
        var context = yamlData
        for (key, value) in additionalContext {
            context[key] = value
        }

        // Add standard context values
        context["current_date"] = Date()
        context["current_year"] = Calendar.current.component(.year, from: Date())

        // Validate and render template
        let validationResult = try templateService.validateContext(markdownContent, context: context)

        guard validationResult.isValid else {
            throw TemplateProcessingError.validationFailed(validationResult)
        }

        let renderedContent = try templateService.render(markdownContent, context: context)

        return ProcessedDocument(
            frontmatter: yamlData,
            originalContent: markdownContent,
            renderedContent: renderedContent,
            context: context
        )
    }

    /// Extract YAML frontmatter and markdown content from a document
    private func extractFrontmatterAndContent(from document: String) throws -> (frontmatter: String, content: String) {
        let lines = document.components(separatedBy: .newlines)

        guard lines.count > 2,
            lines[0] == "---"
        else {
            throw TemplateProcessingError.noFrontmatter
        }

        // Find the closing frontmatter delimiter
        var endIndex = 1
        while endIndex < lines.count && lines[endIndex] != "---" {
            endIndex += 1
        }

        guard endIndex < lines.count else {
            throw TemplateProcessingError.unclosedFrontmatter
        }

        let frontmatter = lines[1..<endIndex].joined(separator: "\n")
        let content = lines[(endIndex + 1)...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        return (frontmatter, content)
    }

    /// Parse YAML string into dictionary
    private func parseYAML(_ yamlString: String) throws -> [String: Any] {
        do {
            let decoded = try Yams.load(yaml: yamlString)
            guard let dictionary = decoded as? [String: Any] else {
                throw TemplateProcessingError.invalidYAML("YAML must be a dictionary")
            }
            return dictionary
        } catch {
            throw TemplateProcessingError.yamlParsingFailed(error.localizedDescription)
        }
    }

    /// Process questionnaire responses and merge with template context
    func processWithQuestionnaire(
        _ content: String,
        responses: [String: Any]
    ) throws -> ProcessedDocument {
        // Process document with questionnaire responses as additional context
        try processDocument(content, additionalContext: responses)
    }
}

/// Result of processing a Standards document
struct ProcessedDocument {
    let frontmatter: [String: Any]
    let originalContent: String
    let renderedContent: String
    let context: [String: Any]

    /// Get the complete rendered document with frontmatter
    var fullDocument: String {
        var yamlString = "---\n"

        // Serialize frontmatter back to YAML
        if let yamlData = try? Yams.dump(object: frontmatter) {
            yamlString += yamlData
        }

        yamlString += "---\n\n"
        yamlString += renderedContent

        return yamlString
    }

    /// Get only the rendered markdown content without frontmatter
    var markdownOnly: String {
        renderedContent
    }
}

/// Errors that can occur during template processing
enum TemplateProcessingError: Error, LocalizedError, Equatable {
    case noFrontmatter
    case unclosedFrontmatter
    case invalidYAML(String)
    case yamlParsingFailed(String)
    case validationFailed(TemplateValidationResult)
    case renderingFailed(String)

    var errorDescription: String? {
        switch self {
        case .noFrontmatter:
            return "Document must start with YAML frontmatter delimited by ---"
        case .unclosedFrontmatter:
            return "YAML frontmatter is not properly closed with ---"
        case .invalidYAML(let detail):
            return "Invalid YAML structure: \(detail)"
        case .yamlParsingFailed(let detail):
            return "Failed to parse YAML: \(detail)"
        case .validationFailed(let result):
            let missing = result.missingVariables.joined(separator: ", ")
            return "Template validation failed. Missing variables: \(missing)"
        case .renderingFailed(let detail):
            return "Failed to render template: \(detail)"
        }
    }
}

/// Extension to provide convenience methods for Standards integration
extension TemplateProcessor {
    /// Process a Standards file from disk
    func processFile(at path: String, additionalContext: [String: Any] = [:]) throws -> ProcessedDocument {
        let url = URL(fileURLWithPath: path)
        let content = try String(contentsOf: url, encoding: .utf8)
        return try processDocument(content, additionalContext: additionalContext)
    }

    /// Process and save a Standards file
    func processAndSave(
        inputPath: String,
        outputPath: String,
        additionalContext: [String: Any] = [:]
    ) throws {
        let processed = try processFile(at: inputPath, additionalContext: additionalContext)
        let outputURL = URL(fileURLWithPath: outputPath)
        try processed.fullDocument.write(to: outputURL, atomically: true, encoding: .utf8)
    }
}
