import Foundation
import Yams

struct YAMLValidator {

    /// Check if content has YAML frontmatter with proper delimiters
    func hasFrontmatter(content: String) -> Bool {
        hasValidStartDelimiter(content: content) && hasValidEndDelimiter(content: content)
    }

    /// Check if content starts with --- delimiter
    func hasValidStartDelimiter(content: String) -> Bool {
        content.hasPrefix("---")
    }

    /// Check if content has ending --- delimiter after the starting one
    func hasValidEndDelimiter(content: String) -> Bool {
        let lines = content.components(separatedBy: .newlines)

        // Must start with ---
        guard lines.first == "---" else {
            return false
        }

        // Find the second occurrence of ---
        var foundStart = false
        for line in lines {
            if line == "---" {
                if foundStart {
                    // Found the ending delimiter
                    return true
                } else {
                    // Found the starting delimiter
                    foundStart = true
                }
            }
        }

        return false
    }

    /// Check if the YAML frontmatter can be parsed successfully
    func isValidYAML(content: String) -> Bool {
        guard let yamlContent = extractYAMLContent(from: content) else {
            return false
        }

        do {
            _ = try Yams.load(yaml: yamlContent)
            return true
        } catch {
            return false
        }
    }

    /// Check if the YAML frontmatter contains all required fields
    func hasRequiredFields(content: String) -> Bool {
        guard let yamlContent = extractYAMLContent(from: content) else {
            return false
        }

        do {
            guard let yaml = try Yams.load(yaml: yamlContent) as? [String: Any] else {
                return false
            }

            // Check for required fields
            let requiredFields = ["code", "title", "respondant_type"]
            for field in requiredFields {
                guard yaml[field] != nil else {
                    return false
                }
            }

            return true
        } catch {
            return false
        }
    }

    /// Extract YAML content between the delimiters
    private func extractYAMLContent(from content: String) -> String? {
        let lines = content.components(separatedBy: .newlines)

        // Must start with ---
        guard lines.first == "---" else {
            return nil
        }

        var yamlLines: [String] = []
        var foundStart = false

        for line in lines {
            if line == "---" {
                if foundStart {
                    // Found the ending delimiter
                    break
                } else {
                    // Found the starting delimiter
                    foundStart = true
                    continue
                }
            }

            if foundStart {
                yamlLines.append(line)
            }
        }

        return yamlLines.joined(separator: "\n")
    }
}
