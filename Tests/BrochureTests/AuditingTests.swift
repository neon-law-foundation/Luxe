import Foundation
import Logging
import Testing

@testable import Brochure

/// Comprehensive test suite for audit logging functionality.
///
/// This test suite verifies that the audit logging system correctly captures,
/// formats, and persists audit events for CLI operations, AWS API calls, and
/// security-sensitive events.
@Suite("Audit Logging Tests")
struct AuditingTests {

    // MARK: - AuditEvent Tests

    @Test("AuditEvent creation and serialization")
    func testAuditEventCreation() throws {
        let event = AuditEvent(
            category: .command,
            action: "upload",
            outcome: .success,
            details: .command(
                command: "upload",
                arguments: ["--profile", "test", "TestSite"],
                user: "testuser",
                workingDirectory: "/test/dir",
                relevantEnvironment: ["AWS_PROFILE": "test"],
                duration: 1.23,
                errorMessage: nil
            )
        )

        #expect(event.category == .command)
        #expect(event.action == "upload")
        #expect(event.outcome == .success)
        #expect(event.timestamp <= Date())

        // Test JSON serialization
        let encoder = JSONEncoder()
        let data = try encoder.encode(event)
        #expect(data.count > 0)

        // Test JSON deserialization
        let decoder = JSONDecoder()
        let decodedEvent = try decoder.decode(AuditEvent.self, from: data)

        #expect(decodedEvent.id == event.id)
        #expect(decodedEvent.category == event.category)
        #expect(decodedEvent.action == event.action)
        #expect(decodedEvent.outcome == event.outcome)
    }

    @Test("AuditEventDetails type safety")
    func testAuditEventDetailsTypeSafety() throws {
        // Test command details
        let commandDetails = AuditEventDetails.command(
            command: "bootstrap",
            arguments: ["--template", "landing", "MyProject"],
            user: "developer",
            workingDirectory: "/projects",
            relevantEnvironment: ["PROJECT_TYPE": "landing"]
        )

        let commandEvent = AuditEvent(
            category: .command,
            action: "bootstrap",
            outcome: .success,
            details: commandDetails
        )

        // Test AWS operation details
        let awsDetails = AuditEventDetails.awsOperation(
            operation: .s3Upload,
            resource: "s3://test-bucket/test-key",
            profile: "test",
            region: "us-west-2",
            duration: 0.5
        )

        let awsEvent = AuditEvent(
            category: .awsOperation,
            action: "s3:PutObject",
            outcome: .success,
            details: awsDetails
        )

        // Test security details
        let securityDetails = AuditEventDetails.security(
            action: "credential-access",
            resource: "profile:production",
            profile: "production",
            securityLevel: "high"
        )

        let securityEvent = AuditEvent(
            category: .security,
            action: "credential-access",
            outcome: .success,
            details: securityDetails
        )

        // Verify all events can be serialized and deserialized
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for event in [commandEvent, awsEvent, securityEvent] {
            let data = try encoder.encode(event)
            let decoded = try decoder.decode(AuditEvent.self, from: data)
            #expect(decoded.category == event.category)
        }
    }

    @Test("AWS operation classification")
    func testAWSOperationClassification() {
        // Test security-sensitive operations
        let securitySensitiveOps: [AWSOperation] = [
            .stsAssumeRole,
            .stsGetCallerIdentity,
            .iamGetUser,
            .iamListAccessKeys,
            .awsCredentialValidation,
        ]

        for operation in securitySensitiveOps {
            #expect(operation.isSecuritySensitive == true, "Operation \(operation) should be security-sensitive")
        }

        // Test non-security-sensitive operations
        let nonSecuritySensitiveOps: [AWSOperation] = [
            .s3Upload,
            .s3Download,
            .s3List,
            .cloudFrontCreateInvalidation,
        ]

        for operation in nonSecuritySensitiveOps {
            #expect(operation.isSecuritySensitive == false, "Operation \(operation) should not be security-sensitive")
        }

        // Test default service mapping
        #expect(AWSOperation.s3Upload.defaultService == "s3")
        #expect(AWSOperation.stsAssumeRole.defaultService == "sts")
        #expect(AWSOperation.iamGetUser.defaultService == "iam")
        #expect(AWSOperation.cloudFrontCreateInvalidation.defaultService == "cloudfront")
    }

