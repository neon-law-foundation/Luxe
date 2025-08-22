import Foundation

/// Version information for services
public struct Version: Codable, Sendable {
    public let serviceName: String
    public let gitCommit: String
    public let gitTag: String
    public let buildDate: String
    public let swiftVersion: String

    public init(serviceName: String, environment: [String: String]? = nil) {
        self.serviceName = serviceName
        let env = environment ?? ProcessInfo.processInfo.environment
        self.gitCommit = env["GIT_COMMIT"] ?? "unknown"
        self.gitTag = env["GIT_TAG"] ?? "unknown"
        self.buildDate = env["BUILD_DATE"] ?? "unknown"

        // Get Swift version from compiler
        #if swift(>=6.1)
        self.swiftVersion = "6.1+"
        #elseif swift(>=6.0)
        self.swiftVersion = "6.0"
        #elseif swift(>=5.10)
        self.swiftVersion = "5.10"
        #elseif swift(>=5.9)
        self.swiftVersion = "5.9"
        #else
        self.swiftVersion = "5.8-"
        #endif
    }

    /// Returns version information as JSON
    public func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Returns version information as formatted JSON string
    public func toJSONString() throws -> String {
        let data = try toJSON()
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

extension Version {
    /// Standard version information for unknown service
    public static let unknown = Version(serviceName: "unknown")
}
