import Fluent
import Foundation
import Vapor
import Yams

/// Service for validating Sagebrush Standards notations according to the roadmap specifications.
///
/// This service provides comprehensive validation of notation documents, including YAML structure,
/// state machine validation, question references, and variable interpolation.
public final class NotationValidationService: Sendable {

    // MARK: - Validation Request/Response Models

    /// Request structure for notation validation
    public struct ValidationRequest: Content, Sendable {
        /// The notation content to validate (includes YAML frontmatter and markdown)
        public let content: String
        /// Whether to only validate without saving
        public let validateOnly: Bool
        /// Whether to include warnings in the response
        public let returnWarnings: Bool

        public init(content: String, validateOnly: Bool = true, returnWarnings: Bool = true) {
            self.content = content
            self.validateOnly = validateOnly
            self.returnWarnings = returnWarnings
        }
    }

    /// Response structure for notation validation
    public struct ValidationResponse: Content, Sendable {
        /// Whether the notation is valid
        public let valid: Bool
        /// Array of validation errors
        public let errors: [ValidationError]
        /// Array of validation warnings (optional)
        public let warnings: [ValidationWarning]

        public init(valid: Bool, errors: [ValidationError], warnings: [ValidationWarning] = []) {
            self.valid = valid
            self.errors = errors
            self.warnings = warnings
        }
    }

    /// Structure for validation errors
    public struct ValidationError: Content, Sendable {
        /// Type of error
        public let type: String
        /// Field that has the error (if applicable)
        public let field: String?
        /// Human-readable error message
        public let message: String
        /// Line number where error occurs (if applicable)
        public let line: Int?
        /// Suggestion for fixing the error
        public let suggestion: String?

        public init(type: String, field: String? = nil, message: String, line: Int? = nil, suggestion: String? = nil) {
            self.type = type
            self.field = field
            self.message = message
            self.line = line
            self.suggestion = suggestion
        }
    }

    /// Structure for validation warnings
    public struct ValidationWarning: Content, Sendable {
        /// Type of warning
        public let type: String
        /// Variable that may be problematic (if applicable)
        public let variable: String?
        /// Human-readable warning message
        public let message: String
        /// Line number where warning occurs (if applicable)
        public let line: Int?

        public init(type: String, variable: String? = nil, message: String, line: Int? = nil) {
            self.type = type
            self.variable = variable
            self.message = message
            self.line = line
        }
    }

    // MARK: - Parsed Notation Structure

    /// Parsed YAML frontmatter from a notation
    private struct ParsedNotation {
        let code: String?
        let title: String?
        let description: String?
        let respondentType: String?
        let flow: [String: Any]?
        let alignment: [String: Any]?
        let documentText: String
    }

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    // MARK: - Main Validation Method

    /// Validates a notation according to all roadmap requirements
    public func validate(_ request: ValidationRequest) async throws -> ValidationResponse {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []

        // Step 1: Parse YAML frontmatter
        guard let parsed = parseNotation(request.content, errors: &errors) else {
            return ValidationResponse(valid: false, errors: errors, warnings: warnings)
        }

        // Step 2: Validate YAML structure and required fields
        validateYAMLStructure(parsed, errors: &errors)

        // Step 3: Validate state machines
        if let flow = parsed.flow {
            await validateStateMachine(flow, type: "flow", errors: &errors, warnings: &warnings)
        }

        if let alignment = parsed.alignment {
            await validateStateMachine(alignment, type: "alignment", errors: &errors, warnings: &warnings)
        }

        // Step 4: Validate variable interpolation
        validateVariableInterpolation(parsed, errors: &errors, warnings: &warnings)

        // Step 5: Validate code uniqueness if provided
        if let code = parsed.code {
            await validateCodeUniqueness(code, errors: &errors)
        }

        let isValid = errors.isEmpty
        return ValidationResponse(
            valid: isValid,
            errors: errors,
            warnings: request.returnWarnings ? warnings : []
        )
    }
}

// MARK: - YAML Parsing

extension NotationValidationService {

