import Foundation

struct ValidationResult {
    let isValid: Bool
    let validFiles: [String]
    let invalidFiles: [String]
    let errors: [String]

    var totalFilesProcessed: Int {
        validFiles.count + invalidFiles.count
    }
}

struct StandardsValidator {
    private let fileProcessor = FileProcessor()
    private let yamlValidator = YAMLValidator()

    /// Validate all markdown files in a directory
    func validateDirectory(path: String) -> ValidationResult {
        let markdownFiles = fileProcessor.findMarkdownFiles(in: path)

        if markdownFiles.isEmpty {
            return ValidationResult(isValid: true, validFiles: [], invalidFiles: [], errors: [])
        }

        var validFiles: [String] = []
        var invalidFiles: [String] = []
        var errors: [String] = []

        for filePath in markdownFiles {
            do {
                let content = try String(contentsOfFile: filePath, encoding: .utf8)
                let validationErrors = validateFileContent(content: content, filePath: filePath)

                if validationErrors.isEmpty {
                    validFiles.append(filePath)
                } else {
                    invalidFiles.append(filePath)
                    errors.append(contentsOf: validationErrors)
                }
            } catch {
                invalidFiles.append(filePath)
                errors.append("Failed to read file \(filePath): \(error.localizedDescription)")
            }
        }

        let isValid = invalidFiles.isEmpty
        return ValidationResult(
            isValid: isValid,
            validFiles: validFiles,
            invalidFiles: invalidFiles,
            errors: errors
        )
    }

    /// Validate the content of a single file
    private func validateFileContent(content: String, filePath: String) -> [String] {
        var errors: [String] = []

        // Check for frontmatter presence
        if !yamlValidator.hasFrontmatter(content: content) {
            errors.append("\(filePath): Missing YAML frontmatter delimiters (---)")
            return errors  // If no frontmatter, no point checking further
        }

        // Check YAML syntax
        if !yamlValidator.isValidYAML(content: content) {
            errors.append("\(filePath): Invalid YAML syntax in frontmatter")
        }

        // Check required fields
        if !yamlValidator.hasRequiredFields(content: content) {
            errors.append("\(filePath): Missing required YAML fields (code, title, respondant_type)")
        }

        return errors
    }
}
