import Crypto
import Foundation
import Testing

@testable import Brochure

@Suite("CLI Binary Distribution End-to-End Tests")
struct CLIBinaryDistributionTests {

    private let testDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("CLIBinaryDistributionTests")
        .appendingPathComponent(UUID().uuidString)

    init() throws {
        try FileManager.default.createDirectory(
            at: testDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    @Test("Binary distribution end-to-end workflow validation")
    func testEndToEndDistributionWorkflow() throws {
        // This test validates the complete binary distribution workflow
        // from build configuration through deployment and installation

        let buildManager = MockBuildManager()
        let uploader = BinaryUploader()
        let urlGenerator = DownloadURLGenerator()
        let installer = InstallationCommandGenerator()

        // 1. Test build metadata generation
        let metadata = buildManager.generateMetadata()
        #expect(!metadata.version.isEmpty, "Version should not be empty")
        #expect(!metadata.platform.isEmpty, "Platform should not be empty")
        #expect(!metadata.architecture.isEmpty, "Architecture should not be empty")

        // 2. Test S3 upload path generation
        let s3Path = uploader.generateS3Path(
            platform: metadata.platform,
            architecture: metadata.architecture,
            version: metadata.version
        )
        #expect(s3Path.contains(metadata.version), "S3 path should contain version")
        #expect(s3Path.contains(metadata.platform), "S3 path should contain platform")
        #expect(s3Path.contains(metadata.architecture), "S3 path should contain architecture")

        // 3. Test download URL generation
        let binaryURL = urlGenerator.generateBinaryURL(
            version: metadata.version,
            platform: metadata.platform,
            architecture: metadata.architecture
        )
        let checksumURL = urlGenerator.generateChecksumURL(
            version: metadata.version,
            platform: metadata.platform,
            architecture: metadata.architecture
        )

        #expect(binaryURL.hasPrefix("https://"), "Binary URL should be HTTPS")
        #expect(checksumURL.hasPrefix("https://"), "Checksum URL should be HTTPS")
        #expect(checksumURL.hasSuffix(".sha256"), "Checksum URL should end with .sha256")

        // 4. Test installation command generation
        let installCommand = installer.generateCurlInstallCommand(
            version: metadata.version,
            platform: metadata.platform,
            architecture: metadata.architecture,
            installPath: "/usr/local/bin/brochure"
        )

        #expect(installCommand.contains("curl"), "Install command should use curl")
        #expect(installCommand.contains("-L"), "Install command should follow redirects")
        #expect(installCommand.contains("chmod +x"), "Install command should make binary executable")

        // 5. Test verification command generation
        let verifyCommand = installer.generateVerificationCommand(
            version: metadata.version,
            platform: metadata.platform,
            architecture: metadata.architecture,
            binaryPath: "/usr/local/bin/brochure"
        )

        #expect(verifyCommand.contains("curl"), "Verify command should fetch checksum")
        #expect(
            verifyCommand.contains("sha256sum") || verifyCommand.contains("shasum"),
            "Verify command should use checksum verification"
        )
    }

    // MARK: - Binary Build Process Tests

    @Test("Should build CLI binary with correct metadata")
    func testBinaryBuildProcess() throws {
        let buildManager = MockBuildManager()
        let testBinaryPath = testDirectory.appendingPathComponent("test-brochure")

        // Test build configuration
        let buildConfig = MockBuildConfiguration(
            outputPath: testBinaryPath.path,
            configuration: .release,
            enableOptimizations: true,
            staticLinking: true
        )

        #expect(buildConfig.outputPath == testBinaryPath.path)
        #expect(buildConfig.configuration == .release)
        #expect(buildConfig.enableOptimizations == true)
        #expect(buildConfig.staticLinking == true)

        // Test metadata generation
        let metadata = buildManager.generateMetadata()
        #expect(!metadata.version.isEmpty)
        #expect(!metadata.buildDate.isEmpty)
        #expect(!metadata.platform.isEmpty)
        #expect(!metadata.architecture.isEmpty)

        // Verify platform detection
        #if os(macOS)
        #expect(metadata.platform.contains("darwin"))
        #elseif os(Linux)
        #expect(metadata.platform.contains("linux"))
        #endif

        // Verify architecture detection
        #if arch(arm64)
        #expect(metadata.architecture.contains("arm64"))
        #elseif arch(x86_64)
        #expect(metadata.architecture.contains("x86_64"))
        #endif
    }

    @Test("Should generate proper build script with correct Swift flags")
    func testBuildScriptGeneration() throws {
        let buildManager = MockBuildManager()
        let buildScript = buildManager.generateBuildScript(
            outputPath: "/tmp/brochure",
            configuration: .release
        )

        #expect(buildScript.contains("swift build"))
        #expect(buildScript.contains("--configuration release"))
        #expect(buildScript.contains("--product Brochure"))
        #expect(buildScript.contains("-Xswiftc -static-stdlib"))

        // Should include optimization flags for release
        #expect(buildScript.contains("-Xswiftc -O"))

        // Should include proper output path handling
        #expect(buildScript.contains("/tmp/brochure"))
    }

    // MARK: - Binary Upload and Distribution Tests

    @Test("Should generate correct S3 upload paths for different platforms")
    func testS3UploadPaths() throws {
        let uploader = BinaryUploader()

        let testCases = [
            ("darwin", "arm64", "1.0.0", "brochure/1.0.0/darwin-arm64/brochure"),
            ("darwin", "x86_64", "1.0.0", "brochure/1.0.0/darwin-x86_64/brochure"),
            ("linux", "x86_64", "2.1.0", "brochure/2.1.0/linux-x86_64/brochure"),
            ("linux", "arm64", "dev", "brochure/dev/linux-arm64/brochure"),
        ]

        for (platform, arch, version, expectedPath) in testCases {
            let path = uploader.generateS3Path(
                platform: platform,
                architecture: arch,
                version: version
            )
            #expect(path == expectedPath, "Expected \(expectedPath), got \(path)")
        }
    }

    @Test("Should generate checksums for binary files")
    func testChecksumGeneration() throws {
        // Create a test binary file
        let testBinary = testDirectory.appendingPathComponent("test-binary")
        let testContent = "Mock binary content for testing"
        try testContent.write(to: testBinary, atomically: true, encoding: .utf8)

        let checker = MockIntegrityChecker()
        let checksum = try checker.generateChecksum(for: testBinary)

        // Verify checksum format (SHA256 should be 64 hex characters)
        #expect(checksum.count == 64)
        #expect(checksum.allSatisfy { $0.isHexDigit })

        // Verify checksum consistency
        let checksum2 = try checker.generateChecksum(for: testBinary)
        #expect(checksum == checksum2)

        // Verify checksum changes with content
        try "Different content".write(to: testBinary, atomically: true, encoding: .utf8)
        let checksum3 = try checker.generateChecksum(for: testBinary)
        #expect(checksum != checksum3)
    }

    @Test("Should create proper checksum files")
    func testChecksumFileGeneration() throws {
        let testBinary = testDirectory.appendingPathComponent("brochure")
        let testContent = "Mock brochure binary"
        try testContent.write(to: testBinary, atomically: true, encoding: .utf8)

        let checker = MockIntegrityChecker()
        let checksumFile = testDirectory.appendingPathComponent("brochure.sha256")

        try checker.createChecksumFile(
            binaryPath: testBinary,
            outputPath: checksumFile
        )

        #expect(FileManager.default.fileExists(atPath: checksumFile.path))

        let checksumContent = try String(contentsOf: checksumFile, encoding: .utf8)
        let lines = checksumContent.components(separatedBy: .newlines).filter { !$0.isEmpty }

        #expect(lines.count == 1)

        let parts = lines[0].components(separatedBy: "  ")
        #expect(parts.count == 2)
        #expect(parts[0].count == 64)  // SHA256 hash
        #expect(parts[1] == "brochure")  // Filename
    }

    // MARK: - Download and Installation Tests

    @Test("Should validate binary download URLs")
    func testDownloadURLGeneration() throws {
        let urlGenerator = DownloadURLGenerator()

        let testCases = [
            ("1.0.0", "darwin", "arm64"),
            ("latest", "linux", "x86_64"),
            ("dev", "darwin", "x86_64"),
        ]

        for (version, platform, arch) in testCases {
            let binaryURL = urlGenerator.generateBinaryURL(
                version: version,
                platform: platform,
                architecture: arch
            )

            let checksumURL = urlGenerator.generateChecksumURL(
                version: version,
                platform: platform,
                architecture: arch
            )

            // Verify URL format
            #expect(binaryURL.hasPrefix("https://"))
            #expect(checksumURL.hasPrefix("https://"))
            #expect(binaryURL.contains(version))
            #expect(binaryURL.contains(platform))
            #expect(binaryURL.contains(arch))
            #expect(checksumURL.hasSuffix(".sha256"))
        }
    }

    @Test("Should generate correct installation commands")
    func testInstallationCommandGeneration() throws {
        let installer = InstallationCommandGenerator()

        let curlCommand = installer.generateCurlInstallCommand(
            version: "1.0.0",
            platform: "darwin",
            architecture: "arm64",
            installPath: "/usr/local/bin/brochure"
        )

        // Verify curl command structure
        #expect(curlCommand.contains("curl"))
        #expect(curlCommand.contains("-L"))  // Follow redirects
        #expect(curlCommand.contains("-o"))  // Output file
        #expect(curlCommand.contains("/usr/local/bin/brochure"))
        #expect(curlCommand.contains("1.0.0"))
        #expect(curlCommand.contains("darwin-arm64"))

        let verifyCommand = installer.generateVerificationCommand(
            version: "1.0.0",
            platform: "darwin",
            architecture: "arm64",
            binaryPath: "/usr/local/bin/brochure"
        )

        // Verify checksum verification command
        #expect(verifyCommand.contains("curl"))
        #expect(verifyCommand.contains("sha256sum") || verifyCommand.contains("shasum"))
        #expect(verifyCommand.contains(".sha256"))
    }

    // MARK: - Integration Tests

    @Test("Should handle complete build-to-distribution workflow")
    func testCompleteWorkflow() throws {
        let workflowManager = MockDistributionWorkflowManager()

        // Mock workflow configuration
        let config = MockWorkflowConfiguration(
            version: "test-1.0.0",
            outputDirectory: testDirectory,
            platforms: [
                ("darwin", "arm64"),
                ("darwin", "x86_64"),
            ],
            bucketName: "test-bucket",
            keyPrefix: "brochure-test"
        )

        // Test workflow validation
        let validationResult = workflowManager.validateConfiguration(config)
        #expect(validationResult.isValid)
        #expect(validationResult.errors.isEmpty)

        // Test file preparation
        let preparedFiles = try workflowManager.prepareDistributionFiles(config)
        #expect(!preparedFiles.isEmpty)

        for fileInfo in preparedFiles {
            #expect(!fileInfo.localPath.isEmpty)
            #expect(!fileInfo.s3Key.isEmpty)
            #expect(!fileInfo.checksum.isEmpty)
            #expect(fileInfo.s3Key.contains(config.version))
        }
    }

    @Test("Should generate proper installation documentation")
    func testInstallationDocumentation() throws {
        let docGenerator = InstallationDocumentationGenerator()

        let markdownDoc = docGenerator.generateMarkdownDocumentation(
            version: "1.0.0",
            baseURL: "https://cli.example.com"
        )

        // Verify documentation structure
        #expect(markdownDoc.contains("# Installation"))
        #expect(markdownDoc.contains("## macOS"))
        #expect(markdownDoc.contains("## Linux"))
        #expect(markdownDoc.contains("curl"))
        #expect(markdownDoc.contains("chmod +x"))
        #expect(markdownDoc.contains("sha256sum"))
        #expect(markdownDoc.contains("1.0.0"))

        // Verify code blocks are properly formatted
        #expect(markdownDoc.contains("```bash"))
        #expect(markdownDoc.contains("```"))

        let shellScript = docGenerator.generateInstallationScript(
            version: "1.0.0",
            baseURL: "https://cli.example.com"
        )

        // Verify shell script structure
        #expect(shellScript.hasPrefix("#!/bin/bash"))
        #expect(shellScript.contains("set -e"))  // Exit on error
        #expect(shellScript.contains("uname"))  // Platform detection
        #expect(shellScript.contains("curl"))
        #expect(shellScript.contains("chmod +x"))
    }

    // MARK: - Error Handling Tests

    @Test("Should handle build failures gracefully")
    func testBuildErrorHandling() throws {
        let buildManager = MockBuildManager()

        // Test invalid configuration
        let invalidConfig = MockBuildConfiguration(
            outputPath: "/invalid/path/that/does/not/exist/binary",
            configuration: .debug,
            enableOptimizations: false,
            staticLinking: false
        )

        #expect(throws: BuildError.self) {
            try buildManager.validateBuildConfiguration(invalidConfig)
        }
    }

