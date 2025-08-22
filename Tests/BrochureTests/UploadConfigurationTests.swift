import Testing

@testable import Brochure

@Suite("UploadConfiguration functionality", .serialized)
struct UploadConfigurationTests {

    @Test("Default configuration has expected values")
    func defaultConfigurationValues() {
        let config = UploadConfiguration.default

        #expect(config.bucketName == "sagebrush-public")
        #expect(config.keyPrefix == "Brochure")
        #expect(config.region == "us-west-2")
        #expect(config.skipUnchangedFiles == true)
        #expect(config.enableMultipartUpload == true)
        #expect(config.multipartChunkSize == 5 * 1024 * 1024)
        #expect(config.maxRetries == 3)
        #expect(config.retryBaseDelay == 1.0)
        #expect(config.defaultCacheDuration == 3600)
        #expect(config.htmlCacheControl == "no-cache, must-revalidate")
        #expect(config.assetCacheControl == "public, max-age=31536000, immutable")
        #expect(config.moderateCacheControl == "public, max-age=3600")
    }

    @Test("Custom configuration can be created")
    func customConfiguration() {
        let config = UploadConfiguration(
            bucketName: "test-bucket",
            keyPrefix: "test-prefix",
            region: "us-east-1",
            skipUnchangedFiles: false,
            maxRetries: 5
        )

        #expect(config.bucketName == "test-bucket")
        #expect(config.keyPrefix == "test-prefix")
        #expect(config.region == "us-east-1")
        #expect(config.skipUnchangedFiles == false)
        #expect(config.maxRetries == 5)
    }

    @Test("HTML files have no-cache control")
    func htmlCacheControl() {
        let config = UploadConfiguration.default

        #expect(config.cacheControl(for: "html") == "no-cache, must-revalidate")
        #expect(config.cacheControl(for: "htm") == "no-cache, must-revalidate")
        #expect(config.cacheControl(for: "HTML") == "no-cache, must-revalidate")
    }

    @Test("Asset files have long cache control")
    func assetCacheControl() {
        let config = UploadConfiguration.default
        let longCache = "public, max-age=31536000, immutable"

        #expect(config.cacheControl(for: "css") == longCache)
        #expect(config.cacheControl(for: "js") == longCache)
        #expect(config.cacheControl(for: "png") == longCache)
        #expect(config.cacheControl(for: "jpg") == longCache)
        #expect(config.cacheControl(for: "woff") == longCache)
    }

    @Test("Manifest files have moderate cache control")
    func manifestCacheControl() {
        let config = UploadConfiguration.default
        let moderateCache = "public, max-age=3600"

        #expect(config.cacheControl(for: "json") == moderateCache)
        #expect(config.cacheControl(for: "webmanifest") == moderateCache)
        #expect(config.cacheControl(for: "txt") == moderateCache)
        #expect(config.cacheControl(for: "md") == moderateCache)
    }

    @Test("PDF files have daily cache control")
    func pdfCacheControl() {
        let config = UploadConfiguration.default

        #expect(config.cacheControl(for: "pdf") == "public, max-age=86400")
    }

    @Test("Unknown extensions return default cache control")
    func unknownExtensionsCacheControl() {
        let config = UploadConfiguration.default

        #expect(config.cacheControl(for: "unknown") == config.moderateCacheControl)
        #expect(config.cacheControl(for: "") == config.moderateCacheControl)
        #expect(config.cacheControl(for: "xyz") == config.moderateCacheControl)
    }

    @Test("Cache control is case insensitive")
    func caseInsensitiveCacheControl() {
        let config = UploadConfiguration.default

        #expect(config.cacheControl(for: "CSS") == config.assetCacheControl)
        #expect(config.cacheControl(for: "PNG") == config.assetCacheControl)
        #expect(config.cacheControl(for: "JSON") == config.moderateCacheControl)
    }

    @Test("Cache control for file type dictionary contains all expected entries")
    func cacheControlDictionary() {
        let config = UploadConfiguration.default
        let dictionary = config.cacheControlForFileType

        #expect(dictionary["html"] == config.htmlCacheControl)
        #expect(dictionary["css"] == config.assetCacheControl)
        #expect(dictionary["json"] == config.moderateCacheControl)
        #expect(dictionary["pdf"] == "public, max-age=86400")

        // Verify it contains the expected number of entries
        #expect(dictionary.count >= 20)
    }
}
