import Foundation

/// Information about a Swift package target
struct TargetInfo {
    /// The name of the target
    let name: String

    /// Dependencies for this target
    let dependencies: [String]

    /// Source files for this target
    let sourceFiles: [String]

    /// Whether this is an executable target
    let isExecutable: Bool

    init(name: String, dependencies: [String], sourceFiles: [String], isExecutable: Bool) {
        self.name = name
        self.dependencies = dependencies
        self.sourceFiles = sourceFiles
        self.isExecutable = isExecutable
    }
}

extension TargetInfo: Equatable {
    static func == (lhs: TargetInfo, rhs: TargetInfo) -> Bool {
        lhs.name == rhs.name && lhs.dependencies == rhs.dependencies && lhs.sourceFiles == rhs.sourceFiles
            && lhs.isExecutable == rhs.isExecutable
    }
}
