import Foundation
import Logging

/// Service for preventing duplicate file selection across multiple runs
public struct DuplicatePreventionStore {
    private let logger: Logger
    private let storeURL: URL
    private let maxHistoryDays: Double

    public init(logger: Logger, storeURL: URL? = nil, maxHistoryDays: Double = 7.0) {
        self.logger = logger
        self.maxHistoryDays = maxHistoryDays

        // Use default cache directory if not provided
        if let storeURL = storeURL {
            self.storeURL = storeURL
        } else {
            let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let rouletteCache = cacheDirectory.appendingPathComponent("Roulette", isDirectory: true)
            self.storeURL = rouletteCache.appendingPathComponent("recent_selections.json")
        }
    }

    /// Records that files were selected at the current time
    /// - Parameter filePaths: Array of file paths that were selected
    public func recordSelection(_ filePaths: [String]) throws {
        logger.debug(
            "Recording selected files",
            metadata: [
                "count": .stringConvertible(filePaths.count),
                "files": .array(filePaths.map { .string($0) }),
            ]
        )

        // Load existing history
        var history = try loadSelectionHistory()

        // Add new selections with current timestamp
        let currentTime = Date()
        let newEntries = filePaths.map { filePath in
            SelectionEntry(filePath: filePath, selectedAt: currentTime)
        }

        history.append(contentsOf: newEntries)

        // Clean up old entries
        let cutoffDate = currentTime.addingTimeInterval(-maxHistoryDays * 24 * 60 * 60)
        history = history.filter { $0.selectedAt > cutoffDate }

        // Save updated history
        try saveSelectionHistory(history)

        logger.debug(
            "Selection history updated",
            metadata: [
                "newEntries": .stringConvertible(newEntries.count),
                "totalEntries": .stringConvertible(history.count),
                "maxHistoryDays": .stringConvertible(maxHistoryDays),
            ]
        )
    }

    /// Gets files that were recently selected and should be avoided
    /// - Returns: Set of file paths that were selected within the history period
    public func getRecentlySelectedFiles() throws -> Set<String> {
        logger.debug("Loading recently selected files")

        let history = try loadSelectionHistory()
        let cutoffDate = Date().addingTimeInterval(-maxHistoryDays * 24 * 60 * 60)

        let recentFiles = Set(
            history
                .filter { $0.selectedAt > cutoffDate }
                .map { $0.filePath }
        )

        logger.debug(
            "Loaded recently selected files",
            metadata: [
                "count": .stringConvertible(recentFiles.count),
                "maxHistoryDays": .stringConvertible(maxHistoryDays),
            ]
        )

        return recentFiles
    }

    /// Filters out recently selected files from the candidate list
    /// - Parameter candidates: Array of candidate file paths
    /// - Returns: Filtered array with recently selected files removed
    public func filterRecentlySelected(_ candidates: [String]) throws -> [String] {
        let recentlySelected = try getRecentlySelectedFiles()
        let filtered = candidates.filter { !recentlySelected.contains($0) }

        let filteredCount = candidates.count - filtered.count
        if filteredCount > 0 {
            logger.info(
                "Filtered recently selected files",
                metadata: [
                    "originalCount": .stringConvertible(candidates.count),
                    "filteredCount": .stringConvertible(filteredCount),
                    "remainingCount": .stringConvertible(filtered.count),
                ]
            )
        }

        return filtered
    }

    /// Clears the selection history
    public func clearHistory() throws {
        logger.info("Clearing selection history")

        if FileManager.default.fileExists(atPath: storeURL.path) {
            try FileManager.default.removeItem(at: storeURL)
        }

        logger.debug("Selection history cleared")
    }

    // MARK: - Private Methods

    /// Loads the selection history from disk
    private func loadSelectionHistory() throws -> [SelectionEntry] {
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            logger.debug("No existing selection history found")
            return []
        }

        do {
            let data = try Data(contentsOf: storeURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let history = try decoder.decode([SelectionEntry].self, from: data)
            logger.debug(
                "Loaded selection history",
                metadata: [
                    "entries": .stringConvertible(history.count)
                ]
            )

            return history
        } catch {
            logger.warning(
                "Failed to load selection history, starting fresh",
                metadata: [
                    "error": .string(String(describing: error))
                ]
            )
            return []
        }
    }

    /// Saves the selection history to disk
    private func saveSelectionHistory(_ history: [SelectionEntry]) throws {
        // Ensure the directory exists
        let directory = storeURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(history)
        try data.write(to: storeURL)

        logger.debug(
            "Saved selection history",
            metadata: [
                "entries": .stringConvertible(history.count),
                "path": .string(storeURL.path),
            ]
        )
    }
}

/// Represents a single file selection entry in the history
private struct SelectionEntry: Codable {
    let filePath: String
    let selectedAt: Date
}
