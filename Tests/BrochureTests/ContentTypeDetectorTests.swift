import Testing

@testable import Brochure

@Suite("ContentTypeDetector functionality", .serialized)
struct ContentTypeDetectorTests {

    @Test("HTML content types are correctly detected")
    func htmlContentTypes() {
        #expect(ContentTypeDetector.contentType(for: "html") == "text/html")
        #expect(ContentTypeDetector.contentType(for: "htm") == "text/html")
        #expect(ContentTypeDetector.contentType(for: "HTML") == "text/html")
        #expect(ContentTypeDetector.contentType(for: "HTM") == "text/html")
    }

    @Test("CSS content types are correctly detected")
    func cssContentTypes() {
        #expect(ContentTypeDetector.contentType(for: "css") == "text/css")
        #expect(ContentTypeDetector.contentType(for: "scss") == "text/css")
        #expect(ContentTypeDetector.contentType(for: "sass") == "text/css")
        #expect(ContentTypeDetector.contentType(for: "less") == "text/css")
        #expect(ContentTypeDetector.contentType(for: "CSS") == "text/css")
    }

    @Test("JavaScript content types are correctly detected")
    func javascriptContentTypes() {
        #expect(ContentTypeDetector.contentType(for: "js") == "application/javascript")
        #expect(ContentTypeDetector.contentType(for: "mjs") == "application/javascript")
        #expect(ContentTypeDetector.contentType(for: "ts") == "application/javascript")
        #expect(ContentTypeDetector.contentType(for: "jsx") == "application/javascript")
        #expect(ContentTypeDetector.contentType(for: "tsx") == "application/javascript")
        #expect(ContentTypeDetector.contentType(for: "JS") == "application/javascript")
    }

    @Test("Image content types are correctly detected")
    func imageContentTypes() {
        #expect(ContentTypeDetector.contentType(for: "png") == "image/png")
        #expect(ContentTypeDetector.contentType(for: "jpg") == "image/jpeg")
        #expect(ContentTypeDetector.contentType(for: "jpeg") == "image/jpeg")
        #expect(ContentTypeDetector.contentType(for: "gif") == "image/gif")
        #expect(ContentTypeDetector.contentType(for: "svg") == "image/svg+xml")
        #expect(ContentTypeDetector.contentType(for: "webp") == "image/webp")
        #expect(ContentTypeDetector.contentType(for: "ico") == "image/x-icon")
        #expect(ContentTypeDetector.contentType(for: "PNG") == "image/png")
    }

    @Test("Font content types are correctly detected")
    func fontContentTypes() {
        #expect(ContentTypeDetector.contentType(for: "woff") == "font/woff")
        #expect(ContentTypeDetector.contentType(for: "woff2") == "font/woff2")
        #expect(ContentTypeDetector.contentType(for: "ttf") == "font/ttf")
        #expect(ContentTypeDetector.contentType(for: "otf") == "font/otf")
        #expect(ContentTypeDetector.contentType(for: "eot") == "application/vnd.ms-fontobject")
    }

    @Test("Document content types are correctly detected")
    func documentContentTypes() {
        #expect(ContentTypeDetector.contentType(for: "pdf") == "application/pdf")
        #expect(ContentTypeDetector.contentType(for: "txt") == "text/plain")
        #expect(ContentTypeDetector.contentType(for: "md") == "text/markdown")
    }

    @Test("JSON content types are correctly detected")
    func jsonContentTypes() {
        #expect(ContentTypeDetector.contentType(for: "json") == "application/json")
        #expect(ContentTypeDetector.contentType(for: "jsonld") == "application/ld+json")
        #expect(ContentTypeDetector.contentType(for: "manifest") == "application/manifest+json")
        #expect(ContentTypeDetector.contentType(for: "webmanifest") == "application/manifest+json")
    }

    @Test("Unknown file extension returns default content type")
    func unknownExtensionDefaultsToOctetStream() {
        #expect(ContentTypeDetector.contentType(for: "unknown") == "application/octet-stream")
        #expect(ContentTypeDetector.contentType(for: "xyz") == "application/octet-stream")
        #expect(ContentTypeDetector.contentType(for: "") == "application/octet-stream")
    }

