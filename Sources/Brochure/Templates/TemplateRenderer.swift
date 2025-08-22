import Foundation
import Logging

/// Renders templates by processing variables, conditionals, and loops.
public struct TemplateRenderer {
    private let logger: Logger

    public init(logger: Logger? = nil) {
        self.logger = logger ?? Logger(label: "TemplateRenderer")
    }

    /// Render a template string with the given context.
    public func render(_ template: String, context: TemplateContext) throws -> String {
        var result = template

        // Process in order:
        // 1. Loops (innermost first)
        result = try processLoops(in: result, context: context)

        // 2. Conditionals
        result = try processConditionals(in: result, context: context)

        // 3. Defaults
        result = try processDefaults(in: result, context: context)

        // 4. Variable substitution
        result = try substituteVariables(in: result, context: context)

        // 5. Clean up any remaining template markers
        result = cleanupTemplate(result)

        return result
    }

    /// Substitute simple variables: {{variableName}}
    private func substituteVariables(in template: String, context: TemplateContext) throws -> String {
        let pattern = #"\{\{(\w+)\}\}"#
        let regex = try NSRegularExpression(pattern: pattern)
        var result = template

        let matches = regex.matches(in: template, range: NSRange(template.startIndex..., in: template))

        // Process matches in reverse order to maintain string indices
        for match in matches.reversed() {
            guard let keyRange = Range(match.range(at: 1), in: template) else { continue }
            let key = String(template[keyRange])

            // Try to find the key in context
            if let contextKey = ContextKey(rawValue: key),
                let value = context[contextKey]
            {
                let replacement = formatValue(value)
                if let range = Range(match.range, in: result) {
                    result.replaceSubrange(range, with: replacement)
                }
            } else {
                // Leave placeholder for unknown variables (will be cleaned up later)
                logger.debug("Unknown template variable: \(key)")
            }
        }

        return result
    }