    // MARK: - AuditLogger Tests

    @Test("AuditLogger file persistence")
    func testAuditLoggerFilePersistence() async throws {
        // Create temporary directory for test audit logs
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("audit-test-\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let testLogger = Logger(label: "TestAuditLogger")
        let auditLogger = AuditLogger(logger: testLogger, auditDirectory: tempDir)

        // Log a test command
        await auditLogger.logCommand(
            command: "test",
            arguments: ["--verbose"],
            user: "testuser",
            workingDirectory: "/test",
            environment: ["TEST_ENV": "true"],
            outcome: .success,
            duration: 0.1
        )

        // Log a test AWS operation
        await auditLogger.logAWSOperation(
            operation: .s3Upload,
            resource: "s3://test-bucket/test-key",
            profile: "test",
            region: "us-west-2",
            outcome: .success,
            duration: 0.5
        )

        // Verify audit file was created
        let auditFiles = try FileManager.default.contentsOfDirectory(
            at: tempDir,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "jsonl" }

        #expect(auditFiles.count == 1, "Expected exactly one audit file")

        // Verify audit file content
        let auditFile = auditFiles[0]
        let content = try String(contentsOf: auditFile)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        #expect(lines.count == 2, "Expected exactly two audit log entries")

        // Verify each line is valid JSON
        let decoder = JSONDecoder()
        for line in lines {
            let data = line.data(using: .utf8)!
            let event = try decoder.decode(AuditEvent.self, from: data)
            #expect(event.id != UUID(), "Each event should have a unique ID")
        }
    }

    @Test("AuditLogger event retrieval")
    func testAuditLoggerEventRetrieval() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("audit-test-\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let testLogger = Logger(label: "TestAuditLogger")
        let auditLogger = AuditLogger(logger: testLogger, auditDirectory: tempDir)

        let startTime = Date()

        // Log events of different categories
        await auditLogger.logCommand(
            command: "upload",
            arguments: ["TestSite"],
            outcome: .success
        )

        await auditLogger.logSecurityEvent(
            action: "credential-access",
            resource: "profile:test",
            profile: "test",
            outcome: .success
        )

        let endTime = Date()

        // Retrieve all events
        let allEvents = try await auditLogger.getAuditEvents(
            from: startTime,
            to: endTime
        )

        #expect(allEvents.count == 2, "Should retrieve all logged events")

        // Retrieve only command events
        let commandEvents = try await auditLogger.getAuditEvents(
            from: startTime,
            to: endTime,
            category: .command
        )

        #expect(commandEvents.count == 1, "Should retrieve only command events")
        #expect(commandEvents[0].category == .command)

        // Retrieve only security events
        let securityEvents = try await auditLogger.getAuditEvents(
            from: startTime,
            to: endTime,
            category: .security
        )

        #expect(securityEvents.count == 1, "Should retrieve only security events")
        #expect(securityEvents[0].category == .security)
    }

    // MARK: - CommandAuditLogger Tests

    @Test("CommandAuditLogger operation wrapping")
    func testCommandAuditLoggerOperationWrapping() async throws {
        let testLogger = Logger(label: "TestCommandAuditLogger")
        let commandLogger = CommandAuditLogger(systemLogger: testLogger)

        var operationExecuted = false
        var operationResult = "test-result"

        // Test successful operation
        let result = try await commandLogger.auditCommand(
            command: "test-command",
            arguments: ["--flag", "value"]
        ) {
            operationExecuted = true
            return operationResult
        }

        #expect(operationExecuted == true, "Operation should have been executed")
        #expect(result == operationResult, "Should return operation result")
    }

    @Test("CommandAuditLogger error handling")
    func testCommandAuditLoggerErrorHandling() async throws {
        let testLogger = Logger(label: "TestCommandAuditLogger")
        let commandLogger = CommandAuditLogger(systemLogger: testLogger)

        struct TestError: Error, LocalizedError {
            let errorDescription: String? = "Test error message"
        }

        var operationExecuted = false

        // Test failed operation
        await #expect(throws: TestError.self) {
            try await commandLogger.auditCommand(
                command: "failing-command",
                arguments: ["--will-fail"]
            ) {
                operationExecuted = true
                throw TestError()
            }
        }

        #expect(operationExecuted == true, "Operation should have been executed before failing")
    }

