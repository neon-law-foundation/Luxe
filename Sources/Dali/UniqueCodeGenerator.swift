import Foundation

/// Utility for generating unique codes with timestamps
public struct UniqueCodeGenerator {

    /// Generates a unique code with ISO timestamp and UUID suffix
    /// Format: prefix_YYYYMMDDTHHMMSSZ_uuid8chars
    /// Example: terms_agreement_20250712T171557Z_a1b2c3d4
    public static func generateISOCode(prefix: String = "code") -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        let timestamp = dateFormatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "T", with: "")
            .replacingOccurrences(of: "Z", with: "")

        let uuidSuffix = UUID().uuidString.prefix(8)
        return "\(prefix)_\(timestamp)_\(uuidSuffix)"
    }

    /// Generates a unique code with compact timestamp (YYYYMMDDHHMMSS) and UUID suffix
    /// Format: prefix_YYYYMMDDHHMMSS_uuid8chars
    /// Example: terms_agreement_20250712171557_a1b2c3d4
    public static func generateCompactCode(prefix: String = "code") -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let timestamp = dateFormatter.string(from: Date())

        let uuidSuffix = UUID().uuidString.prefix(8)
        return "\(prefix)_\(timestamp)_\(uuidSuffix)"
    }

    /// Generates a unique code with Unix timestamp and UUID suffix
    /// Format: prefix_unixTimestamp_uuid8chars
    /// Example: terms_agreement_1720798557_a1b2c3d4
    public static func generateUnixCode(prefix: String = "code") -> String {
        let unixTimestamp = Int(Date().timeIntervalSince1970)
        let uuidSuffix = UUID().uuidString.prefix(8)
        return "\(prefix)_\(unixTimestamp)_\(uuidSuffix)"
    }

    /// Generates a unique code with millisecond precision timestamp and UUID suffix
    /// Format: prefix_unixTimestampMillis_uuid8chars
    /// Example: terms_agreement_1720798557123_a1b2c3d4
    public static func generateMillisCode(prefix: String = "code") -> String {
        let unixTimestampMillis = Int64(Date().timeIntervalSince1970 * 1000)
        let uuidSuffix = UUID().uuidString.prefix(8)
        return "\(prefix)_\(unixTimestampMillis)_\(uuidSuffix)"
    }

    /// Generates a unique code with date-only timestamp (YYYYMMDD) and UUID suffix
    /// Format: prefix_YYYYMMDD_uuid8chars
    /// Example: terms_agreement_20250712_a1b2c3d4
    public static func generateDateCode(prefix: String = "code") -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let dateString = dateFormatter.string(from: Date())

        let uuidSuffix = UUID().uuidString.prefix(8)
        return "\(prefix)_\(dateString)_\(uuidSuffix)"
    }

    /// Generates a unique code with custom format
    /// - Parameters:
    ///   - prefix: The prefix for the code
    ///   - dateFormat: Custom date format string
    ///   - uuidLength: Length of UUID suffix (default: 8)
    /// - Returns: Formatted unique code
    public static func generateCustomCode(
        prefix: String = "code",
        dateFormat: String = "yyyyMMddHHmmss",
        uuidLength: Int = 8
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = dateFormat
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let timestamp = dateFormatter.string(from: Date())

        let uuidSuffix = UUID().uuidString.prefix(uuidLength)
        return "\(prefix)_\(timestamp)_\(uuidSuffix)"
    }
}
