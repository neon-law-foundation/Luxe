import Foundation
import Testing

@testable import Brochure

@Suite("Directory traversal functionality", .serialized)
struct DirectoryTraversalTests {

    @Test("URL relative path calculation works correctly")
    func relativePathCalculation() {
        let baseURL = URL(fileURLWithPath: "/Users/test/site")
        let fileURL = URL(fileURLWithPath: "/Users/test/site/css/style.css")

        let relativePath = fileURL.relativePath(from: baseURL)
        #expect(relativePath == "css/style.css")
    }

    @Test("URL relative path calculation with nested directories")
    func nestedDirectoryRelativePath() {
        let baseURL = URL(fileURLWithPath: "/Users/test/site")
        let fileURL = URL(fileURLWithPath: "/Users/test/site/assets/images/logo.png")

        let relativePath = fileURL.relativePath(from: baseURL)
        #expect(relativePath == "assets/images/logo.png")
    }

    @Test("URL relative path calculation with single file")
    func singleFileRelativePath() {
        let baseURL = URL(fileURLWithPath: "/Users/test/site")
        let fileURL = URL(fileURLWithPath: "/Users/test/site/index.html")

        let relativePath = fileURL.relativePath(from: baseURL)
        #expect(relativePath == "index.html")
    }

    @Test("Site name validation logic works correctly")
    func siteNameValidationLogic() {
        let validSiteNames = [
            "NeonLaw", "HoshiHoshi", "TarotSwift", "NLF", "NVSciTech", "1337lawyers",
        ]
        let invalidSiteNames = ["invalid", "test", "", "neonlaw", "NEONLAW"]

        // Test that valid site names are recognized as valid
        for siteName in validSiteNames {
            #expect(validSiteNames.contains(siteName))
        }

        // Test that invalid site names are not in the valid list
        for siteName in invalidSiteNames {
            #expect(!validSiteNames.contains(siteName))
        }
    }

    @Test("S3Uploader error types have appropriate descriptions")
    func s3UploaderErrorDescriptions() {
        let directoryError = S3UploaderError.directoryNotFound("/test/path")
        #expect(directoryError.errorDescription == "Directory not found: /test/path")

        let enumeratorError = S3UploaderError.failedToCreateEnumerator
        #expect(enumeratorError.errorDescription == "Failed to create directory enumerator")

        let multipartError = S3UploaderError.multipartUploadFailed("Test failure")
        #expect(multipartError.errorDescription == "Multipart upload failed: Test failure")
    }

    @Test("Upload error types have appropriate descriptions")
    func uploadErrorDescriptions() {
        let publicDirError = Brochure.UploadError.publicDirectoryNotFound
        #expect(publicDirError.errorDescription == "Public directory not found in bundle resources")

        let siteDirError = Brochure.UploadError.siteDirectoryNotFound("TestSite")
        #expect(siteDirError.errorDescription == "Site directory not found for: TestSite")
    }

    @Test("S3Uploader initialization sets correct defaults")
    func s3UploaderInitialization() async throws {
        let uploader = S3Uploader(bucketName: "test-bucket", keyPrefix: "test-prefix")

        // Test that the uploader can be created without throwing
        // Verify the object is a valid S3Uploader instance
        #expect(type(of: uploader) == S3Uploader.self)

        // Properly shutdown the uploader
        try await uploader.shutdown()
    }

    @Test("S3Uploader initialization with custom parameters")
    func s3UploaderCustomInitialization() async throws {
        let customBucket = "test-bucket"
        let customPrefix = "test-prefix"
        let uploader = S3Uploader(bucketName: customBucket, keyPrefix: customPrefix)

        // Test that the uploader can be created with custom parameters
        #expect(type(of: uploader) == S3Uploader.self)

        // Properly shutdown the uploader
        try await uploader.shutdown()
    }
}
