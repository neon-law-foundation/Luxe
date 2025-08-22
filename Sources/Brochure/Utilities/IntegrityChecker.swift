import Crypto
import Foundation
import Logging

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Provides binary integrity checking functionality using SHA256 checksums.
///
/// `IntegrityChecker` enables verification of downloaded binaries against their published
/// SHA256 checksums to ensure integrity and authenticity. It supports both local file
/// verification and remote checksum validation.
///
/// ## Key Features
///
/// - **SHA256 Verification**: Compare local files against expected checksums
/// - **Remote Checksum Fetching**: Download and verify checksums from URLs
/// - **Batch Verification**: Verify multiple files simultaneously
/// - **Detailed Reporting**: Comprehensive verification results with error details
/// - **Progress Tracking**: Real-time verification progress for large operations
///
/// ## Example Usage
///
/// ```swift
/// let checker = IntegrityChecker()
///
/// // Verify a local binary against a checksum file
/// let result = try await checker.verifyFile(
///     binaryPath: "/usr/local/bin/brochure",
///     checksumPath: "/tmp/brochure.sha256"
/// )
///
/// // Verify against a remote checksum
/// let remoteResult = try await checker.verifyFileAgainstRemoteChecksum(
///     binaryPath: "/usr/local/bin/brochure",
///     checksumURL: "https://cli.neonlaw.com/brochure/latest/darwin-arm64/brochure.sha256"
/// )
/// ```
public struct IntegrityChecker {
    private let logger: Logger
    private let urlSession: URLSession

    /// Creates a new integrity checker instance.
    ///
    /// - Parameters:
    ///   - urlSession: URL session for remote checksum downloads (defaults to shared session)
    ///   - logger: Logger instance for verification progress and results
    public init(urlSession: URLSession = .shared, logger: Logger? = nil) {
        self.urlSession = urlSession
        self.logger = logger ?? Logger(label: "IntegrityChecker")
    }

    /// Verifies a file against a local checksum file.
    ///
    /// - Parameters:
    ///   - binaryPath: Path to the binary file to verify
    ///   - checksumPath: Path to the checksum file containing the expected SHA256
    ///
    /// - Returns: Verification result with success status and details
    /// - Throws: `IntegrityError` if verification fails or files cannot be read
    ///
    /// ## Example
    ///
    /// ```swift
    /// let result = try await checker.verifyFile(
    ///     binaryPath: "/usr/local/bin/brochure",
    ///     checksumPath: "/tmp/brochure.sha256"
    /// )
    ///
    /// if result.isValid {
    ///     print("✅ Binary integrity verified")
    /// } else {
    ///     print("❌ Integrity check failed: \(result.errorMessage ?? "Unknown error")")
    /// }
    /// ```
    public func verifyFile(binaryPath: String, checksumPath: String) async throws -> VerificationResult {
        logger.info("Verifying binary integrity: \(binaryPath)")

        // Read expected checksum
        guard
            let checksumContent = try? String(contentsOfFile: checksumPath, encoding: .utf8),
            let expectedChecksum =
                checksumContent
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .whitespaces).first,
            !expectedChecksum.isEmpty,
            expectedChecksum.allSatisfy({ $0.isHexDigit }),
            expectedChecksum.count == 64  // SHA256 is 64 hex characters
        else {
            throw IntegrityError.invalidChecksumFile(checksumPath)
        }

        // Calculate actual checksum
        let actualChecksum = try calculateSHA256(for: binaryPath)

        // Compare checksums
        let isValid = actualChecksum.lowercased() == expectedChecksum.lowercased()

        let result = VerificationResult(
            binaryPath: binaryPath,
            expectedChecksum: expectedChecksum,
            actualChecksum: actualChecksum,
            isValid: isValid,
            verificationMethod: .localFile(checksumPath)
        )

        if isValid {
            logger.info("✅ Binary integrity verified: \(binaryPath)")
        } else {
            logger.warning("❌ Binary integrity check failed: \(binaryPath)")
            logger.warning("   Expected: \(expectedChecksum)")
            logger.warning("   Actual:   \(actualChecksum)")
        }

