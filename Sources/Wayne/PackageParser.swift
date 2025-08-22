import Foundation

/// Parser for Swift Package.swift files
struct PackageParser {

    /// Parse targets from Package.swift content
    func parseTargets(from packageContent: String) throws -> [TargetInfo] {
        var targets: [TargetInfo] = []

        // Simple regex-based parsing for executable targets
        let executablePattern = #"\.executableTarget\s*\(\s*name:\s*"([^"]+)"(?:\s*,\s*dependencies:\s*(\[[^\]]*\]))?"#
        let regex = try NSRegularExpression(pattern: executablePattern, options: [])

        let range = NSRange(location: 0, length: packageContent.utf16.count)
        let matches = regex.matches(in: packageContent, options: [], range: range)

        for match in matches {
            let nameRange = match.range(at: 1)
            let dependenciesRange = match.range(at: 2)

            guard let nameNSRange = Range(nameRange, in: packageContent) else { continue }
            let name = String(packageContent[nameNSRange])

            var dependencies: [String] = []
            if dependenciesRange.location != NSNotFound,
                let depNSRange = Range(dependenciesRange, in: packageContent)
            {
                let depString = String(packageContent[depNSRange])
                dependencies = parseDependencies(from: depString)
            }

            // Get source files for this target
            let sourceFiles = getSourceFiles(for: name)

            let targetInfo = TargetInfo(
                name: name,
                dependencies: dependencies,
                sourceFiles: sourceFiles,
                isExecutable: true
            )
            targets.append(targetInfo)
        }

        return targets
    }

    /// Parse dependencies array from string
    private func parseDependencies(from dependenciesString: String) -> [String] {
        var dependencies: [String] = []

        // Match quoted strings (simple dependencies)
        let quotedPattern = #""([^"]+)""#
        if let quotedRegex = try? NSRegularExpression(pattern: quotedPattern, options: []) {
            let range = NSRange(location: 0, length: dependenciesString.utf16.count)
            let matches = quotedRegex.matches(in: dependenciesString, options: [], range: range)

            for match in matches {
                let depRange = match.range(at: 1)
                if let depNSRange = Range(depRange, in: dependenciesString) {
                    let dep = String(dependenciesString[depNSRange])
                    dependencies.append(dep)
                }
            }
        }

        return dependencies
    }

    /// Get source files for a target by scanning the file system
    private func getSourceFiles(for targetName: String) -> [String] {
        let sourcesPath = "Sources/\(targetName)"
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(atPath: sourcesPath) else {
            return []
        }

        var sourceFiles: [String] = []
        while let file = enumerator.nextObject() as? String {
            if file.hasSuffix(".swift") {
                sourceFiles.append(file)
            }
        }

        return sourceFiles.sorted()
    }

    /// Parse Package.swift file from file system
    func parsePackageFile(at path: String = "Package.swift") throws -> [TargetInfo] {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: path) else {
            throw WayneError.packageFileNotFound
        }

        let packageContent = try String(contentsOfFile: path, encoding: .utf8)
        return try parseTargets(from: packageContent)
    }
}

/// Errors that can occur during package parsing
enum WayneError: Error, LocalizedError {
    case packageFileNotFound
    case invalidPackageFormat
    case targetNotFound(String)
    case projectGenerationFailed(String)

    var errorDescription: String? {
        switch self {
        case .packageFileNotFound:
            return "Package.swift file not found"
        case .invalidPackageFormat:
            return "Invalid Package.swift format"
        case .targetNotFound(let name):
            return "Target '\(name)' not found"
        case .projectGenerationFailed(let reason):
            return "Project generation failed: \(reason)"
        }
    }
}
