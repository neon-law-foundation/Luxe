import Testing

@testable import Brochure

@Suite("UploadProgress functionality", .serialized)
struct UploadProgressTests {

    @Test("Initial progress state is correct")
    func initialProgressState() async {
        let progress = UploadProgress()
        let stats = await progress.getStats()

        #expect(stats.totalFiles == 0)
        #expect(stats.processedFiles == 0)
        #expect(stats.uploadedFiles == 0)
        #expect(stats.skippedFiles == 0)
        #expect(stats.failedFiles == 0)
        #expect(stats.totalBytes == 0)
        #expect(stats.uploadedBytes == 0)
        #expect(stats.percentageComplete == 0.0)
        #expect(stats.isComplete == false)
    }

    @Test("Setting total files updates correctly")
    func settingTotalFiles() async {
        let progress = UploadProgress()
        await progress.setTotalFiles(10)

        let stats = await progress.getStats()
        #expect(stats.totalFiles == 10)
        #expect(stats.percentageComplete == 0.0)
    }

    @Test("Setting total bytes updates correctly")
    func settingTotalBytes() async {
        let progress = UploadProgress()
        await progress.setTotalBytes(1024 * 1024)  // 1MB

        let stats = await progress.getStats()
        #expect(stats.totalBytes == 1024 * 1024)
    }

    @Test("Adding uploaded files updates progress correctly")
    func addingUploadedFiles() async {
        let progress = UploadProgress()
        await progress.setTotalFiles(5)
        await progress.addUploadedFile(size: 1024)
        await progress.addUploadedFile(size: 2048)

        let stats = await progress.getStats()
        #expect(stats.uploadedFiles == 2)
        #expect(stats.processedFiles == 2)
        #expect(stats.uploadedBytes == 3072)
        #expect(stats.percentageComplete == 40.0)  // 2/5 * 100
    }

    @Test("Adding skipped files updates progress correctly")
    func addingSkippedFiles() async {
        let progress = UploadProgress()
        await progress.setTotalFiles(4)
        await progress.addSkippedFile(size: 512)
        await progress.addSkippedFile(size: 1024)

        let stats = await progress.getStats()
        #expect(stats.skippedFiles == 2)
        #expect(stats.processedFiles == 2)
        #expect(stats.uploadedBytes == 0)  // Skipped files don't add to uploaded bytes
        #expect(stats.percentageComplete == 50.0)  // 2/4 * 100
    }

    @Test("Adding failed files updates progress correctly")
    func addingFailedFiles() async {
        let progress = UploadProgress()
        await progress.setTotalFiles(3)
        await progress.addFailedFile(size: 256)

        let stats = await progress.getStats()
        #expect(stats.failedFiles == 1)
        #expect(stats.processedFiles == 1)
        #expect(stats.uploadedBytes == 0)  // Failed files don't add to uploaded bytes
        #expect(abs(stats.percentageComplete - 33.3) < 0.1)  // 1/3 * 100
    }

    @Test("Mixed file operations calculate correctly")
    func mixedFileOperations() async {
        let progress = UploadProgress()
        await progress.setTotalFiles(6)
        await progress.setTotalBytes(10240)  // 10KB

        await progress.addUploadedFile(size: 2048)  // 2KB
        await progress.addUploadedFile(size: 1024)  // 1KB
        await progress.addSkippedFile(size: 512)  // 0.5KB (not counted in uploaded)
        await progress.addFailedFile(size: 256)  // 0.25KB (not counted in uploaded)

        let stats = await progress.getStats()
        #expect(stats.uploadedFiles == 2)
        #expect(stats.skippedFiles == 1)
        #expect(stats.failedFiles == 1)
        #expect(stats.processedFiles == 4)
        #expect(stats.uploadedBytes == 3072)  // Only uploaded files
        #expect(abs(stats.percentageComplete - 66.7) < 0.1)  // 4/6 * 100
        #expect(stats.isComplete == false)
    }

    @Test("Progress is complete when all files processed")
    func progressCompleteState() async {
        let progress = UploadProgress()
        await progress.setTotalFiles(2)

        await progress.addUploadedFile(size: 1024)
        await progress.addSkippedFile(size: 512)

        let stats = await progress.getStats()
        #expect(stats.isComplete == true)
        #expect(stats.percentageComplete == 100.0)
    }

    @Test("UploadStats formatted progress string is correct")
    func formattedProgressString() async {
        let progress = UploadProgress()
        await progress.setTotalFiles(10)
        await progress.addUploadedFile(size: 1024)
        await progress.addUploadedFile(size: 1024)
        await progress.addSkippedFile(size: 512)

        let stats = await progress.getStats()
        let formatted = stats.formattedProgress

        #expect(formatted.contains("30.0%"))
        #expect(formatted.contains("(3/10"))
    }

    @Test("UploadStats summary string is correct")
    func summaryString() async {
        let progress = UploadProgress()
        await progress.addUploadedFile(size: 1024)
        await progress.addUploadedFile(size: 1024)
        await progress.addSkippedFile(size: 512)
        await progress.addFailedFile(size: 256)

        let stats = await progress.getStats()
        let summary = stats.summary

        #expect(summary == "Uploaded: 2, Skipped: 1, Failed: 1")
    }

    @Test("UploadStats formatted bytes string contains expected format")
    func formattedBytesString() async {
        let progress = UploadProgress()
        await progress.setTotalBytes(2048)
        await progress.addUploadedFile(size: 1024)

        let stats = await progress.getStats()
        let formatted = stats.formattedBytes

        // The exact format depends on ByteCountFormatter, but should contain sizes
        #expect(formatted.contains("1"))
        #expect(formatted.contains("2"))
        #expect(formatted.contains("/"))
    }
}
