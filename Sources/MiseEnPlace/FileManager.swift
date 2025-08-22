import Foundation

/// Default file manager implementation
public struct DefaultFileManager: FileManagerProtocol {
    private let fileManager = FileManager.default

    public init() {}

    public func readFile(at path: String) throws -> String {
        let url = URL(fileURLWithPath: path)
        return try String(contentsOf: url, encoding: .utf8)
    }

    public func fileExists(at path: String) -> Bool {
        fileManager.fileExists(atPath: path)
    }
}