    @Test("CommandAuditLogger convenience methods")
    func testCommandAuditLoggerConvenienceMethods() async throws {
        let testLogger = Logger(label: "TestCommandAuditLogger")
        let commandLogger = CommandAuditLogger(systemLogger: testLogger)

        // Test upload audit
        let uploadResult = try await commandLogger.auditUpload(
            siteName: "TestSite",
            profile: "test",
            environment: "development"
        ) {
            "Upload completed"
        }

        #expect(uploadResult == "Upload completed")

        // Test bootstrap audit
        let bootstrapResult = try await commandLogger.auditBootstrap(
            projectName: "TestProject",
            template: "landing"
        ) {
            "Bootstrap completed"
        }

        #expect(bootstrapResult == "Bootstrap completed")

        // Test profile operation audit
        let profileResult = try await commandLogger.auditProfileOperation(
            subcommand: "store",
            profileName: "test"
        ) {
            "Profile stored"
        }

        #expect(profileResult == "Profile stored")
    }

    // MARK: - AWSOperationLogger Tests

    @Test("AWSOperationLogger operation wrapping")
    func testAWSOperationLoggerOperationWrapping() async throws {
        let testLogger = Logger(label: "TestAWSOperationLogger")
        let awsLogger = AWSOperationLogger(systemLogger: testLogger)

        struct MockS3Response {
            let requestId = "test-request-id"
            let data = "mock-data"
        }

        var operationExecuted = false

        // Test successful AWS operation
        let result = try await awsLogger.auditAWSOperation(
            operation: .s3Upload,
            service: "s3",
            resource: "s3://test-bucket/test-key",
            profile: "test",
            region: "us-west-2"
        ) {
            operationExecuted = true
            return MockS3Response()
        }

        #expect(operationExecuted == true, "AWS operation should have been executed")
        #expect(result.data == "mock-data", "Should return operation result")
    }

    @Test("AWSOperationLogger error handling")
    func testAWSOperationLoggerErrorHandling() async throws {
        let testLogger = Logger(label: "TestAWSOperationLogger")
        let awsLogger = AWSOperationLogger(systemLogger: testLogger)

        struct MockAWSError: Error, LocalizedError {
            let errorDescription: String? = "Access denied"
            let errorCode = "AccessDenied"
            let requestId = "test-error-request-id"
        }

        var operationExecuted = false

        // Test failed AWS operation
        await #expect(throws: MockAWSError.self) {
            try await awsLogger.auditAWSOperation(
                operation: .s3Upload,
                service: "s3",
                resource: "s3://test-bucket/test-key",
                profile: "test",
                region: "us-west-2"
            ) {
                operationExecuted = true
                throw MockAWSError()
            }
        }

