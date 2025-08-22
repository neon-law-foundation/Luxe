import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Native Swift HTTP client for performing health checks and redirect verification.
///
/// ## Overview
/// This class provides methods for checking service health endpoints and verifying
/// HTTP redirects to S3 static pages during Holiday mode operations.
///
/// ## Features
/// - Health check for `/health` endpoints
/// - Redirect verification for vacation mode
/// - Configurable timeout and retry logic
/// - Native Swift implementation using URLSession
public final class HTTPHealthChecker: @unchecked Sendable {
    private let session: URLSession
    private let timeout: TimeInterval

    /// Initializes the health checker with configurable timeout.
    ///
    /// - Parameter timeout: Request timeout in seconds (default: 10)
    public init(timeout: TimeInterval = 10) {
        self.timeout = timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout

        // Create a session that doesn't automatically follow redirects
        // so we can detect and analyze redirect responses
        self.session = URLSession(
            configuration: config,
            delegate: HTTPHealthCheckerDelegate(),
            delegateQueue: nil
        )
    }

    /// Checks the health of a service endpoint.
    ///
    /// - Parameter url: The URL to check (should include /health path)
    /// - Returns: HealthCheckResult indicating success, failure, or error
    public func checkHealth(url: URL) async -> HealthCheckResult {
        do {
            let (_, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .error("Invalid response type")
            }

            return .init(
                url: url,
                statusCode: httpResponse.statusCode,
                isHealthy: httpResponse.statusCode >= 200 && httpResponse.statusCode < 300,
                responseTime: nil  // URLSession doesn't provide easy timing
            )
        } catch {
            return .error("Request failed: \(error.localizedDescription)")
        }
    }

    /// Verifies that a URL redirects to the expected S3 static page.
    ///
    /// - Parameter url: The URL to check for redirects
    /// - Returns: RedirectCheckResult indicating the redirect status
    public func checkRedirect(url: URL) async -> RedirectCheckResult {
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"

            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .error("Invalid response type")
            }

            let isRedirect = httpResponse.statusCode >= 300 && httpResponse.statusCode < 400
            let location = httpResponse.value(forHTTPHeaderField: "Location")
            let isS3Redirect = location?.contains("sagebrush-public.s3") ?? false

            return .init(
                url: url,
                statusCode: httpResponse.statusCode,
                isRedirect: isRedirect,
                location: location,
                isS3Redirect: isS3Redirect
            )
        } catch {
            return .error("Request failed: \(error.localizedDescription)")
        }
    }

    /// Checks health for multiple URLs concurrently.
    ///
    /// - Parameter urls: Array of URLs to check
    /// - Returns: Array of HealthCheckResult in the same order as input
    public func checkHealthConcurrently(urls: [URL]) async -> [HealthCheckResult] {
        await withTaskGroup(of: (Int, HealthCheckResult).self, returning: [HealthCheckResult].self) { group in
            for (index, url) in urls.enumerated() {
                group.addTask { [self] in
                    let result = await self.checkHealth(url: url)
                    return (index, result)
                }
            }

            var results = [HealthCheckResult?](repeating: nil, count: urls.count)
            for await (index, result) in group {
                results[index] = result
            }

            return results.compactMap { $0 }
        }
    }

    /// Checks redirects for multiple URLs concurrently.
    ///
    /// - Parameter urls: Array of URLs to check
    /// - Returns: Array of RedirectCheckResult in the same order as input
    public func checkRedirectsConcurrently(urls: [URL]) async -> [RedirectCheckResult] {
        await withTaskGroup(of: (Int, RedirectCheckResult).self, returning: [RedirectCheckResult].self) { group in
            for (index, url) in urls.enumerated() {
                group.addTask { [self] in
                    let result = await self.checkRedirect(url: url)
                    return (index, result)
                }
            }

            var results = [RedirectCheckResult?](repeating: nil, count: urls.count)
            for await (index, result) in group {
                results[index] = result
            }

            return results.compactMap { $0 }
        }
    }
}

/// Result of a health check operation.
public enum HealthCheckResult: Sendable {
    case success(url: URL, statusCode: Int, responseTime: TimeInterval?)
    case failure(url: URL, statusCode: Int, responseTime: TimeInterval?)
    case error(String)

    /// Convenience initializer for creating results based on health status.
    init(url: URL, statusCode: Int, isHealthy: Bool, responseTime: TimeInterval?) {
        if isHealthy {
            self = .success(url: url, statusCode: statusCode, responseTime: responseTime)
        } else {
            self = .failure(url: url, statusCode: statusCode, responseTime: responseTime)
        }
    }

    /// Whether the health check was successful.
    public var isHealthy: Bool {
        switch self {
        case .success:
            return true
        case .failure, .error:
            return false
        }
    }

    /// The URL that was checked (if available).
    public var url: URL? {
        switch self {
        case .success(let url, _, _), .failure(let url, _, _):
            return url
        case .error:
            return nil
        }
    }

    /// The HTTP status code (if available).
    public var statusCode: Int? {
        switch self {
        case .success(_, let code, _), .failure(_, let code, _):
            return code
        case .error:
            return nil
        }
    }
}

/// URLSessionDelegate that prevents automatic redirect following.
///
/// This delegate allows us to capture redirect responses (3xx status codes)
/// instead of automatically following them, which is essential for verifying
/// that ALB rules are correctly configured to redirect to S3.
private final class HTTPHealthCheckerDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        // Return nil to prevent automatic redirect following
        // This allows us to inspect the redirect response
        completionHandler(nil)
    }
}

/// Result of a redirect check operation.
public enum RedirectCheckResult: Sendable {
    case redirect(url: URL, statusCode: Int, location: String, isS3: Bool)
    case noRedirect(url: URL, statusCode: Int)
    case error(String)

    /// Convenience initializer for creating results based on redirect status.
    init(url: URL, statusCode: Int, isRedirect: Bool, location: String?, isS3Redirect: Bool) {
        if isRedirect, let location = location {
            self = .redirect(url: url, statusCode: statusCode, location: location, isS3: isS3Redirect)
        } else {
            self = .noRedirect(url: url, statusCode: statusCode)
        }
    }

    /// Whether the check found a valid redirect.
    public var isRedirecting: Bool {
        switch self {
        case .redirect:
            return true
        case .noRedirect, .error:
            return false
        }
    }

    /// Whether the redirect points to S3 (for vacation mode verification).
    public var isS3Redirect: Bool {
        switch self {
        case .redirect(_, _, _, let isS3):
            return isS3
        case .noRedirect, .error:
            return false
        }
    }

    /// The URL that was checked (if available).
    public var url: URL? {
        switch self {
        case .redirect(let url, _, _, _), .noRedirect(let url, _):
            return url
        case .error:
            return nil
        }
    }

    /// The HTTP status code (if available).
    public var statusCode: Int? {
        switch self {
        case .redirect(_, let code, _, _), .noRedirect(_, let code):
            return code
        case .error:
            return nil
        }
    }

    /// The redirect location (if available).
    public var location: String? {
        switch self {
        case .redirect(_, _, let location, _):
            return location
        case .noRedirect, .error:
            return nil
        }
    }
}