    /// Parses the notation content and extracts YAML frontmatter
    private func parseNotation(_ content: String, errors: inout [ValidationError]) -> ParsedNotation? {
        // Check for YAML frontmatter boundaries
        let lines = content.components(separatedBy: .newlines)

        guard !lines.isEmpty && lines[0].trimmingCharacters(in: .whitespacesAndNewlines) == "---" else {
            errors.append(
                ValidationError(
                    type: "missing_frontmatter",
                    message: "Document must start with '---' on the first line",
                    line: 1,
                    suggestion: "Add '---' as the first line to start YAML frontmatter"
                )
            )
            return nil
        }

        // Find the closing frontmatter boundary
        var frontmatterEndIndex: Int?
        for (index, line) in lines.enumerated() {
            if index > 0 && line.trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                frontmatterEndIndex = index
                break
            }
        }

        guard let endIndex = frontmatterEndIndex else {
            errors.append(
                ValidationError(
                    type: "invalid_frontmatter",
                    message: "YAML frontmatter must end with '---'",
                    suggestion: "Add a closing '---' line after your YAML frontmatter"
                )
            )
            return nil
        }

        // Extract YAML content
        let yamlLines = Array(lines[1..<endIndex])
        let yamlContent = yamlLines.joined(separator: "\n")

        // Extract document text (everything after the closing ---)
        let documentLines = Array(lines[(endIndex + 1)...])
        let documentText = documentLines.joined(separator: "\n")

        // Parse YAML
        do {
            guard let yamlData = try Yams.load(yaml: yamlContent) as? [String: Any] else {
                errors.append(
                    ValidationError(
                        type: "invalid_yaml",
                        message: "YAML frontmatter must be a valid object",
                        suggestion: "Ensure your YAML is properly formatted with key-value pairs"
                    )
                )
                return nil
            }

            return ParsedNotation(
                code: yamlData["code"] as? String,
                title: yamlData["title"] as? String,
                description: yamlData["description"] as? String,
                respondentType: yamlData["respondent_type"] as? String,
                flow: yamlData["flow"] as? [String: Any],
                alignment: yamlData["alignment"] as? [String: Any],
                documentText: documentText
            )

        } catch {
            errors.append(
                ValidationError(
                    type: "yaml_parse_error",
                    message: "Invalid YAML syntax: \(error.localizedDescription)",
                    suggestion: "Check your YAML syntax and ensure proper indentation"
                )
            )
            return nil
        }
    }
}

// MARK: - YAML Structure Validation

extension NotationValidationService {

    /// Validates the YAML structure and required fields
    private func validateYAMLStructure(_ parsed: ParsedNotation, errors: inout [ValidationError]) {
        // Validate required fields
        if parsed.code == nil || parsed.code?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            errors.append(
                ValidationError(
                    type: "missing_field",
                    field: "code",
                    message: "Required field 'code' is missing or empty",
                    suggestion: "Add 'code: unique_identifier' to the YAML frontmatter"
                )
            )
        }

        if parsed.title == nil || parsed.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            errors.append(
                ValidationError(
                    type: "missing_field",
                    field: "title",
                    message: "Required field 'title' is missing or empty",
                    suggestion: "Add 'title: Your Document Title' to the YAML frontmatter"
                )
            )
        }

        if parsed.description == nil
            || parsed.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
        {
            errors.append(
                ValidationError(
                    type: "missing_field",
                    field: "description",
                    message: "Required field 'description' is missing or empty",
                    suggestion: "Add 'description: Brief description of the document' to the YAML frontmatter"
                )
            )
        }

        if parsed.flow == nil {
            errors.append(
                ValidationError(
                    type: "missing_field",
                    field: "flow",
                    message: "Required field 'flow' is missing",
                    suggestion: "Add 'flow:' with a valid state machine object to the YAML frontmatter"
                )
            )
        }

        if parsed.alignment == nil {
            errors.append(
                ValidationError(
                    type: "missing_field",
                    field: "alignment",
                    message: "Required field 'alignment' is missing",
                    suggestion: "Add 'alignment:' with a valid state machine object to the YAML frontmatter"
                )
            )
        }

        // Validate respondent_type
        if let respondentType = parsed.respondentType {
            if respondentType != "org" && respondentType != "org_and_person" {
                errors.append(
                    ValidationError(
                        type: "invalid_field_value",
                        field: "respondent_type",
                        message: "Field 'respondent_type' must be either 'org' or 'org_and_person'",
                        suggestion: "Change 'respondent_type' to either 'org' or 'org_and_person'"
                    )
                )
            }
        }

        // Validate title length
        if let title = parsed.title, title.count > 255 {
            errors.append(
                ValidationError(
                    type: "field_too_long",
                    field: "title",
                    message: "Field 'title' exceeds maximum length of 255 characters",
                    suggestion: "Shorten the title to 255 characters or less"
                )
            )
        }
    }
}

