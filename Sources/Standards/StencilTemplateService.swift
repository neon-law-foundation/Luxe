import Foundation
import PathKit
import Stencil

/// Protocol defining template operations for Standards documents
protocol StencilTemplateService {
    /// Parses and renders a template string with provided context
    /// - Parameters:
    ///   - template: The template string containing Stencil syntax
    ///   - context: Dictionary of values to interpolate into the template
    /// - Returns: The rendered template string with all variables replaced
    /// - Throws: StencilTemplateError if parsing or rendering fails
    func render(_ template: String, context: [String: Any]) throws -> String

    /// Parses a template string and returns the list of variable names used
    /// - Parameter template: The template string to analyze
    /// - Returns: Set of variable names found in the template
    /// - Throws: StencilTemplateError if parsing fails
    func extractVariables(from template: String) throws -> Set<String>

    /// Validates that all required variables are present in the context
    /// - Parameters:
    ///   - template: The template string to validate
    ///   - context: Dictionary of available values
    /// - Returns: Validation result with any missing variables
    /// - Throws: StencilTemplateError if parsing fails
    func validateContext(_ template: String, context: [String: Any]) throws -> TemplateValidationResult
}

/// Errors that can occur during template operations
enum StencilTemplateError: Error, LocalizedError {
    case parsingFailed(String)
    case renderingFailed(String)
    case missingVariables([String])
    case invalidTemplate(String)

    var errorDescription: String? {
        switch self {
        case .parsingFailed(let detail):
            return "Failed to parse template: \(detail)"
        case .renderingFailed(let detail):
            return "Failed to render template: \(detail)"
        case .missingVariables(let variables):
            return "Missing required variables: \(variables.joined(separator: ", "))"
        case .invalidTemplate(let detail):
            return "Invalid template: \(detail)"
        }
    }
}

/// Result of template validation
struct TemplateValidationResult: Equatable {
    let isValid: Bool
    let missingVariables: Set<String>
    let errors: [String]

    init(isValid: Bool = true, missingVariables: Set<String> = [], errors: [String] = []) {
        self.isValid = isValid
        self.missingVariables = missingVariables
        self.errors = errors
    }
}

/// Default implementation of StencilTemplateService
final class StandardsTemplateService: StencilTemplateService {
    private let environment: Environment

    init() {
        // Create environment with default loader
        let loader = FileSystemLoader(paths: [])
        var extensions: [Extension] = []

        // Create extension with custom filters
        let ext = Extension()

        // Register common date filter
        ext.registerFilter("date") { (value) -> Any? in
            guard let date = value as? Date else {
                return value
            }

            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none

            return formatter.string(from: date)
        }

        // Register currency filter
        ext.registerFilter("currency") { (value) -> Any? in
            guard let number = value as? Double else {
                return value
            }

            let formatter = NumberFormatter()
            formatter.numberStyle = .currency

            return formatter.string(from: NSNumber(value: number)) ?? String(number)
        }

        extensions.append(ext)
        self.environment = Environment(loader: loader, extensions: extensions)
    }

    func render(_ template: String, context: [String: Any]) throws -> String {
        do {
            let stencilTemplate = Template(templateString: template, environment: environment)
            return try stencilTemplate.render(context)
        } catch {
            throw StencilTemplateError.renderingFailed(error.localizedDescription)
        }
    }

    func extractVariables(from template: String) throws -> Set<String> {
        var variables = Set<String>()
        var loopVariables = Set<String>()  // Track loop iterator variables

        // Simple regex-based extraction for variables
        // Match {{ variable }} and {% if variable %} patterns
        let variablePattern = "\\{\\{\\s*([\\w\\.]+)\\s*(?:\\|.*)?\\}\\}"
        let blockPattern = "\\{%\\s*(?:if|elif)\\s+([\\w\\.]+)"
        // For loop pattern is different: {% for item in collection %}
        let forPattern = "\\{%\\s*for\\s+(\\w+)\\s+in\\s+(\\w+)"

        let variableRegex = try NSRegularExpression(pattern: variablePattern)
        let blockRegex = try NSRegularExpression(pattern: blockPattern)
        let forRegex = try NSRegularExpression(pattern: forPattern)

        let range = NSRange(location: 0, length: template.utf16.count)

        // Extract from {{ variable }} patterns
        let variableMatches = variableRegex.matches(in: template, range: range)
        for match in variableMatches {
            if let varRange = Range(match.range(at: 1), in: template) {
                let variable = String(template[varRange])
                // Get root variable if it has dots
                if let dotIndex = variable.firstIndex(of: ".") {
                    let rootVariable = String(variable[..<dotIndex])
                    variables.insert(rootVariable)
                } else {
                    variables.insert(variable)
                }
            }
        }

        // Extract from {% if/elif %} patterns
        let blockMatches = blockRegex.matches(in: template, range: range)
        for match in blockMatches {
            if let varRange = Range(match.range(at: 1), in: template) {
                let variable = String(template[varRange])
                // Get root variable if it has dots
                if let dotIndex = variable.firstIndex(of: ".") {
                    let rootVariable = String(variable[..<dotIndex])
                    variables.insert(rootVariable)
                } else {
                    variables.insert(variable)
                }
            }
        }

        // Extract from {% for item in collection %} patterns
        let forMatches = forRegex.matches(in: template, range: range)
        for match in forMatches {
            // The first capture group is the loop variable (should be excluded)
            if let loopVarRange = Range(match.range(at: 1), in: template) {
                let loopVar = String(template[loopVarRange])
                loopVariables.insert(loopVar)
            }
            // The second capture group is the collection being iterated (should be included)
            if let collectionRange = Range(match.range(at: 2), in: template) {
                let collection = String(template[collectionRange])
                variables.insert(collection)
            }
        }

        // Remove loop variables from the final set
        return variables.subtracting(loopVariables)
    }

    func validateContext(_ template: String, context: [String: Any]) throws -> TemplateValidationResult {
        let requiredVariables = try extractVariables(from: template)
        let providedVariables = Set(context.keys)
        let missingVariables = requiredVariables.subtracting(providedVariables)

        var errors: [String] = []

        if !missingVariables.isEmpty {
            errors.append("Missing variables: \(missingVariables.sorted().joined(separator: ", "))")
        }

        // Try to render to catch any other issues
        do {
            _ = try render(template, context: context)
        } catch {
            errors.append("Template rendering error: \(error.localizedDescription)")
        }

        return TemplateValidationResult(
            isValid: missingVariables.isEmpty && errors.isEmpty,
            missingVariables: missingVariables,
            errors: errors
        )
    }
}
