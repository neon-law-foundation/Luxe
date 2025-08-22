import Foundation

/// Detects MIME content types and cache control headers for web files.
///
/// `ContentTypeDetector` provides static methods to determine appropriate MIME types
/// and cache control headers based on file extensions. It supports all common web file types
/// including HTML, CSS, JavaScript, images, fonts, and documents.
///
/// ## Content Type Detection
///
/// The detector maps file extensions to proper MIME types following web standards:
/// - HTML files: `text/html`
/// - CSS files: `text/css`
/// - JavaScript files: `application/javascript`
/// - Images: `image/png`, `image/jpeg`, etc.
/// - Fonts: `font/woff`, `font/woff2`, etc.
///
/// ## Cache Control Strategies
///
/// Different file types receive appropriate cache control headers:
/// - **HTML files**: No caching (`no-cache, must-revalidate`)
/// - **Static assets**: Long-term caching (`public, max-age=31536000, immutable`)
/// - **Manifests/configs**: Moderate caching (`public, max-age=3600`)
///
/// ## Example Usage
///
/// ```swift
/// let contentType = ContentTypeDetector.contentType(for: "css")  // "text/css"
/// let cacheControl = ContentTypeDetector.cacheControl(for: "css")  // "public, max-age=31536000, immutable"
/// let isText = ContentTypeDetector.isTextFile("html")  // true
/// let isImage = ContentTypeDetector.isImageFile("png")  // true
/// ```
public struct ContentTypeDetector {
    private static let contentTypes: [String: String] = [
        // HTML and XML
        "html": "text/html",
        "htm": "text/html",
        "xml": "application/xml",
        "xhtml": "application/xhtml+xml",

        // Stylesheets
        "css": "text/css",
        "scss": "text/css",
        "sass": "text/css",
        "less": "text/css",

        // JavaScript
        "js": "application/javascript",
        "mjs": "application/javascript",
        "ts": "application/javascript",
        "jsx": "application/javascript",
        "tsx": "application/javascript",

        // Images
        "png": "image/png",
        "jpg": "image/jpeg",
        "jpeg": "image/jpeg",
        "gif": "image/gif",
        "svg": "image/svg+xml",
        "webp": "image/webp",
        "ico": "image/x-icon",

        // Fonts
        "woff": "font/woff",
        "woff2": "font/woff2",
        "ttf": "font/ttf",
        "otf": "font/otf",
        "eot": "application/vnd.ms-fontobject",

        // Documents
        "pdf": "application/pdf",
        "txt": "text/plain",
        "md": "text/markdown",

        // JSON and data
        "json": "application/json",
        "jsonld": "application/ld+json",
        "manifest": "application/manifest+json",

        // Other common web files
        "webmanifest": "application/manifest+json",
        "map": "application/json",
        "rss": "application/rss+xml",
        "atom": "application/atom+xml",
    ]

    private static let cacheControls: [String: String] = [
        // HTML files - no cache to ensure fresh content
        "html": "no-cache, must-revalidate",
        "htm": "no-cache, must-revalidate",

        // Assets - long cache for static assets
        "css": "public, max-age=31536000, immutable",  // 1 year
        "js": "public, max-age=31536000, immutable",  // 1 year
        "png": "public, max-age=31536000, immutable",  // 1 year
        "jpg": "public, max-age=31536000, immutable",  // 1 year
        "jpeg": "public, max-age=31536000, immutable",  // 1 year
        "gif": "public, max-age=31536000, immutable",  // 1 year
        "svg": "public, max-age=31536000, immutable",  // 1 year
        "webp": "public, max-age=31536000, immutable",  // 1 year
        "ico": "public, max-age=31536000, immutable",  // 1 year

        // Fonts - long cache
        "woff": "public, max-age=31536000, immutable",  // 1 year
        "woff2": "public, max-age=31536000, immutable",  // 1 year
        "ttf": "public, max-age=31536000, immutable",  // 1 year
        "otf": "public, max-age=31536000, immutable",  // 1 year
        "eot": "public, max-age=31536000, immutable",  // 1 year

        // Manifests and configs - moderate cache
        "json": "public, max-age=3600",  // 1 hour
        "webmanifest": "public, max-age=3600",  // 1 hour
        "manifest": "public, max-age=3600",  // 1 hour

        // Other documents - moderate cache
        "pdf": "public, max-age=86400",  // 1 day
        "txt": "public, max-age=3600",  // 1 hour
        "md": "public, max-age=3600",  // 1 hour
    ]

    /// Returns the appropriate MIME content type for the given file extension.
    ///
    /// - Parameter fileExtension: The file extension (without the dot)
    /// - Returns: The MIME content type, or "application/octet-stream" for unknown types
    ///
    /// ## Example
    ///
    /// ```swift
    /// ContentTypeDetector.contentType(for: "html")  // "text/html"
    /// ContentTypeDetector.contentType(for: "css")   // "text/css"
    /// ContentTypeDetector.contentType(for: "unknown") // "application/octet-stream"
    /// ```
    public static func contentType(for fileExtension: String) -> String {
        let lowercaseExtension = fileExtension.lowercased()
        return contentTypes[lowercaseExtension] ?? "application/octet-stream"
    }

    /// Returns the appropriate cache control header for the given file extension.
    ///
    /// - Parameter fileExtension: The file extension (without the dot)
    /// - Returns: The cache control header string, or moderate caching for unknown types
    ///
    /// ## Cache Control Strategies
    ///
    /// - **HTML files**: `no-cache, must-revalidate` (always fresh)
    /// - **Static assets**: `public, max-age=31536000, immutable` (1 year cache)
    /// - **Manifests**: `public, max-age=3600` (1 hour cache)
    /// - **Unknown types**: `public, max-age=3600` (1 hour cache)
    ///
    /// ## Example
    ///
    /// ```swift
    /// ContentTypeDetector.cacheControl(for: "html")  // "no-cache, must-revalidate"
    /// ContentTypeDetector.cacheControl(for: "css")   // "public, max-age=31536000, immutable"
    /// ```
    public static func cacheControl(for fileExtension: String) -> String {
        let lowercaseExtension = fileExtension.lowercased()
        return cacheControls[lowercaseExtension] ?? "public, max-age=3600"  // Default: 1 hour
    }

    /// Determines if the file extension represents a text-based file.
    ///
    /// - Parameter fileExtension: The file extension (without the dot)
    /// - Returns: `true` if the file is text-based, `false` otherwise
    ///
    /// Text files include HTML, CSS, JavaScript, JSON, XML, SVG, and Markdown files.
    /// This is useful for determining how to handle file encoding during upload.
    public static func isTextFile(_ fileExtension: String) -> Bool {
        let textExtensions = ["html", "htm", "css", "js", "txt", "json", "xml", "svg", "md"]
        return textExtensions.contains(fileExtension.lowercased())
    }

    /// Determines if the file extension represents an image file.
    ///
    /// - Parameter fileExtension: The file extension (without the dot)
    /// - Returns: `true` if the file is an image, `false` otherwise
    ///
    /// Supported image formats include PNG, JPEG, GIF, SVG, WebP, and ICO files.
    public static func isImageFile(_ fileExtension: String) -> Bool {
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "svg", "webp", "ico"]
        return imageExtensions.contains(fileExtension.lowercased())
    }
}
