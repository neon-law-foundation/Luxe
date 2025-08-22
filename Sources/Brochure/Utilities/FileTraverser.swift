import Foundation

/// File filtering utility using glob-style patterns.
///
/// `FileTraverser` provides file exclusion capabilities using glob-style pattern matching.
/// It supports common glob patterns including wildcards (`*`), character placeholders (`?`),
/// and recursive directory matching (`**`).
///
/// ## Supported Patterns
///
/// - `*`: Matches any characters except directory separators
/// - `?`: Matches any single character except directory separators
/// - `**`: Matches any number of directories and subdirectories
/// - `**/pattern`: Matches pattern in any subdirectory
/// - `pattern/**`: Matches pattern and all its contents
/// - `**/pattern/**`: Matches pattern anywhere with all contents
///
/// ## Example Usage
///
/// ```swift
/// let traverser = FileTraverser(excludePatterns: [
///     "*.min.js",           // Exclude minified JavaScript
///     "node_modules/**",    // Exclude entire node_modules directory
///     "**/temp/**",         // Exclude any temp directory and contents
///     "test?.txt"           // Exclude test1.txt, testA.txt, etc.
/// ])
///
/// let shouldExclude = traverser.shouldExcludeFile(path: "dist/app.min.js")  // true
/// ```
///
/// ## Pattern Examples
///
/// - `*.log` → Excludes all log files
/// - `**/node_modules/**` → Excludes node_modules directories anywhere
/// - `build/**` → Excludes everything in build directory
/// - `test?.js` → Excludes test1.js, testA.js, but not test12.js
public struct FileTraverser {
    private let excludePatterns: [String]

    /// Creates a new file traverser with the specified exclude patterns.
    ///
    /// - Parameter excludePatterns: Array of glob patterns to match against file paths
    public init(excludePatterns: [String] = []) {
        self.excludePatterns = excludePatterns
    }

    /// Determines whether a file should be excluded based on the configured patterns.
    ///
    /// - Parameter path: The file path to test against exclusion patterns
    /// - Returns: `true` if the file should be excluded, `false` otherwise
    ///
    /// ## Example
    ///
    /// ```swift
    /// let traverser = FileTraverser(excludePatterns: ["*.log", "temp/**"])
    /// traverser.shouldExcludeFile(path: "app.log")        // true
    /// traverser.shouldExcludeFile(path: "temp/data.txt")  // true
    /// traverser.shouldExcludeFile(path: "src/main.js")    // false
    /// ```
    public func shouldExcludeFile(path: String) -> Bool {
        for pattern in excludePatterns {
            if matchesPattern(path: path, pattern: pattern) {
                return true
            }
        }
        return false
    }

    private func matchesPattern(path: String, pattern: String) -> Bool {
        // Handle simple common cases first
        if pattern.contains("**") {
            // For ** patterns, check if the pattern minus ** appears anywhere in the path
            let patternWithoutStars = pattern.replacingOccurrences(of: "**", with: "")
            if patternWithoutStars.isEmpty {
                return true  // ** alone matches everything
            }

            // For patterns like "**/*.min.js", check if path ends with ".min.js"
            if pattern.hasPrefix("**/") {
                let suffix = String(pattern.dropFirst(3))
                return simpleMatch(path: path, pattern: suffix)
            }

            // For patterns like "node_modules/**", check if path starts with "node_modules/"
            if pattern.hasSuffix("/**") {
                let prefix = String(pattern.dropLast(3))
                return path.hasPrefix(prefix + "/") || path == prefix
            }

            // For patterns like "**/temp/**", check if path contains "/temp/"
            if pattern.hasPrefix("**/") && pattern.hasSuffix("/**") {
                let middle = String(pattern.dropFirst(3).dropLast(3))
                return path.contains("/" + middle + "/") || path.hasPrefix(middle + "/") || path.hasSuffix("/" + middle)
            }
        }

        return simpleMatch(path: path, pattern: pattern)
    }

    private func simpleMatch(path: String, pattern: String) -> Bool {
        // Handle simple * and ? patterns
        if pattern == "*" {
            return !path.contains("/")
        }

        if !pattern.contains("*") && !pattern.contains("?") {
            return path == pattern
        }

        // Handle ? patterns with simple character matching
        if pattern.contains("?") {
            return matchWithQuestionMarks(path: path, pattern: pattern)
        }

        // For patterns like "*.ext", check if path ends with ".ext"
        if pattern.hasPrefix("*") && !pattern.dropFirst().contains("*") {
            let suffix = String(pattern.dropFirst())
            return path.hasSuffix(suffix)
        }

        // For patterns like "prefix*", check if path starts with "prefix"
        if pattern.hasSuffix("*") && !pattern.dropLast().contains("*") {
            let prefix = String(pattern.dropLast())
            return path.hasPrefix(prefix)
        }

        // For simple cases, fall back to basic contains
        return path.contains(pattern.replacingOccurrences(of: "*", with: ""))
    }

    private func matchWithQuestionMarks(path: String, pattern: String) -> Bool {
        // Simple implementation for ? matching
        if path.count != pattern.count {
            return false
        }

        let pathArray = Array(path)
        let patternArray = Array(pattern)

        for i in 0..<pathArray.count {
            let pathChar = pathArray[i]
            let patternChar = patternArray[i]

            if patternChar == "?" {
                // ? matches any character except /
                if pathChar == "/" {
                    return false
                }
            } else if patternChar != pathChar {
                return false
            }
        }

        return true
    }
}

extension String {
    /// Parses a comma-separated string of exclude patterns into an array.
    ///
    /// - Returns: An array of trimmed, non-empty pattern strings
    ///
    /// This extension method is useful for parsing command-line arguments or configuration
    /// strings containing multiple exclude patterns.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let patterns = "*.log, temp/**, **/node_modules/**".parseExcludePatterns()
    /// // Returns: ["*.log", "temp/**", "**/node_modules/**"]
    /// ```
    public func parseExcludePatterns() -> [String] {
        self.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
