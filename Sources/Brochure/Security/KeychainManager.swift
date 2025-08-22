import Foundation
import Logging

#if canImport(Security)
import Security
#endif

/// Secure credential management with cross-platform support.
///
/// `KeychainManager` provides secure storage and retrieval of AWS credentials and other sensitive
/// data. On macOS, it uses the system keychain for maximum security. On Linux, it provides
/// a fallback implementation with appropriate warnings.
///
/// ## Key Features
///
/// - **Encrypted Storage**: Credentials stored using system keychain (macOS) or secure fallback (Linux)
/// - **Cross-Platform**: Works on both macOS and Linux with appropriate security measures
/// - **Profile Support**: Store multiple AWS profiles securely
/// - **Audit Trail**: Comprehensive logging of all credential operations
///
/// ## Usage Examples
///
/// ```swift
/// let keychain = KeychainManager()
///
/// // Store AWS credentials securely
/// try await keychain.storeAWSCredentials(
///     profile: "production",
///     accessKeyId: "AKIA...",
///     secretAccessKey: "secret...",
///     sessionToken: "token..." // optional
/// )
///
/// // Retrieve credentials
/// let credentials = try await keychain.getAWSCredentials(profile: "production")
/// print("Access Key: \(credentials.accessKeyId)")
/// ```
///
/// ## Security Considerations
///
/// - **macOS**: Credentials encrypted by system keychain with access control
/// - **Linux**: Credentials stored in protected directory with file permissions
/// - Never stores credentials in memory longer than necessary
/// - Comprehensive audit logging for security compliance
public actor KeychainManager {
    private let servicePrefix = "com.neonlaw.brochure"
    private let logger: Logger

    #if !canImport(Security)
    // Linux fallback: secure directory for credential storage
    private let credentialsDirectory: URL
    #endif

    /// Initializes the keychain manager with logging support.
    ///
    /// - Parameter logger: Logger for security audit trail
    public init(logger: Logger = Logger(label: "KeychainManager")) {
        self.logger = logger

        #if canImport(Security)
        logger.debug("🔐 KeychainManager initialized with macOS Keychain support")
        #else
        // Linux fallback: create secure credentials directory
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        self.credentialsDirectory = homeDirectory.appendingPathComponent(".brochure/credentials")

        do {
            try FileManager.default.createDirectory(at: credentialsDirectory, withIntermediateDirectories: true)
            // Set secure permissions (owner read/write only)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: credentialsDirectory.path)
            logger.debug("🔐 KeychainManager initialized with Linux file-based storage at: \(credentialsDirectory.path)")
            logger.warning("⚠️ Using file-based credential storage on Linux - ensure proper file system encryption")
        } catch {
            logger.error("❌ Failed to create secure credentials directory: \(error)")
        }
        #endif
    }

    /// Stores AWS credentials securely in the keychain.
    ///
    /// - Parameters:
    ///   - profile: AWS profile name (e.g., "production", "staging")
    ///   - accessKeyId: AWS access key ID
    ///   - secretAccessKey: AWS secret access key
    ///   - sessionToken: Optional session token for temporary credentials
    ///   - region: Optional default region for the profile
    /// - Throws: `KeychainError` if storage fails
    public func storeAWSCredentials(
        profile: String,
        accessKeyId: String,
        secretAccessKey: String,
        sessionToken: String? = nil,
        region: String? = nil
    ) throws {
        logger.info("🔐 Storing AWS credentials for profile: \(profile)")

        let credentials = AWSCredentials(
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey,
            sessionToken: sessionToken,
            region: region,
            storedAt: Date()
        )

        let data = try JSONEncoder().encode(credentials)

        #if canImport(Security)
        let account = "\(servicePrefix).aws.\(profile)"
        try storeSecureData(data, account: account, service: "aws-credentials")
        #else
        try storeLinuxCredentials(data: data, profile: profile)
        #endif

        logger.info("✅ Successfully stored AWS credentials for profile: \(profile)")
        logger.debug("📊 Credential metadata: region=\(region ?? "none"), sessionToken=\(sessionToken != nil)")
    }

    /// Retrieves AWS credentials from the keychain.
    ///
    /// - Parameter profile: AWS profile name
    /// - Returns: AWS credentials if found
    /// - Throws: `KeychainError` if retrieval fails or credentials not found
    public func getAWSCredentials(profile: String) throws -> AWSCredentials {
        logger.debug("🔍 Retrieving AWS credentials for profile: \(profile)")

        let data: Data
        #if canImport(Security)
        let account = "\(servicePrefix).aws.\(profile)"
        data = try getSecureData(account: account, service: "aws-credentials")
        #else
        data = try getLinuxCredentials(profile: profile)
        #endif

        let credentials = try JSONDecoder().decode(AWSCredentials.self, from: data)

        logger.info("✅ Successfully retrieved AWS credentials for profile: \(profile)")
        logger.debug("📊 Credential age: \(String(format: "%.1f", Date().timeIntervalSince(credentials.storedAt)))s")

        return credentials
    }

    /// Removes AWS credentials from the keychain.
    ///
    /// - Parameter profile: AWS profile name
    /// - Throws: `KeychainError` if deletion fails
    public func removeAWSCredentials(profile: String) throws {
        logger.info("🗑️ Removing AWS credentials for profile: \(profile)")

        #if canImport(Security)
        let account = "\(servicePrefix).aws.\(profile)"
        try deleteSecureData(account: account, service: "aws-credentials")
        #else
        try removeLinuxCredentials(profile: profile)
        #endif

        logger.info("✅ Successfully removed AWS credentials for profile: \(profile)")
    }

    /// Lists all AWS profiles stored in the keychain.
    ///
    /// - Returns: Array of profile names
    public func listAWSProfiles() throws -> [String] {
        logger.debug("📋 Listing all AWS profiles in keychain")

        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "aws-credentials",
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
        ]

        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                logger.debug("📋 No AWS profiles found in keychain")
                return []
            }
            throw KeychainError.retrievalFailed(status)
        }

        guard let itemsArray = items as? [[String: Any]] else {
            throw KeychainError.invalidData("Failed to parse keychain items")
        }

        let profiles = itemsArray.compactMap { item -> String? in
            guard let account = item[kSecAttrAccount as String] as? String else { return nil }
            let prefix = "\(servicePrefix).aws."
            guard account.hasPrefix(prefix) else { return nil }
            return String(account.dropFirst(prefix.count))
        }

        logger.info("📋 Found \(profiles.count) AWS profiles in keychain: \(profiles.joined(separator: ", "))")
        return profiles.sorted()
        #else
        let profiles = try listLinuxAWSProfiles()
        logger.info("📋 Found \(profiles.count) AWS profiles in storage: \(profiles.joined(separator: ", "))")
        return profiles.sorted()
        #endif
    }

    /// Stores sensitive configuration data in the keychain.
    ///
    /// - Parameters:
    ///   - key: Configuration key (e.g., "default-region", "mfa-device")
    ///   - value: Configuration value
    /// - Throws: `KeychainError` if storage fails
    public func storeConfiguration(key: String, value: String) throws {
        logger.debug("🔧 Storing configuration: \(key)")

        let data = value.data(using: .utf8) ?? Data()

        #if canImport(Security)
        let account = "\(servicePrefix).config.\(key)"
        try storeSecureData(data, account: account, service: "brochure-config")
        #else
        try storeLinuxConfiguration(key: key, data: data)
        #endif

        logger.debug("✅ Successfully stored configuration: \(key)")
    }

    /// Retrieves configuration data from the keychain.
    ///
    /// - Parameter key: Configuration key
    /// - Returns: Configuration value if found
    /// - Throws: `KeychainError` if retrieval fails
    public func getConfiguration(key: String) throws -> String? {
        logger.debug("🔍 Retrieving configuration: \(key)")

        #if canImport(Security)
        let account = "\(servicePrefix).config.\(key)"

        do {
            let data = try getSecureData(account: account, service: "brochure-config")
            let value = String(data: data, encoding: .utf8)
            logger.debug("✅ Successfully retrieved configuration: \(key)")
            return value
        } catch KeychainError.itemNotFound {
            logger.debug("📭 Configuration not found: \(key)")
            return nil
        }
        #else
        do {
            let data = try getLinuxConfiguration(key: key)
            let value = String(data: data, encoding: .utf8)
            logger.debug("✅ Successfully retrieved configuration: \(key)")
            return value
        } catch KeychainError.itemNotFound {
            logger.debug("📭 Configuration not found: \(key)")
            return nil
        }
        #endif
    }

    /// Removes configuration from the keychain.
    ///
    /// - Parameter key: Configuration key
    /// - Throws: `KeychainError` if deletion fails
    public func removeConfiguration(key: String) throws {
        logger.debug("🗑️ Removing configuration: \(key)")

        #if canImport(Security)
        let account = "\(servicePrefix).config.\(key)"
        try deleteSecureData(account: account, service: "brochure-config")
        #else
        try removeLinuxConfiguration(key: key)
        #endif

        logger.debug("✅ Successfully removed configuration: \(key)")
    }

    /// Clears all Brochure data from the keychain.
    ///
    /// **⚠️ Warning**: This permanently removes all stored credentials and configuration.
    /// Use with extreme caution.
    public func clearAllData() throws {
        logger.warning("🧹 Clearing all Brochure data from keychain")

        #if canImport(Security)
        let services = ["aws-credentials", "brochure-config"]
        var removedCount = 0

        for service in services {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
            ]

            let status = SecItemDelete(query as CFDictionary)
            if status == errSecSuccess {
                removedCount += 1
                logger.debug("✅ Cleared service: \(service)")
            } else if status != errSecItemNotFound {
                logger.warning("⚠️ Failed to clear service \(service): \(status)")
            }
        }

        logger.warning("🧹 Cleared \(removedCount) service categories from keychain")
        #else
        try clearLinuxData()
        logger.warning("🧹 Cleared all data from Linux storage")
        #endif
    }

    // MARK: - Private Implementation

    #if canImport(Security)
    private func storeSecureData(_ data: Data, account: String, service: String) throws {
        // First, try to update existing item
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrModificationDate as String: Date(),
        ]

        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecSuccess {
            logger.debug("✅ Updated existing keychain item: \(account)")
            return
        }

        if updateStatus != errSecItemNotFound {
            throw KeychainError.storageFailed(updateStatus)
        }

        // Item doesn't exist, create new one
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecAttrSynchronizable as String: false,  // Never sync to iCloud for security
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.storageFailed(addStatus)
        }

        logger.debug("✅ Created new keychain item: \(account)")
    }

    private func getSecureData(account: String, service: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound(account)
            }
            throw KeychainError.retrievalFailed(status)
        }

        guard let data = item as? Data else {
            throw KeychainError.invalidData("Failed to cast keychain data")
        }

        return data
    }

    private func deleteSecureData(account: String, service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deletionFailed(status)
        }
    }
    #endif

    // MARK: - Linux Implementation

    #if !canImport(Security)
    private func storeLinuxCredentials(data: Data, profile: String) throws {
        let fileURL = credentialsDirectory.appendingPathComponent("aws-\(profile).json")

        do {
            try data.write(to: fileURL, options: [.atomic])
            // Set secure file permissions (owner read/write only)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            logger.debug("✅ Stored Linux credentials file: \(fileURL.path)")
        } catch {
            throw KeychainError.storageFailed(-1)
        }
    }

    private func getLinuxCredentials(profile: String) throws -> Data {
        let fileURL = credentialsDirectory.appendingPathComponent("aws-\(profile).json")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw KeychainError.itemNotFound("aws-\(profile)")
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return data
        } catch {
            throw KeychainError.retrievalFailed(-1)
        }
    }

    private func removeLinuxCredentials(profile: String) throws {
        let fileURL = credentialsDirectory.appendingPathComponent("aws-\(profile).json")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // File doesn't exist, consider it successfully removed
            return
        }

        do {
            try FileManager.default.removeItem(at: fileURL)
            logger.debug("✅ Removed Linux credentials file: \(fileURL.path)")
        } catch {
            throw KeychainError.deletionFailed(-1)
        }
    }

    private func listLinuxAWSProfiles() throws -> [String] {
        guard FileManager.default.fileExists(atPath: credentialsDirectory.path) else {
            return []
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: credentialsDirectory.path)
            let profiles = files.compactMap { filename -> String? in
                guard filename.hasPrefix("aws-") && filename.hasSuffix(".json") else {
                    return nil
                }
                let startIndex = filename.index(filename.startIndex, offsetBy: 4)  // "aws-".count
                let endIndex = filename.index(filename.endIndex, offsetBy: -5)  // ".json".count
                return String(filename[startIndex..<endIndex])
            }
            return profiles
        } catch {
            throw KeychainError.retrievalFailed(-1)
        }
    }

    private func storeLinuxConfiguration(key: String, data: Data) throws {
        let fileURL = credentialsDirectory.appendingPathComponent("config-\(key).json")

        do {
            try data.write(to: fileURL, options: [.atomic])
            // Set secure file permissions (owner read/write only)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
            logger.debug("✅ Stored Linux configuration file: \(fileURL.path)")
        } catch {
            throw KeychainError.storageFailed(-1)
        }
    }

    private func getLinuxConfiguration(key: String) throws -> Data {
        let fileURL = credentialsDirectory.appendingPathComponent("config-\(key).json")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw KeychainError.itemNotFound("config-\(key)")
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return data
        } catch {
            throw KeychainError.retrievalFailed(-1)
        }
    }

    private func removeLinuxConfiguration(key: String) throws {
        let fileURL = credentialsDirectory.appendingPathComponent("config-\(key).json")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            // File doesn't exist, consider it successfully removed
            return
        }

        do {
            try FileManager.default.removeItem(at: fileURL)
            logger.debug("✅ Removed Linux configuration file: \(fileURL.path)")
        } catch {
            throw KeychainError.deletionFailed(-1)
        }
    }

    private func clearLinuxData() throws {
        guard FileManager.default.fileExists(atPath: credentialsDirectory.path) else {
            return
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: credentialsDirectory.path)
            for filename in files {
                if filename.hasPrefix("aws-") || filename.hasPrefix("config-") {
                    let fileURL = credentialsDirectory.appendingPathComponent(filename)
                    try FileManager.default.removeItem(at: fileURL)
                    logger.debug("✅ Removed Linux file: \(fileURL.path)")
                }
            }
        } catch {
            throw KeychainError.deletionFailed(-1)
        }
    }
    #endif
}