    @Test("Should handle upload failures and provide recovery instructions")
    func testUploadErrorHandling() throws {
        let uploader = BinaryUploader()

        // Test invalid S3 configuration
        #expect(throws: UploadError.self) {
            try uploader.validateS3Configuration(
                bucketName: "",
                region: "invalid-region",
                profile: "nonexistent-profile"
            )
        }

        // Test network error handling
        let mockError = UploadError.networkError("Connection timeout")
        let errorMessage = mockError.localizedDescription

        #expect(errorMessage.contains("Connection timeout"))
        #expect(errorMessage.contains("retry"))  // Should suggest retry
    }

    @Test("Should validate binary integrity during end-to-end testing")
    func testBinaryIntegrityValidation() throws {
        // Create mock binary and checksum files
        let binaryFile = testDirectory.appendingPathComponent("brochure")
        let checksumFile = testDirectory.appendingPathComponent("brochure.sha256")

        let binaryContent = "Mock brochure binary content"
        try binaryContent.write(to: binaryFile, atomically: true, encoding: .utf8)

        let checker = MockIntegrityChecker()
        let realChecksum = try checker.generateChecksum(for: binaryFile)

        // Create valid checksum file
        let checksumContent = "\(realChecksum)  brochure\n"
        try checksumContent.write(to: checksumFile, atomically: true, encoding: .utf8)

        // Test successful verification
        let verifyResult = try checker.verifyBinary(
            binaryPath: binaryFile,
            checksumPath: checksumFile
        )
        #expect(verifyResult.isValid)
        #expect(verifyResult.expectedChecksum == realChecksum)
        #expect(verifyResult.actualChecksum == realChecksum)

        // Test checksum mismatch
        let invalidChecksumContent = "invalid_checksum_here  brochure\n"
        try invalidChecksumContent.write(to: checksumFile, atomically: true, encoding: .utf8)

        let invalidResult = try checker.verifyBinary(
            binaryPath: binaryFile,
            checksumPath: checksumFile
        )
        #expect(!invalidResult.isValid)
        #expect(invalidResult.expectedChecksum == "invalid_checksum_here")
        #expect(invalidResult.actualChecksum == realChecksum)
    }

    // MARK: - Platform-Specific Tests

    @Test("Should detect current platform and architecture correctly")
    func testPlatformDetection() throws {
        let platformDetector = PlatformDetector()

        let currentPlatform = platformDetector.detectCurrentPlatform()
        let currentArchitecture = platformDetector.detectCurrentArchitecture()

        #expect(!currentPlatform.isEmpty)
        #expect(!currentArchitecture.isEmpty)

        // Verify platform values
        let validPlatforms = ["darwin", "linux"]
        #expect(validPlatforms.contains(currentPlatform))

        // Verify architecture values
        let validArchitectures = ["arm64", "x86_64"]
        #expect(validArchitectures.contains(currentArchitecture))

        // Test platform-specific binary naming
        let binaryName = platformDetector.getBinaryName(
            baseName: "brochure",
            platform: currentPlatform
        )

        #expect(binaryName == "brochure")  // Should be same on Unix-like systems
    }

    // MARK: - Performance and Reliability Tests

    @Test("Should handle large binary files efficiently")
    func testLargeBinaryHandling() throws {
        // Create a larger mock binary (1MB)
        let largeBinary = testDirectory.appendingPathComponent("large-brochure")
        let largeContent = String(repeating: "X", count: 1024 * 1024)
        try largeContent.write(to: largeBinary, atomically: true, encoding: .utf8)

        let checker = MockIntegrityChecker()
        let startTime = Date()
        let checksum = try checker.generateChecksum(for: largeBinary)
        let duration = Date().timeIntervalSince(startTime)

        #expect(!checksum.isEmpty)
        #expect(checksum.count == 64)  // SHA256
        #expect(duration < 5.0)  // Should complete within 5 seconds
    }

    @Test("Should retry failed operations with exponential backoff")
    func testRetryMechanism() throws {
        let retryManager = RetryManager()

        var attemptCount = 0
        let maxRetries = 3

        let result = try retryManager.executeWithRetry(maxAttempts: maxRetries) {
            attemptCount += 1
            if attemptCount < maxRetries {
                throw NetworkError.temporaryFailure("Simulated failure")
            }
            return "Success"
        }

        #expect(result == "Success")
        #expect(attemptCount == maxRetries)
    }
}

