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
        self.environment = Self.createEnvironment()
    }

    private static func formatNumber(_ number: Double, decimals: Int?) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        if let decimals = decimals {
            formatter.minimumFractionDigits = decimals
            formatter.maximumFractionDigits = decimals
        }
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }

    private static func formatPercentage(_ number: Double, decimals: Int?) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        if let decimals = decimals {
            formatter.minimumFractionDigits = decimals
            formatter.maximumFractionDigits = decimals
        }
        // Divide by 100 since NumberFormatter expects 0.5 for 50%
        return formatter.string(from: NSNumber(value: number / 100.0)) ?? "\(number)%"
    }

    private static func createEnvironment() -> Environment {
        // Create environment with default loader
        let loader = FileSystemLoader(paths: [])
        var extensions: [Extension] = []

        // Create extension with custom filters
        let ext = Extension()

        // Register enhanced date filter with format parameter
        ext.registerFilter("date") { (value, args) -> Any? in
            guard let date = value as? Date else {
                return value
            }

            let formatter = DateFormatter()

            // Check if a format string was provided
            if let format = args.first as? String {
                formatter.dateFormat = format
            } else {
                // Default format
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
            }

            return formatter.string(from: date)
        }

        // Register currency filter with locale support
        ext.registerFilter("currency") { (value, args) -> Any? in
            guard let number = value as? Double else {
                return value
            }

            let formatter = NumberFormatter()
            formatter.numberStyle = .currency

            // Check if a currency code was provided
            if let currencyCode = args.first as? String {
                formatter.currencyCode = currencyCode
            }

            return formatter.string(from: NSNumber(value: number)) ?? String(number)
        }

        // Register uppercase filter
        ext.registerFilter("uppercase") { (value) -> Any? in
            guard let string = value as? String else {
                return value
            }
            return string.uppercased()
        }

        // Register lowercase filter
        ext.registerFilter("lowercase") { (value) -> Any? in
            guard let string = value as? String else {
                return value
            }
            return string.lowercased()
        }

        // Register capitalize filter
        ext.registerFilter("capitalize") { (value) -> Any? in
            guard let string = value as? String else {
                return value
            }
            return string.capitalized
        }

        // Register truncate filter
        ext.registerFilter("truncate") { (value, args) -> Any? in
            guard let string = value as? String else {
                return value
            }

            let length = (args.first as? Int) ?? 50
            let suffix = (args.count > 1 ? args[1] as? String : nil) ?? "..."

            if string.count <= length {
                return string
            }

            let endIndex = string.index(string.startIndex, offsetBy: length)
            return String(string[..<endIndex]) + suffix
        }

        // Register default filter
        ext.registerFilter("default") { (value, args) -> Any? in
            // If value is nil or empty string, return default
            if value == nil || (value as? String)?.isEmpty == true {
                return args.first ?? ""
            }
            return value
        }

        // Register join filter
        ext.registerFilter("join") { (value, args) -> Any? in
            guard let array = value as? [Any] else {
                return value
            }

            let separator = (args.first as? String) ?? ", "
            return array.map { String(describing: $0) }.joined(separator: separator)
        }

        // Register count filter
        ext.registerFilter("count") { (value) -> Any? in
            if let array = value as? [Any] {
                return array.count
            } else if let string = value as? String {
                return string.count
            } else if let dict = value as? [String: Any] {
                return dict.count
            }
            return 0
        }

        // Register number formatting filter
        ext.registerFilter("number") { (value, args) -> Any? in
            guard let number = value as? Double else {
                if let intNumber = value as? Int {
                    return StandardsTemplateService.formatNumber(Double(intNumber), decimals: args.first as? Int)
                }
                return value
            }

            return StandardsTemplateService.formatNumber(number, decimals: args.first as? Int)
        }

        // Register percentage filter
        ext.registerFilter("percentage") { (value, args) -> Any? in
            guard let number = value as? Double else {
                if let intNumber = value as? Int {
                    return StandardsTemplateService.formatPercentage(Double(intNumber), decimals: args.first as? Int)
                }
                return value
            }

            return StandardsTemplateService.formatPercentage(number, decimals: args.first as? Int)
        }

        extensions.append(ext)
        return Environment(loader: loader, extensions: extensions)
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

        // Enhanced regex patterns for better variable extraction
        // Match {{ variable }} and {{ variable|filter }} patterns
        let variablePattern = "\\{\\{\\s*([\\w\\.]+)\\s*(?:\\|.*)?\\}\\}"

        // Match {% if variable %} and {% if variable == "value" %} patterns
        // This handles comparisons and logical operators
        let blockPattern = "\\{%\\s*(?:if|elif)\\s+(?:not\\s+)?([\\w\\.]+)(?:\\s*[!=<>]=?.*)?\\s*%\\}"

        // For loop pattern: {% for item in collection %}
        let forPattern = "\\{%\\s*for\\s+(\\w+)\\s+in\\s+([\\w\\.]+)\\s*%\\}"

        // Match comparison patterns like {% if foo == bar %}
        let comparisonPattern = "\\{%\\s*(?:if|elif).*?\\s+([\\w\\.]+)\\s*[!=<>]=?\\s*([\\w\\.]+).*?%\\}"

        let variableRegex = try NSRegularExpression(pattern: variablePattern)
        let blockRegex = try NSRegularExpression(pattern: blockPattern)
        let forRegex = try NSRegularExpression(pattern: forPattern)
        let comparisonRegex = try NSRegularExpression(pattern: comparisonPattern)

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
                // Get root variable if it has dots
                if let dotIndex = collection.firstIndex(of: ".") {
                    let rootVariable = String(collection[..<dotIndex])
                    variables.insert(rootVariable)
                } else {
                    variables.insert(collection)
                }
            }
        }

        // Extract from comparison patterns
        let comparisonMatches = comparisonRegex.matches(in: template, range: range)
        for match in comparisonMatches {
            // Extract both sides of comparison
            for i in 1...2 {
                if let varRange = Range(match.range(at: i), in: template) {
                    let variable = String(template[varRange])
                    // Only add if it looks like a variable (not a string literal)
                    if !variable.contains("\"") && !variable.contains("'") {
                        // Get root variable if it has dots
                        if let dotIndex = variable.firstIndex(of: ".") {
                            let rootVariable = String(variable[..<dotIndex])
                            if !loopVariables.contains(rootVariable) {
                                variables.insert(rootVariable)
                            }
                        } else if !loopVariables.contains(variable) {
                            variables.insert(variable)
                        }
                    }
                }
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