    @Test("HTML cache control headers are no-cache")
    func htmlCacheControlIsNoCache() {
        #expect(ContentTypeDetector.cacheControl(for: "html") == "no-cache, must-revalidate")
        #expect(ContentTypeDetector.cacheControl(for: "htm") == "no-cache, must-revalidate")
        #expect(ContentTypeDetector.cacheControl(for: "HTML") == "no-cache, must-revalidate")
    }

    @Test("Asset cache control headers are long-lived")
    func assetCacheControlIsLongLived() {
        let longCacheHeader = "public, max-age=31536000, immutable"
        #expect(ContentTypeDetector.cacheControl(for: "css") == longCacheHeader)
        #expect(ContentTypeDetector.cacheControl(for: "js") == longCacheHeader)
        #expect(ContentTypeDetector.cacheControl(for: "png") == longCacheHeader)
        #expect(ContentTypeDetector.cacheControl(for: "jpg") == longCacheHeader)
        #expect(ContentTypeDetector.cacheControl(for: "woff") == longCacheHeader)
    }

    @Test("Manifest cache control headers are moderate")
    func manifestCacheControlIsModerate() {
        let moderateCacheHeader = "public, max-age=3600"
        #expect(ContentTypeDetector.cacheControl(for: "json") == moderateCacheHeader)
        #expect(ContentTypeDetector.cacheControl(for: "webmanifest") == moderateCacheHeader)
        #expect(ContentTypeDetector.cacheControl(for: "manifest") == moderateCacheHeader)
    }

    @Test("Unknown extension cache control returns default")
    func unknownExtensionCacheControlReturnsDefault() {
        #expect(ContentTypeDetector.cacheControl(for: "unknown") == "public, max-age=3600")
        #expect(ContentTypeDetector.cacheControl(for: "") == "public, max-age=3600")
    }

    @Test("Text file detection works correctly")
    func textFileDetection() {
        #expect(ContentTypeDetector.isTextFile("html") == true)
        #expect(ContentTypeDetector.isTextFile("css") == true)
        #expect(ContentTypeDetector.isTextFile("js") == true)
        #expect(ContentTypeDetector.isTextFile("txt") == true)
        #expect(ContentTypeDetector.isTextFile("json") == true)
        #expect(ContentTypeDetector.isTextFile("xml") == true)
        #expect(ContentTypeDetector.isTextFile("svg") == true)
        #expect(ContentTypeDetector.isTextFile("md") == true)
        #expect(ContentTypeDetector.isTextFile("HTML") == true)

        #expect(ContentTypeDetector.isTextFile("png") == false)
        #expect(ContentTypeDetector.isTextFile("jpg") == false)
        #expect(ContentTypeDetector.isTextFile("pdf") == false)
        #expect(ContentTypeDetector.isTextFile("unknown") == false)
    }

    @Test("Image file detection works correctly")
    func imageFileDetection() {
        #expect(ContentTypeDetector.isImageFile("png") == true)
        #expect(ContentTypeDetector.isImageFile("jpg") == true)
        #expect(ContentTypeDetector.isImageFile("jpeg") == true)
        #expect(ContentTypeDetector.isImageFile("gif") == true)
        #expect(ContentTypeDetector.isImageFile("svg") == true)
        #expect(ContentTypeDetector.isImageFile("webp") == true)
        #expect(ContentTypeDetector.isImageFile("ico") == true)
        #expect(ContentTypeDetector.isImageFile("PNG") == true)

        #expect(ContentTypeDetector.isImageFile("html") == false)
        #expect(ContentTypeDetector.isImageFile("css") == false)
        #expect(ContentTypeDetector.isImageFile("js") == false)
        #expect(ContentTypeDetector.isImageFile("pdf") == false)
        #expect(ContentTypeDetector.isImageFile("unknown") == false)
    }
}