// MARK: - Supporting Types

/// AWS credentials stored securely in the keychain.
public struct AWSCredentials: Codable, Sendable {
    public let accessKeyId: String
    public let secretAccessKey: String
    public let sessionToken: String?
    public let region: String?
    public let storedAt: Date

    /// Checks if the credentials include temporary session tokens.
    public var isTemporary: Bool {
        sessionToken != nil
    }

    /// Age of the stored credentials in seconds.
    public var age: TimeInterval {
        Date().timeIntervalSince(storedAt)
    }

    /// Checks if temporary credentials might be expired (1 hour threshold).
    public var isPotentiallyExpired: Bool {
        isTemporary && age > 3600  // 1 hour
    }
}

/// Errors that can occur during keychain operations.
public enum KeychainError: Error, LocalizedError, Equatable {
    #if canImport(Security)
    case storageFailed(OSStatus)
    case retrievalFailed(OSStatus)
    case deletionFailed(OSStatus)
    #else
    case storageFailed(Int)
    case retrievalFailed(Int)
    case deletionFailed(Int)
    #endif
    case itemNotFound(String)
    case invalidData(String)
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .storageFailed(let status):
            return "Failed to store data in keychain (status: \(status))"
        case .retrievalFailed(let status):
            return "Failed to retrieve data from keychain (status: \(status))"
        case .deletionFailed(let status):
            return "Failed to delete data from keychain (status: \(status))"
        case .itemNotFound(let account):
            return "Keychain item not found: \(account)"
        case .invalidData(let reason):
            return "Invalid keychain data: \(reason)"
        case .encodingFailed:
            return "Failed to encode data for keychain storage"
        }
    }

    public var userFriendlyDescription: String {
        switch self {
        case .storageFailed, .encodingFailed:
            return """
                Failed to securely store credentials.

                Possible solutions:
                1. Ensure your keychain is unlocked
                2. Check available disk space
                3. Verify keychain permissions
                """

        case .retrievalFailed:
            return """
                Failed to retrieve stored credentials.

                Possible solutions:
                1. Unlock your keychain if prompted
                2. Verify the profile exists with 'brochure profiles list'
                3. Check keychain access permissions
                """

        case .itemNotFound:
            return """
                No credentials found for the specified profile.

                Store credentials first using:
                brochure profiles store --profile <name> --access-key <key> --secret-key <secret>
                """

        case .invalidData:
            return """
                Stored credential data is corrupted or invalid.

                Try removing and re-storing the credentials:
                brochure profiles remove --profile <name>
                brochure profiles store --profile <name> --access-key <key> --secret-key <secret>
                """

        case .deletionFailed:
            return """
                Failed to remove credentials from secure storage.

                You may need to manually remove them using Keychain Access.app
                """
        }
    }
}
