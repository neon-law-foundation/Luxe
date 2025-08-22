import Fluent
import FluentPostgresDriver
import TestUtilities
import Testing
import Vapor

@testable import Dali

@Suite("Notation Validation Service", .serialized)
struct NotationValidationServiceTests {

    // MARK: - YAML Structure Validation Tests

    @Test("Valid notation with all required fields should pass validation")
    func validNotationValidation() async throws {
        try await TestUtilities.withApp { app, database in
            let service = NotationValidationService(database: app.db)

            let validContent = """
                ---
                title: Test Document
                code: test_doc_001
                description: A test document for validation
                respondent_type: org
                flow:
                  BEGIN:
                    _: END
                alignment:
                  BEGIN:
                    _: END
                ---
                # Test Document

                This is a test document.
                """

            let request = NotationValidationService.ValidationRequest(
                content: validContent,
                validateOnly: true,
                returnWarnings: true
            )

            let response = try await service.validate(request)

            #expect(response.valid == true)
            #expect(response.errors.isEmpty)
        }
    }

    @Test("Notation missing required fields should fail validation")
    func missingRequiredFieldsValidation() async throws {
        try await TestUtilities.withApp { app, database in
            let service = NotationValidationService(database: app.db)

            let invalidContent = """
                ---
                title: Test Document
                # Missing code, description, flow, alignment
                ---
                # Test Document

                This is incomplete.
                """

            let request = NotationValidationService.ValidationRequest(
                content: invalidContent,
                validateOnly: true,
                returnWarnings: true
            )

            let response = try await service.validate(request)

            #expect(response.valid == false)
            #expect(!response.errors.isEmpty)

            // Check that we have errors for missing required fields
            let errorTypes = response.errors.map { $0.type }
            #expect(errorTypes.contains("missing_field"))
        }
    }

    @Test("Invalid YAML frontmatter should fail validation")
    func invalidYAMLValidation() async throws {
        try await TestUtilities.withApp { app, database in
            let service = NotationValidationService(database: app.db)

            let invalidContent = """
                ---
                title: Test Document
                code: test_doc
                invalid_yaml: [unclosed array
                ---
                # Test Document

                This has invalid YAML.
                """

            let request = NotationValidationService.ValidationRequest(
                content: invalidContent,
                validateOnly: true,
                returnWarnings: true
            )

            let response = try await service.validate(request)

            #expect(response.valid == false)
            #expect(!response.errors.isEmpty)

            // Check that we have a YAML parse error
            let errorTypes = response.errors.map { $0.type }
            #expect(errorTypes.contains("yaml_parse_error"))
        }
    }

    @Test("Missing frontmatter boundaries should fail validation")
    func missingFrontmatterValidation() async throws {
        try await TestUtilities.withApp { app, database in
            let service = NotationValidationService(database: app.db)

            let invalidContent = """
                title: Test Document
                code: test_doc

                # Test Document

                This is missing YAML frontmatter boundaries.
                """

            let request = NotationValidationService.ValidationRequest(
                content: invalidContent,
                validateOnly: true,
                returnWarnings: true
            )

            let response = try await service.validate(request)

            #expect(response.valid == false)
            #expect(!response.errors.isEmpty)

            // Check that we have a missing frontmatter error
            let errorTypes = response.errors.map { $0.type }
            #expect(errorTypes.contains("missing_frontmatter"))
        }
    }

    // MARK: - State Machine Validation Tests

    @Test("State machine missing BEGIN should fail validation")
    func missingBeginStateValidation() async throws {
        try await TestUtilities.withApp { app, database in
            let service = NotationValidationService(database: app.db)

            let invalidContent = """
                ---
                title: Test Document
                code: test_doc_002
                description: A test document
                respondent_type: org
                flow:
                  INVALID_START:
                    _: END
                alignment:
                  BEGIN:
                    _: END
                ---
                # Test Document

                This has invalid flow structure.
                """

            let request = NotationValidationService.ValidationRequest(
                content: invalidContent,
                validateOnly: true,
                returnWarnings: true
            )

            let response = try await service.validate(request)

            #expect(response.valid == false)
            #expect(!response.errors.isEmpty)

            // Check that we have a missing BEGIN state error
            let errorTypes = response.errors.map { $0.type }
            #expect(errorTypes.contains("missing_begin_state"))
        }
    }