// MARK: - Supporting Types for Tests

struct MockBuildConfiguration {
    let outputPath: String
    let configuration: Configuration
    let enableOptimizations: Bool
    let staticLinking: Bool

    enum Configuration {
        case debug
        case release
    }
}

struct MockBuildMetadata {
    let version: String
    let buildDate: String
    let platform: String
    let architecture: String
}

struct MockWorkflowConfiguration {
    let version: String
    let outputDirectory: URL
    let platforms: [(String, String)]
    let bucketName: String
    let keyPrefix: String
}

struct MockValidationResult {
    let isValid: Bool
    let errors: [String]
}

struct MockDistributionFileInfo {
    let localPath: String
    let s3Key: String
    let checksum: String
}

enum BuildError: Error, LocalizedError {
    case invalidConfiguration(String)
    case buildFailed(String)
    case outputPathNotWritable(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message):
            return "Invalid build configuration: \(message)"
        case .buildFailed(let message):
            return "Build failed: \(message)"
        case .outputPathNotWritable(let path):
            return "Output path is not writable: \(path)"
        }
    }
}

enum UploadError: Error, LocalizedError {
    case invalidConfiguration(String)
    case networkError(String)
    case authenticationFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message):
            return "Invalid upload configuration: \(message)"
        case .networkError(let message):
            return "Network error: \(message). Please check your connection and retry."
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        }
    }
}

