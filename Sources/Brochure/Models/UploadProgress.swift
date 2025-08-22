import Foundation

/// Thread-safe progress tracking for S3 upload operations.
///
/// `UploadProgress` provides real-time tracking of file upload operations including
/// counts of uploaded, skipped, and failed files, as well as byte-level progress tracking.
/// All operations are thread-safe and can be safely accessed from multiple concurrent tasks.
///
/// ## Example Usage
///
/// ```swift
/// let progress = UploadProgress()
/// await progress.setTotalFiles(100)
/// await progress.setTotalBytes(1024 * 1024 * 50) // 50MB
///
/// // During upload operations
/// await progress.addUploadedFile(size: 1024 * 512) // 512KB file
/// await progress.addSkippedFile(size: 1024 * 256)  // 256KB file
///
/// // Check progress
/// let stats = await progress.getStats()
/// print("Progress: \(stats.percentageComplete)%")
/// print("Uploaded: \(stats.uploadedFiles)/\(stats.totalFiles) files")
/// ```
///
/// ## Thread Safety
///
/// All methods are thread-safe using Swift actors for data consistency across multiple tasks.
public actor UploadProgress {
    private var totalFiles: Int = 0
    private var processedFiles: Int = 0
    private var uploadedFiles: Int = 0
    private var skippedFiles: Int = 0
    private var failedFiles: Int = 0
    private var totalBytes: Int64 = 0
    private var uploadedBytes: Int64 = 0

    /// Sets the total number of files to be processed.
    ///
    /// - Parameter count: The total number of files
    public func setTotalFiles(_ count: Int) {
        totalFiles = count
    }

    /// Sets the total number of bytes to be uploaded.
    ///
    /// - Parameter bytes: The total number of bytes
    public func setTotalBytes(_ bytes: Int64) {
        totalBytes = bytes
    }

    /// Records a successfully uploaded file.
    ///
    /// - Parameter size: The size of the uploaded file in bytes
    public func addUploadedFile(size: Int64) {
        uploadedFiles += 1
        processedFiles += 1
        uploadedBytes += size
    }

    /// Records a skipped file (e.g., due to no changes detected).
    ///
    /// - Parameter size: The size of the skipped file in bytes
    public func addSkippedFile(size: Int64) {
        skippedFiles += 1
        processedFiles += 1
    }

    /// Records a failed file upload.
    ///
    /// - Parameter size: The size of the failed file in bytes
    public func addFailedFile(size: Int64) {
        failedFiles += 1
        processedFiles += 1
    }

    /// Returns a snapshot of the current upload statistics.
    ///
    /// - Returns: An `UploadStats` structure containing current progress information
    public func getStats() -> UploadStats {
        // Calculate percentage and completion directly
        let percentage: Double = totalFiles > 0 ? Double(processedFiles) / Double(totalFiles) * 100.0 : 0.0
        let complete = totalFiles > 0 && processedFiles >= totalFiles

        return UploadStats(
            totalFiles: totalFiles,
            processedFiles: processedFiles,
            uploadedFiles: uploadedFiles,
            skippedFiles: skippedFiles,
            failedFiles: failedFiles,
            totalBytes: totalBytes,
            uploadedBytes: uploadedBytes,
            percentageComplete: percentage,
            isComplete: complete
        )
    }
}

/// A snapshot of upload progress statistics.
///
/// `UploadStats` provides a thread-safe snapshot of upload progress at a specific point in time.
/// It includes file counts, byte counts, and computed properties for formatted display.
public struct UploadStats: Sendable {
    /// The total number of files to be processed.
    public let totalFiles: Int

    /// The number of files that have been processed (uploaded, skipped, or failed).
    public let processedFiles: Int

    /// The number of files successfully uploaded.
    public let uploadedFiles: Int

    /// The number of files skipped (e.g., due to no changes).
    public let skippedFiles: Int

    /// The number of files that failed to upload.
    public let failedFiles: Int

    /// The total number of bytes to be uploaded.
    public let totalBytes: Int64

    /// The number of bytes successfully uploaded.
    public let uploadedBytes: Int64

    /// The completion percentage (0.0 to 100.0).
    public let percentageComplete: Double

    /// Whether all files have been processed.
    public let isComplete: Bool

    /// A formatted progress string showing percentage and file counts.
    ///
    /// - Returns: A string like "75.5% (151/200 files)"
    public var formattedProgress: String {
        String(format: "%.1f%% (%d/%d files)", percentageComplete, processedFiles, totalFiles)
    }

    /// A formatted byte count string showing uploaded vs total bytes.
    ///
    /// - Returns: A human-readable string like "45.2 MB / 60.1 MB"
    public var formattedBytes: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: uploadedBytes)) / \(formatter.string(fromByteCount: totalBytes))"
    }

    /// A summary string showing the breakdown of file processing results.
    ///
    /// - Returns: A string like "Uploaded: 145, Skipped: 5, Failed: 0"
    public var summary: String {
        "Uploaded: \(uploadedFiles), Skipped: \(skippedFiles), Failed: \(failedFiles)"
    }
}