        #expect(operationExecuted == true, "AWS operation should have been executed before failing")
    }

    // MARK: - Integration Tests

    @Test("End-to-end audit logging integration")
    func testEndToEndAuditLogging() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("audit-integration-test-\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let testLogger = Logger(label: "IntegrationTestLogger")
        let auditLogger = AuditLogger(logger: testLogger, auditDirectory: tempDir)
        let commandLogger = CommandAuditLogger(auditLogger: auditLogger, systemLogger: testLogger)

        let startTime = Date()

        // Simulate a complete command execution with multiple audit points
        try await commandLogger.auditCommand(
            command: "upload",
            arguments: ["--profile", "test", "TestSite"]
        ) {
            // Simulate security validation
            await commandLogger.logSecurityEvent(
                action: "profile-validation",
                resource: "profile:test",
                profile: "test",
                outcome: .success
            )

            // Simulate file operations
            await commandLogger.logFileOperation(
                operation: "scan-directory",
                path: "/test/public",
                outcome: .success
            )

            // Simulate AWS operations within the command
            let awsLogger = AWSOperationLogger(auditLogger: auditLogger, systemLogger: testLogger)

            try await awsLogger.auditAWSOperation(
                operation: .s3Upload,
                resource: "s3://test-bucket/index.html",
                profile: "test",
                region: "us-west-2"
            ) {
                // Mock S3 upload
                "Upload successful"
            }
        }

        let endTime = Date()

        // Verify all events were logged
        let allEvents = try await auditLogger.getAuditEvents(
            from: startTime,
            to: endTime
        )

        #expect(allEvents.count == 4, "Should have logged command, security, file, and AWS events")

        let categories = Set(allEvents.map { $0.category })
        let expectedCategories: Set<AuditCategory> = [.command, .security, .fileSystem, .awsOperation]
        #expect(categories == expectedCategories, "Should have events from all expected categories")

        // Verify events are chronologically ordered
        for i in 0..<(allEvents.count - 1) {
            #expect(
                allEvents[i].timestamp <= allEvents[i + 1].timestamp,
                "Events should be chronologically ordered"
            )
        }
    }

    @Test("Audit log data sanitization")
    func testAuditLogDataSanitization() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("audit-sanitization-test-\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let testLogger = Logger(label: "SanitizationTestLogger")
        let auditLogger = AuditLogger(logger: testLogger, auditDirectory: tempDir)

        // Log command with potentially sensitive arguments
        await auditLogger.logCommand(
            command: "profiles",
            arguments: [
                "store",
                "--profile", "test",
                "--access-key", "AKIATEST123456789012",  // Should be sanitized
                "--secret-key", "abcdef1234567890abcdef1234567890abcdef12",  // Should be sanitized
            ],
            environment: [
                "AWS_ACCESS_KEY_ID": "AKIATEST123456789012",  // Should be filtered out
                "AWS_SECRET_ACCESS_KEY": "secret",  // Should be filtered out
                "AWS_PROFILE": "test",  // Should be included
                "USER": "testuser",  // Should be included
            ],
            outcome: .success
        )

        // Retrieve and verify sanitization
        let events = try await auditLogger.getAuditEvents(
            from: Date().addingTimeInterval(-60),
            to: Date()
        )

        #expect(events.count == 1, "Should have one event")

        let event = events[0]
        if case .command(let details) = event.details {
            // Check argument sanitization
            let hasUnsanitizedAccessKey = details.arguments.contains { $0 == "AKIATEST123456789012" }
            let hasUnsanitizedSecretKey = details.arguments.contains {
                $0 == "abcdef1234567890abcdef1234567890abcdef12"
            }

            #expect(hasUnsanitizedAccessKey == false, "Access key should be sanitized in arguments")
            #expect(hasUnsanitizedSecretKey == false, "Secret key should be sanitized in arguments")

            // Check environment sanitization
            #expect(
                details.relevantEnvironment["AWS_ACCESS_KEY_ID"] == nil,
                "AWS credentials should not be in environment"
            )
            #expect(
                details.relevantEnvironment["AWS_SECRET_ACCESS_KEY"] == nil,
                "AWS credentials should not be in environment"
            )
            #expect(
                details.relevantEnvironment["AWS_PROFILE"] == "test",
                "Safe environment variables should be included"
            )
            #expect(details.relevantEnvironment["USER"] == "testuser", "Safe environment variables should be included")
        } else {
            #expect(Bool(false), "Event should have command details")
        }
    }
}