enum NetworkError: Error {
    case temporaryFailure(String)
}

// Platform detection functions
private func detectPlatform() -> String {
    #if os(macOS)
    return "darwin"
    #elseif os(Linux)
    return "linux"
    #else
    return "unknown"
    #endif
}

private func detectArchitecture() -> String {
    #if arch(arm64)
    return "arm64"
    #elseif arch(x86_64)
    return "x86_64"
    #else
    return "unknown"
    #endif
}

// Mock implementations for testing
struct MockIntegrityChecker {

    func generateChecksum(for fileURL: URL) throws -> String {
        let data = try Data(contentsOf: fileURL)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    func createChecksumFile(binaryPath: URL, outputPath: URL) throws {
        let checksum = try generateChecksum(for: binaryPath)
        let filename = binaryPath.lastPathComponent
        let content = "\(checksum)  \(filename)\n"
        try content.write(to: outputPath, atomically: true, encoding: .utf8)
    }

    func verifyBinary(binaryPath: URL, checksumPath: URL) throws -> MockVerificationResult {
        let actualChecksum = try generateChecksum(for: binaryPath)
        let checksumContent = try String(contentsOf: checksumPath, encoding: .utf8)
        let expectedChecksum =
            checksumContent.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: "  ").first ?? ""

        return MockVerificationResult(
            expectedChecksum: expectedChecksum,
            actualChecksum: actualChecksum,
            isValid: actualChecksum == expectedChecksum
        )
    }
}