    /// Process conditionals: {{#if condition}}...{{/if}}
    private func processConditionals(in template: String, context: TemplateContext) throws -> String {
        let pattern = #"\{\{#if\s+(\w+)\}\}(.*?)\{\{/if\}\}"#
        let regex = try NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
        var result = template

        let matches = regex.matches(in: template, range: NSRange(template.startIndex..., in: template))

        for match in matches.reversed() {
            guard let conditionRange = Range(match.range(at: 1), in: template),
                let contentRange = Range(match.range(at: 2), in: template)
            else { continue }

            let condition = String(template[conditionRange])
            let content = String(template[contentRange])

            // Check if condition is true
            let shouldInclude: Bool
            if let contextKey = ContextKey(rawValue: condition) {
                // Check if key exists and has truthy value
                if let value = context[contextKey] {
                    shouldInclude = isTruthy(value)
                } else {
                    shouldInclude = false
                }
            } else {
                shouldInclude = false
            }

            if let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: shouldInclude ? content : "")
            }
        }

        // Also handle negated conditionals: {{#unless condition}}...{{/unless}}
        let unlessPattern = #"\{\{#unless\s+(\w+)\}\}(.*?)\{\{/unless\}\}"#
        let unlessRegex = try NSRegularExpression(pattern: unlessPattern, options: .dotMatchesLineSeparators)

        let unlessMatches = unlessRegex.matches(in: result, range: NSRange(result.startIndex..., in: result))

        for match in unlessMatches.reversed() {
            guard let conditionRange = Range(match.range(at: 1), in: result),
                let contentRange = Range(match.range(at: 2), in: result)
            else { continue }

            let condition = String(result[conditionRange])
            let content = String(result[contentRange])

            let shouldInclude: Bool
            if let contextKey = ContextKey(rawValue: condition) {
                if let value = context[contextKey] {
                    shouldInclude = !isTruthy(value)
                } else {
                    shouldInclude = true
                }
            } else {
                shouldInclude = true
            }

            if let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: shouldInclude ? content : "")
            }
        }

        return result
    }

    /// Process loops: {{#each items}}...{{/each}}
    private func processLoops(in template: String, context: TemplateContext) throws -> String {
        let pattern = #"\{\{#each\s+(\w+)\}\}(.*?)\{\{/each\}\}"#
        let regex = try NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
        var result = template

        let matches = regex.matches(in: template, range: NSRange(template.startIndex..., in: template))

        for match in matches.reversed() {
            guard let itemsKeyRange = Range(match.range(at: 1), in: template),
                let contentRange = Range(match.range(at: 2), in: template)
            else { continue }

            let itemsKey = String(template[itemsKeyRange])
            let itemTemplate = String(template[contentRange])

            // Get array from context
            var rendered = ""
            if let contextKey = ContextKey(rawValue: itemsKey),
                let items = context[contextKey] as? [any Sendable]
            {
                for (index, item) in items.enumerated() {
                    var itemContent = itemTemplate

                    // Replace {{this}} with current item
                    itemContent = itemContent.replacingOccurrences(
                        of: "{{this}}",
                        with: formatValue(item)
                    )

                    // Replace {{@index}} with current index
                    itemContent = itemContent.replacingOccurrences(
                        of: "{{@index}}",
                        with: String(index)
                    )

                    // Replace {{@first}} and {{@last}}
                    itemContent = itemContent.replacingOccurrences(
                        of: "{{@first}}",
                        with: index == 0 ? "true" : "false"
                    )
                    itemContent = itemContent.replacingOccurrences(
                        of: "{{@last}}",
                        with: index == items.count - 1 ? "true" : "false"
                    )

                    // If item is a dictionary, replace its keys
                    if let dict = item as? [String: any Sendable] {
                        for (key, value) in dict {
                            itemContent = itemContent.replacingOccurrences(
                                of: "{{this.\(key)}}",
                                with: formatValue(value)
                            )
                        }
                    }

                    rendered += itemContent
                }
            }

            if let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: rendered)
            }
        }

        return result
    }

    /// Process defaults: {{variable|default:value}}
    private func processDefaults(in template: String, context: TemplateContext) throws -> String {
        let pattern = #"\{\{(\w+)\|default:([^}]+)\}\}"#
        let regex = try NSRegularExpression(pattern: pattern)
        var result = template

        let matches = regex.matches(in: template, range: NSRange(template.startIndex..., in: template))

        for match in matches.reversed() {
            guard let keyRange = Range(match.range(at: 1), in: template),
                let defaultRange = Range(match.range(at: 2), in: template)
            else { continue }

            let key = String(template[keyRange])
            let defaultValue = String(template[defaultRange])

            let value: String
            if let contextKey = ContextKey(rawValue: key),
                let contextValue = context[contextKey]
            {
                value = formatValue(contextValue)
            } else {
                // Check if default value is also a variable reference
                if let defaultContextKey = ContextKey(rawValue: defaultValue),
                    let defaultContextValue = context[defaultContextKey]
                {
                    value = formatValue(defaultContextValue)
                } else {
                    value = defaultValue
                }
            }

            if let range = Range(match.range, in: result) {
                result.replaceSubrange(range, with: value)
            }
        }

        return result
    }

    /// Clean up any remaining template markers.
    private func cleanupTemplate(_ template: String) -> String {
        var result = template

        // Remove any remaining unprocessed template variables
        let remainingPattern = #"\{\{[^}]*\}\}"#
        if let regex = try? NSRegularExpression(pattern: remainingPattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        return result
    }

    /// Format a value for template output.
    private func formatValue(_ value: any Sendable) -> String {
        if let string = value as? String {
            return string
        } else if let bool = value as? Bool {
            return bool ? "true" : "false"
        } else if let date = value as? Date {
            return ISO8601DateFormatter().string(from: date)
        } else {
            return String(describing: value)
        }
    }

    /// Check if a value is "truthy" for conditionals.
    private func isTruthy(_ value: any Sendable) -> Bool {
        if let bool = value as? Bool {
            return bool
        } else if let string = value as? String {
            return !string.isEmpty && string.lowercased() != "false"
        } else if let number = value as? NSNumber {
            return number.boolValue
        } else if let array = value as? [any Sendable] {
            return !array.isEmpty
        } else if let dict = value as? [String: any Sendable] {
            return !dict.isEmpty
        } else {
            return true  // Non-nil values are truthy
        }
    }
}
