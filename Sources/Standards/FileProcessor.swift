import Foundation

struct FileProcessor {

    /// Recursively find all markdown files in a directory, excluding README.md and CLAUDE.md
    func findMarkdownFiles(in directoryPath: String) -> [String] {
        let fileManager = FileManager.default
        let directoryURL = URL(fileURLWithPath: directoryPath)

        guard fileManager.fileExists(atPath: directoryPath) else {
            return []
        }

        var markdownFiles: [String] = []

        if let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {

            for case let fileURL as URL in enumerator {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.isRegularFileKey])

                    // Only process regular files
                    guard resourceValues.isRegularFile == true else {
                        continue
                    }

                    // Check if it's a markdown file
                    guard fileURL.pathExtension.lowercased() == "md" else {
                        continue
                    }

                    // Exclude README.md and CLAUDE.md
                    let fileName = fileURL.lastPathComponent
                    if fileName == "README.md" || fileName == "CLAUDE.md" {
                        continue
                    }

                    markdownFiles.append(fileURL.path)
                } catch {
                    // Skip files we can't read
                    continue
                }
            }
        }

        return markdownFiles.sorted()
    }
}