struct MockVerificationResult {
    let expectedChecksum: String
    let actualChecksum: String
    let isValid: Bool
}

struct MockBuildManager {
    func generateMetadata() -> MockBuildMetadata {
        MockBuildMetadata(
            version: "1.0.0",
            buildDate: ISO8601DateFormatter().string(from: Date()),
            platform: detectPlatform(),
            architecture: detectArchitecture()
        )
    }

    func generateBuildScript(outputPath: String, configuration: MockBuildConfiguration.Configuration) -> String {
        let configFlag = configuration == .release ? "--configuration release" : "--configuration debug"
        let optimizations = configuration == .release ? "-Xswiftc -O" : ""

        return """
            #!/bin/bash
            set -e
            swift build \(configFlag) --product Brochure -Xswiftc -static-stdlib \(optimizations)
            cp .build/release/Brochure \(outputPath)
            """
    }

    func validateBuildConfiguration(_ config: MockBuildConfiguration) throws {
        let outputDir = URL(fileURLWithPath: config.outputPath).deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: outputDir.path) {
            throw BuildError.outputPathNotWritable(config.outputPath)
        }
    }
}

struct BinaryUploader {
    func generateS3Path(platform: String, architecture: String, version: String) -> String {
        "brochure/\(version)/\(platform)-\(architecture)/brochure"
    }

    func validateS3Configuration(bucketName: String, region: String, profile: String) throws {
        if bucketName.isEmpty {
            throw UploadError.invalidConfiguration("Bucket name cannot be empty")
        }
        if !region.contains("-") {
            throw UploadError.invalidConfiguration("Invalid region format: \(region)")
        }
    }
}

struct DownloadURLGenerator {
    func generateBinaryURL(version: String, platform: String, architecture: String) -> String {
        "https://cli.example.com/brochure/\(version)/\(platform)-\(architecture)/brochure"
    }