        return result
    }

    /// Verifies a file against a remote checksum URL.
    ///
    /// - Parameters:
    ///   - binaryPath: Path to the binary file to verify
    ///   - checksumURL: URL to download the expected checksum from
    ///
    /// - Returns: Verification result with success status and details
    /// - Throws: `IntegrityError` if verification fails or checksum cannot be downloaded
    ///
    /// ## Example
    ///
    /// ```swift
    /// let result = try await checker.verifyFileAgainstRemoteChecksum(
    ///     binaryPath: "/usr/local/bin/brochure",
    ///     checksumURL: "https://cli.neonlaw.com/brochure/latest/darwin-arm64/brochure.sha256"
    /// )
    /// ```
    public func verifyFileAgainstRemoteChecksum(
        binaryPath: String,
        checksumURL: String
    ) async throws -> VerificationResult {
        logger.info("Verifying binary against remote checksum: \(checksumURL)")

        // Download checksum
        guard let url = URL(string: checksumURL) else {
            throw IntegrityError.invalidURL(checksumURL)
        }

        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw IntegrityError.checksumDownloadFailed(checksumURL, response)
        }

        guard
            let checksumContent = String(data: data, encoding: .utf8),
            let expectedChecksum =
                checksumContent
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .whitespaces).first,
            !expectedChecksum.isEmpty,
            expectedChecksum.allSatisfy({ $0.isHexDigit }),
            expectedChecksum.count == 64  // SHA256 is 64 hex characters
        else {
            throw IntegrityError.invalidRemoteChecksum(checksumURL)
        }

        // Calculate actual checksum
        let actualChecksum = try calculateSHA256(for: binaryPath)

        // Compare checksums
        let isValid = actualChecksum.lowercased() == expectedChecksum.lowercased()

        let result = VerificationResult(
            binaryPath: binaryPath,
            expectedChecksum: expectedChecksum,
            actualChecksum: actualChecksum,
            isValid: isValid,
            verificationMethod: .remoteURL(checksumURL)
        )

        if isValid {
            logger.info("✅ Binary integrity verified against remote checksum")
        } else {
            logger.warning("❌ Binary integrity check failed against remote checksum")
            logger.warning("   Expected: \(expectedChecksum)")
            logger.warning("   Actual:   \(actualChecksum)")
        }

        return result
    }

    /// Verifies multiple files in batch.
    ///
    /// - Parameter verifications: Array of verification requests to process
    /// - Returns: Array of verification results in the same order as input
    ///
    /// ## Example
    ///
    /// ```swift
    /// let verifications = [
    ///     BatchVerificationRequest(
    ///         binaryPath: "/usr/local/bin/brochure",
    ///         method: .localFile("/tmp/brochure.sha256")
    ///     ),
    ///     BatchVerificationRequest(
    ///         binaryPath: "/usr/local/bin/other-tool",
    ///         method: .remoteURL("https://example.com/other-tool.sha256")
    ///     )
    /// ]
    ///
    /// let results = try await checker.verifyBatch(verifications)
    /// ```
    public func verifyBatch(_ verifications: [BatchVerificationRequest]) async throws -> [VerificationResult] {
        logger.info("Starting batch verification of \(verifications.count) files")

        var results: [VerificationResult] = []

        for verification in verifications {
            do {
                let result: VerificationResult

                switch verification.method {
                case .localFile(let checksumPath):
                    result = try await verifyFile(
                        binaryPath: verification.binaryPath,
                        checksumPath: checksumPath
                    )

                case .remoteURL(let checksumURL):
                    result = try await verifyFileAgainstRemoteChecksum(
                        binaryPath: verification.binaryPath,
                        checksumURL: checksumURL
                    )
                }

                results.append(result)

            } catch {
                // Create a failed result for this verification
                let failedResult = VerificationResult(
                    binaryPath: verification.binaryPath,
                    expectedChecksum: "unknown",
                    actualChecksum: "unknown",
                    isValid: false,
                    verificationMethod: verification.method,
                    errorMessage: error.localizedDescription
                )

                results.append(failedResult)
                logger.error("Batch verification failed for \(verification.binaryPath): \(error)")
            }
        }

        let successCount = results.filter { $0.isValid }.count
        logger.info("Batch verification completed: \(successCount)/\(results.count) files verified successfully")

        return results
    }

    /// Downloads a file and verifies its integrity in one operation.
    ///
    /// - Parameters:
    ///   - downloadURL: URL to download the binary from
    ///   - checksumURL: URL to download the checksum from
    ///   - destinationPath: Local path to save the downloaded binary
    ///
    /// - Returns: Verification result after download and verification
    /// - Throws: `IntegrityError` if download or verification fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// let result = try await checker.downloadAndVerify(
    ///     downloadURL: "https://cli.neonlaw.com/brochure/latest/darwin-arm64/brochure",
    ///     checksumURL: "https://cli.neonlaw.com/brochure/latest/darwin-arm64/brochure.sha256",
    ///     destinationPath: "/tmp/brochure"
    /// )
    /// ```
    public func downloadAndVerify(
        downloadURL: String,
        checksumURL: String,
        destinationPath: String
    ) async throws -> VerificationResult {
        logger.info("Downloading and verifying binary: \(downloadURL)")

        // Download binary
        guard let binaryURL = URL(string: downloadURL) else {
            throw IntegrityError.invalidURL(downloadURL)
        }

        let (binaryData, binaryResponse) = try await urlSession.data(from: binaryURL)

        guard let httpResponse = binaryResponse as? HTTPURLResponse,
            httpResponse.statusCode == 200
        else {
            throw IntegrityError.downloadFailed(downloadURL, binaryResponse)
        }

        // Save binary to destination
        try binaryData.write(to: URL(fileURLWithPath: destinationPath))
        logger.info("Binary downloaded to: \(destinationPath)")

        // Verify integrity
        let result = try await verifyFileAgainstRemoteChecksum(
            binaryPath: destinationPath,
            checksumURL: checksumURL
        )

        if result.isValid {
            logger.info("✅ Downloaded binary integrity verified")
        } else {
            logger.warning("❌ Downloaded binary failed integrity check")
            // Clean up invalid file
            try? FileManager.default.removeItem(atPath: destinationPath)
        }

        return result
    }

    /// Calculates SHA256 checksum for a file.
    ///
    /// - Parameter filePath: Path to the file to calculate checksum for
    /// - Returns: Hexadecimal SHA256 checksum string
    /// - Throws: `IntegrityError` if file cannot be read
    private func calculateSHA256(for filePath: String) throws -> String {
        guard let data = FileManager.default.contents(atPath: filePath) else {
            throw IntegrityError.fileNotFound(filePath)
        }

        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

/// Result of a binary integrity verification operation.
public struct VerificationResult: Sendable {
    /// Path to the binary file that was verified
    public let binaryPath: String

    /// Expected SHA256 checksum
    public let expectedChecksum: String

    /// Actual calculated SHA256 checksum
    public let actualChecksum: String

    /// Whether the verification was successful
    public let isValid: Bool

    /// Method used for verification
    public let verificationMethod: VerificationMethod

    /// Error message if verification failed
    public let errorMessage: String?

    /// Timestamp when verification was performed
    public let verificationTime: Date

    public init(
        binaryPath: String,
        expectedChecksum: String,
        actualChecksum: String,
        isValid: Bool,
        verificationMethod: VerificationMethod,
        errorMessage: String? = nil
    ) {
        self.binaryPath = binaryPath
        self.expectedChecksum = expectedChecksum
        self.actualChecksum = actualChecksum
        self.isValid = isValid
        self.verificationMethod = verificationMethod
        self.errorMessage = errorMessage
        self.verificationTime = Date()
    }
}

/// Method used for binary verification.
public enum VerificationMethod: Sendable {
    /// Verification using a local checksum file
    case localFile(String)

    /// Verification using a remote checksum URL
    case remoteURL(String)

    public var description: String {
        switch self {
        case .localFile(let path):
            return "Local file: \(path)"
        case .remoteURL(let url):
            return "Remote URL: \(url)"
        }
    }
}

/// Request for batch verification operation.
public struct BatchVerificationRequest: Sendable {
    /// Path to the binary file to verify
    public let binaryPath: String

    /// Verification method to use
    public let method: VerificationMethod

    public init(binaryPath: String, method: VerificationMethod) {
        self.binaryPath = binaryPath
        self.method = method
    }
}

/// Errors that can occur during integrity checking operations.
public enum IntegrityError: Error, LocalizedError, Sendable {
    case fileNotFound(String)
    case invalidChecksumFile(String)
    case invalidURL(String)
    case checksumDownloadFailed(String, URLResponse?)
    case downloadFailed(String, URLResponse?)
    case invalidRemoteChecksum(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .invalidChecksumFile(let path):
            return "Invalid checksum file: \(path)"
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .checksumDownloadFailed(let url, let response):
            if let httpResponse = response as? HTTPURLResponse {
                return "Failed to download checksum from \(url) (HTTP \(httpResponse.statusCode))"
            }
            return "Failed to download checksum from \(url)"
        case .downloadFailed(let url, let response):
            if let httpResponse = response as? HTTPURLResponse {
                return "Failed to download binary from \(url) (HTTP \(httpResponse.statusCode))"
            }
            return "Failed to download binary from \(url)"
        case .invalidRemoteChecksum(let url):
            return "Invalid checksum format from remote URL: \(url)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .fileNotFound(let path):
            return "Ensure the file exists at \(path) and is readable"
        case .invalidChecksumFile(let path):
            return "Ensure \(path) contains a valid SHA256 checksum"
        case .invalidURL(let url):
            return "Check that the URL is properly formatted: \(url)"
        case .checksumDownloadFailed(let url, _):
            return "Check network connectivity and that the checksum is available at \(url)"
        case .downloadFailed(let url, _):
            return "Check network connectivity and that the binary is available at \(url)"
        case .invalidRemoteChecksum(let url):
            return "Ensure the remote checksum at \(url) is in the correct format"
        }
    }
}