    @Test("State machine with no path to END should fail validation")
    func noEndPathValidation() async throws {
        try await TestUtilities.withApp { app, database in
            let service = NotationValidationService(database: app.db)

            let invalidContent = """
                ---
                title: Test Document
                code: test_doc_003
                description: A test document
                respondent_type: org
                flow:
                  BEGIN:
                    _: NOWHERE
                  NOWHERE:
                    _: NOWHERE
                alignment:
                  BEGIN:
                    _: END
                ---
                # Test Document

                This has no path to END.
                """

            let request = NotationValidationService.ValidationRequest(
                content: invalidContent,
                validateOnly: true,
                returnWarnings: true
            )

            let response = try await service.validate(request)

            #expect(response.valid == false)
            #expect(!response.errors.isEmpty)

            // Check that we have a no END state error
            let errorTypes = response.errors.map { $0.type }
            #expect(errorTypes.contains("no_end_state"))
        }
    }

    // MARK: - Variable Interpolation Tests

    @Test("Valid variable interpolation should not generate warnings")
    func validVariableInterpolation() async throws {
        try await TestUtilities.withApp { app, database in
            let service = NotationValidationService(database: app.db)

            let validContent = """
                ---
                title: Test Document
                code: test_doc_004
                description: A test document for {{entity.name}}
                respondent_type: org
                flow:
                  BEGIN:
                    _: END
                alignment:
                  BEGIN:
                    _: END
                ---
                # Test Document

                This document is for {{entity.name}} and was created on {{effective_date}}.
                """

            let request = NotationValidationService.ValidationRequest(
                content: validContent,
                validateOnly: true,
                returnWarnings: true
            )

            let response = try await service.validate(request)

            // Should be valid but might have warnings for undefined variables
            #expect(response.valid == true)

            // Check that system variables like entity.name don't generate warnings
            let undefinedVariableWarnings = response.warnings.filter {
                $0.type == "undefined_variable" && $0.variable == "entity.name"
            }
            #expect(undefinedVariableWarnings.isEmpty)
        }
    }

    @Test("Invalid filter should generate warning")
    func invalidFilterWarning() async throws {
        try await TestUtilities.withApp { app, database in
            let service = NotationValidationService(database: app.db)

            let contentWithInvalidFilter = """
                ---
                title: Test Document
                code: test_doc_005
                description: A test document
                respondent_type: org
                flow:
                  BEGIN:
                    _: END
                alignment:
                  BEGIN:
                    _: END
                ---
                # Test Document

                This document was created on {{effective_date|invalid_filter}}.
                """

            let request = NotationValidationService.ValidationRequest(
                content: contentWithInvalidFilter,
                validateOnly: true,
                returnWarnings: true
            )

            let response = try await service.validate(request)

            #expect(response.valid == true)
            #expect(!response.warnings.isEmpty)

            // Check that we have an unsupported filter warning
            let filterWarnings = response.warnings.filter { $0.type == "unsupported_filter" }
            #expect(!filterWarnings.isEmpty)
        }
    }

    // MARK: - Respondent Type Validation Tests

    @Test("Invalid respondent type should fail validation")
    func invalidRespondentTypeValidation() async throws {
        try await TestUtilities.withApp { app, database in
            let service = NotationValidationService(database: app.db)

            let invalidContent = """
                ---
                title: Test Document
                code: test_doc_006
                description: A test document
                respondent_type: invalid_type
                flow:
                  BEGIN:
                    _: END
                alignment:
                  BEGIN:
                    _: END
                ---
                # Test Document

                This has invalid respondent type.
                """

            let request = NotationValidationService.ValidationRequest(
                content: invalidContent,
                validateOnly: true,
                returnWarnings: true
            )

            let response = try await service.validate(request)

            #expect(response.valid == false)
            #expect(!response.errors.isEmpty)

            // Check that we have an invalid field value error
            let errorTypes = response.errors.map { $0.type }
            #expect(errorTypes.contains("invalid_field_value"))
        }
    }

    @Test("Valid respondent types should pass validation")
    func validRespondentTypesValidation() async throws {
        try await TestUtilities.withApp { app, database in
            let service = NotationValidationService(database: app.db)

            let validTypes = ["org", "org_and_person"]

            for respondentType in validTypes {
                let validContent = """
                    ---
                    title: Test Document
                    code: test_doc_\(respondentType)
                    description: A test document
                    respondent_type: \(respondentType)
                    flow:
                      BEGIN:
                        _: END
                    alignment:
                      BEGIN:
                        _: END
                    ---
                    # Test Document

                    This has valid respondent type: \(respondentType).
                    """

                let request = NotationValidationService.ValidationRequest(
                    content: validContent,
                    validateOnly: true,
                    returnWarnings: true
                )

                let response = try await service.validate(request)

                #expect(response.valid == true, "respondent_type '\(respondentType)' should be valid")
            }
        }
    }
}
