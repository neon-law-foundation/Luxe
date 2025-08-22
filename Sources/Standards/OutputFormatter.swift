import Foundation

enum ANSIColor: String {
    case reset = "\u{001B}[0m"
    case red = "\u{001B}[31m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case blue = "\u{001B}[34m"
    case cyan = "\u{001B}[36m"
    case gray = "\u{001B}[37m"
}

struct OutputFormatter {

    /// Format validation result with optional colors and verbosity
    func formatResult(_ result: ValidationResult, useColors: Bool = true, verbose: Bool = false) -> String {
        var output: [String] = []

        // Summary line
        let summary = formatSummary(result)
        output.append(summary)

        // Handle empty directory case
        if result.totalFilesProcessed == 0 {
            output.append(
                colorize("No markdown files found in the specified directory.", color: .gray, useColors: useColors)
            )
            return output.joined(separator: "\n")
        }

        // Verbose output for valid files
        if verbose && !result.validFiles.isEmpty {
            output.append(colorize("\nValid files:", color: .green, useColors: useColors))
            for file in result.validFiles {
                let fileName = URL(fileURLWithPath: file).lastPathComponent
                output.append(colorize("  ✓ \(fileName)", color: .green, useColors: useColors))
            }
        }

        // Always show invalid files if any
        if !result.invalidFiles.isEmpty {
            output.append(colorize("\nInvalid files:", color: .red, useColors: useColors))
            for error in result.errors {
                // Extract file name from error message for cleaner output
                let fileName = extractFileName(from: error)
                let errorMessage = extractErrorMessage(from: error)
                output.append(colorize("  ✗ \(fileName): \(errorMessage)", color: .red, useColors: useColors))
            }
        }

        // Final status
        output.append("")
        if result.isValid {
            output.append(colorize("All standards files are valid ✓", color: .green, useColors: useColors))
        } else {
            output.append(colorize("Some standards files are invalid ✗", color: .red, useColors: useColors))
        }

        return output.joined(separator: "\n")
    }

    /// Format summary statistics
    func formatSummary(_ result: ValidationResult) -> String {
        if result.totalFilesProcessed == 0 {
            return "0 files processed"
        }

        let totalText = "\(result.totalFilesProcessed) files processed"
        let validText = "\(result.validFiles.count) valid"
        let invalidText = "\(result.invalidFiles.count) invalid"

        return "\(totalText): \(validText), \(invalidText)"
    }

    /// Apply ANSI color codes to text
    func colorize(_ text: String, color: ANSIColor, useColors: Bool = true) -> String {
        guard useColors else { return text }
        return color.rawValue + text + ANSIColor.reset.rawValue
    }

    /// Extract filename from full path in error message
    private func extractFileName(from error: String) -> String {
        let components = error.components(separatedBy: ": ")
        guard let filePath = components.first else { return "unknown" }
        return URL(fileURLWithPath: filePath).lastPathComponent
    }

    /// Extract error message without file path
    private func extractErrorMessage(from error: String) -> String {
        let components = error.components(separatedBy: ": ")
        return components.dropFirst().joined(separator: ": ")
    }
}