// MARK: - State Machine Validation

extension NotationValidationService {

    /// Validates a state machine (flow or alignment)
    private func validateStateMachine(
        _ stateMachine: [String: Any],
        type: String,
        errors: inout [ValidationError],
        warnings: inout [ValidationWarning]
    ) async {
        // Check for BEGIN state
        guard stateMachine["BEGIN"] != nil else {
            errors.append(
                ValidationError(
                    type: "missing_begin_state",
                    field: type,
                    message: "\(type.capitalized) must have 'BEGIN:' as a top-level key",
                    suggestion: "Add 'BEGIN:' as the first state in your \(type) definition"
                )
            )
            return
        }

        // Check for END reachability
        let hasEndState = await hasReachableEndState(stateMachine)
        if !hasEndState {
            errors.append(
                ValidationError(
                    type: "no_end_state",
                    field: type,
                    message: "\(type.capitalized) must have at least one path that leads to 'END'",
                    suggestion: "Ensure at least one state transition leads to 'END'"
                )
            )
        }

        // Validate question references in state machine
        await validateQuestionReferences(in: stateMachine, type: type, errors: &errors, warnings: &warnings)

        // Check for infinite loops (basic cycle detection)
        let hasCycles = detectCycles(in: stateMachine)
        if hasCycles {
            warnings.append(
                ValidationWarning(
                    type: "potential_infinite_loop",
                    message: "Potential infinite loop detected in \(type) state machine",
                    line: nil
                )
            )
        }
    }

    /// Checks if the state machine has a reachable END state
    private func hasReachableEndState(_ stateMachine: [String: Any]) async -> Bool {
        var visited = Set<String>()
        var queue = ["BEGIN"]

        while !queue.isEmpty {
            let currentState = queue.removeFirst()

            if visited.contains(currentState) {
                continue
            }
            visited.insert(currentState)

            if currentState == "END" {
                return true
            }

            // Get transitions from current state
            if let stateData = stateMachine[currentState] as? [String: Any] {
                for (_, nextState) in stateData {
                    if let nextStateString = nextState as? String {
                        if !visited.contains(nextStateString) {
                            queue.append(nextStateString)
                        }
                    }
                }
            }
        }

        return false
    }

    /// Basic cycle detection in state machine
    private func detectCycles(in stateMachine: [String: Any]) -> Bool {
        var visited = Set<String>()
        var recursionStack = Set<String>()

        func hasCycle(_ state: String) -> Bool {
            if recursionStack.contains(state) {
                return true
            }

            if visited.contains(state) {
                return false
            }

            visited.insert(state)
            recursionStack.insert(state)

            if let stateData = stateMachine[state] as? [String: Any] {
                for (_, nextState) in stateData {
                    if let nextStateString = nextState as? String {
                        if nextStateString != "END" && nextStateString != "ERROR" {
                            if hasCycle(nextStateString) {
                                return true
                            }
                        }
                    }
                }
            }

            recursionStack.remove(state)
            return false
        }

        return hasCycle("BEGIN")
    }
}

// MARK: - Question Reference Validation

extension NotationValidationService {

    /// Validates all question references in a state machine
    private func validateQuestionReferences(
        in stateMachine: [String: Any],
        type: String,
        errors: inout [ValidationError],
        warnings: inout [ValidationWarning]
    ) async {
        var questionCodes = Set<String>()

        // Extract all question codes from the state machine
        for (key, value) in stateMachine {
            if key != "BEGIN" {
                // Extract question code from key (format: prefix__question_code or prefix__question_code__for_variable)
                if let questionCode = extractQuestionCode(from: key) {
                    questionCodes.insert(questionCode)
                }
            }

            // Also check transitions
            if let stateData = value as? [String: Any] {
                for (_, nextState) in stateData {
                    if let nextStateString = nextState as? String {
                        if nextStateString != "END" && nextStateString != "ERROR" {
                            if let questionCode = extractQuestionCode(from: nextStateString) {
                                questionCodes.insert(questionCode)
                            }
                        }
                    }
                }
            }
        }

        // Validate that all question codes exist in the database
        for questionCode in questionCodes {
            let exists = await questionExists(code: questionCode)
            if !exists {
                errors.append(
                    ValidationError(
                        type: "missing_question",
                        field: type,
                        message: "Question with code '\(questionCode)' does not exist in the Questions table",
                        suggestion: "Create a question with code '\(questionCode)' or use an existing question code"
                    )
                )
            }
        }
    }