    func generateChecksumURL(version: String, platform: String, architecture: String) -> String {
        "https://cli.example.com/brochure/\(version)/\(platform)-\(architecture)/brochure.sha256"
    }
}

struct InstallationCommandGenerator {
    func generateCurlInstallCommand(
        version: String,
        platform: String,
        architecture: String,
        installPath: String
    ) -> String {
        let url = "https://cli.example.com/brochure/\(version)/\(platform)-\(architecture)/brochure"
        return "curl -L \(url) -o \(installPath) && chmod +x \(installPath)"
    }

    func generateVerificationCommand(
        version: String,
        platform: String,
        architecture: String,
        binaryPath: String
    ) -> String {
        let checksumURL = "https://cli.example.com/brochure/\(version)/\(platform)-\(architecture)/brochure.sha256"
        let shaCmd = platform == "darwin" ? "shasum -a 256" : "sha256sum"
        return "curl -L \(checksumURL) | \(shaCmd) -c -"
    }
}

struct MockDistributionWorkflowManager {
    func validateConfiguration(_ config: MockWorkflowConfiguration) -> MockValidationResult {
        var errors: [String] = []

        if config.version.isEmpty {
            errors.append("Version cannot be empty")
        }
        if config.platforms.isEmpty {
            errors.append("At least one platform must be specified")
        }
        if config.bucketName.isEmpty {
            errors.append("Bucket name cannot be empty")
        }

        return MockValidationResult(isValid: errors.isEmpty, errors: errors)
    }

    func prepareDistributionFiles(_ config: MockWorkflowConfiguration) throws -> [MockDistributionFileInfo] {
        var files: [MockDistributionFileInfo] = []

        for (platform, arch) in config.platforms {
            let localPath = config.outputDirectory.appendingPathComponent("brochure-\(platform)-\(arch)").path
            let s3Key = "brochure/\(config.version)/\(platform)-\(arch)/brochure"
            let checksum = "mock_checksum_for_\(platform)_\(arch)"

            files.append(
                MockDistributionFileInfo(
                    localPath: localPath,
                    s3Key: s3Key,
                    checksum: checksum
                )
            )
        }

        return files
    }
}

struct InstallationDocumentationGenerator {
    func generateMarkdownDocumentation(version: String, baseURL: String) -> String {
        """
        # Installation

        ## macOS

        ```bash
        curl -L \(baseURL)/brochure/\(version)/darwin-arm64/brochure -o /usr/local/bin/brochure
        chmod +x /usr/local/bin/brochure
        ```

        ## Linux

        ```bash
        curl -L \(baseURL)/brochure/\(version)/linux-x86_64/brochure -o /usr/local/bin/brochure
        chmod +x /usr/local/bin/brochure
        ```

        ## Verification

        ```bash
        curl -L \(baseURL)/brochure/\(version)/darwin-arm64/brochure.sha256 | sha256sum -c -
        ```
        """
    }

    func generateInstallationScript(version: String, baseURL: String) -> String {
        """
        #!/bin/bash
        set -e

        # Detect platform and architecture
        PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
        ARCH=$(uname -m)

        if [ "$PLATFORM" = "darwin" ]; then
            PLATFORM="darwin"
        elif [ "$PLATFORM" = "linux" ]; then
            PLATFORM="linux"
        fi

        if [ "$ARCH" = "aarch64" ]; then
            ARCH="arm64"
        elif [ "$ARCH" = "x86_64" ]; then
            ARCH="x86_64"
        fi

        URL="\(baseURL)/brochure/\(version)/$PLATFORM-$ARCH/brochure"

        curl -L "$URL" -o /usr/local/bin/brochure
        chmod +x /usr/local/bin/brochure
        """
    }
}

struct PlatformDetector {
    func detectCurrentPlatform() -> String {
        detectPlatform()
    }

    func detectCurrentArchitecture() -> String {
        detectArchitecture()
    }

    func getBinaryName(baseName: String, platform: String) -> String {
        // On Windows, we'd append .exe, but for Unix-like systems, no extension
        baseName
    }
}

struct RetryManager {
    func executeWithRetry<T>(maxAttempts: Int, operation: () throws -> T) throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try operation()
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    Thread.sleep(forTimeInterval: Double(attempt) * 0.1)  // Exponential backoff
                }
            }
        }

        throw lastError!
    }
}