    /// Extracts question code from a reference string
    private func extractQuestionCode(from reference: String) -> String? {
        let components = reference.components(separatedBy: "__")

        if components.count >= 2 {
            // Format: prefix__question_code or prefix__question_code__for_variable
            return components[1]
        }

        return nil
    }

    /// Checks if a question with the given code exists
    private func questionExists(code: String) async -> Bool {
        do {
            let count = try await Question.query(on: database)
                .filter(\.$code == code)
                .count()
            return count > 0
        } catch {
            return false
        }
    }
}

// MARK: - Variable Interpolation Validation

extension NotationValidationService {

    /// Validates variable interpolation in document text
    private func validateVariableInterpolation(
        _ parsed: ParsedNotation,
        errors: inout [ValidationError],
        warnings: inout [ValidationWarning]
    ) {
        let documentText = parsed.documentText

        // Extract all {{variable}} references
        let variablePattern = #"\{\{([^}]+)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: variablePattern) else {
            return
        }

        let range = NSRange(location: 0, length: documentText.utf16.count)
        let matches = regex.matches(in: documentText, range: range)

        for match in matches {
            if let variableRange = Range(match.range(at: 1), in: documentText) {
                let variableReference = String(documentText[variableRange])
                validateVariableReference(variableReference, in: parsed, warnings: &warnings)
            }
        }
    }

    /// Validates a single variable reference
    private func validateVariableReference(
        _ variable: String,
        in parsed: ParsedNotation,
        warnings: inout [ValidationWarning]
    ) {
        // Split variable and filter
        let components = variable.components(separatedBy: "|")
        let variableName = components[0].trimmingCharacters(in: .whitespacesAndNewlines)

        // Validate filter if present
        if components.count > 1 {
            let filter = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            validateFilter(filter, for: variableName, warnings: &warnings)
        }

        // Check if variable might be undefined
        let isSystemVariable =
            ["entity", "person", "org"].contains(variableName) || variableName.hasPrefix("person.")
            || variableName.hasPrefix("org.") || variableName.hasPrefix("entity.")

        if !isSystemVariable {
            // Check if variable corresponds to a question reference pattern
            let isQuestionReference = variableName.contains(".")

            if !isQuestionReference {
                warnings.append(
                    ValidationWarning(
                        type: "undefined_variable",
                        variable: variableName,
                        message: "Variable '\(variableName)' may be undefined or not available in this context"
                    )
                )
            }
        }
    }

    /// Validates a filter applied to a variable
    private func validateFilter(_ filter: String, for variable: String, warnings: inout [ValidationWarning]) {
        let supportedFilters = ["date", "currency", "uppercase", "lowercase"]

        if !supportedFilters.contains(filter) {
            warnings.append(
                ValidationWarning(
                    type: "unsupported_filter",
                    variable: variable,
                    message:
                        "Filter '\(filter)' is not supported. Supported filters: \(supportedFilters.joined(separator: ", "))"
                )
            )
        }
    }
}

// MARK: - Code Uniqueness Validation

extension NotationValidationService {

    /// Validates that the notation code is unique
    private func validateCodeUniqueness(_ code: String, errors: inout [ValidationError]) async {
        do {
            let existingCount = try await Notation.query(on: database)
                .filter(\.$code == code)
                .count()

            if existingCount > 0 {
                errors.append(
                    ValidationError(
                        type: "duplicate_code",
                        field: "code",
                        message: "Code '\(code)' already exists. Codes must be unique.",
                        suggestion: "Choose a different unique code for this notation"
                    )
                )
            }
        } catch {
            errors.append(
                ValidationError(
                    type: "database_error",
                    field: "code",
                    message: "Unable to check code uniqueness: \(error.localizedDescription)",
                    suggestion: "Ensure database connection is available"
                )
            )
        }
    }
}
