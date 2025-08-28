import Logging
import Vapor

/// Rate limiter for Slack API calls
public actor RateLimiter {
    private let logger: Logger
    private let maxRequestsPerMinute: Int
    private let maxBurst: Int

    private var requestTimestamps: [Date] = []
    private var burstTokens: Int

    public init(
        maxRequestsPerMinute: Int = 60,
        maxBurst: Int = 10,
        logger: Logger
    ) {
        self.logger = logger
        self.maxRequestsPerMinute = maxRequestsPerMinute
        self.maxBurst = maxBurst
        self.burstTokens = maxBurst
    }

    /// Check if a request can proceed based on rate limits
    public func checkLimit() async -> RateLimitStatus {
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)

        // Clean up old timestamps
        requestTimestamps = requestTimestamps.filter { $0 > oneMinuteAgo }

        // Check per-minute limit
        if requestTimestamps.count >= maxRequestsPerMinute {
            let oldestAllowed = requestTimestamps.first ?? now
            let retryAfter = Int(oldestAllowed.timeIntervalSince(oneMinuteAgo))

            logger.warning(
                "Rate limit exceeded",
                metadata: [
                    "requests": .string("\(requestTimestamps.count)"),
                    "limit": .string("\(maxRequestsPerMinute)"),
                    "retryAfter": .string("\(retryAfter)s"),
                ]
            )

            return .limited(retryAfter: retryAfter)
        }

        // Check burst limit
        let recentRequests = requestTimestamps.filter { $0 > now.addingTimeInterval(-1) }
        if recentRequests.count >= maxBurst {
            logger.warning(
                "Burst limit exceeded",
                metadata: [
                    "recentRequests": .string("\(recentRequests.count)"),
                    "burstLimit": .string("\(maxBurst)"),
                ]
            )

            return .limited(retryAfter: 1)
        }

        // Record this request
        requestTimestamps.append(now)

        // Refill burst tokens slowly
        if burstTokens < maxBurst {
            burstTokens += 1
        }

        logger.debug(
            "Rate limit check passed",
            metadata: [
                "currentRequests": .string("\(requestTimestamps.count)"),
                "burstTokens": .string("\(burstTokens)"),
            ]
        )

        return .allowed
    }

    /// Reset rate limits (useful for testing)
    public func reset() {
        requestTimestamps = []
        burstTokens = maxBurst
        logger.info("Rate limiter reset")
    }

    /// Get current usage statistics
    public func getStats() -> RateLimitStats {
        let now = Date()
        let oneMinuteAgo = now.addingTimeInterval(-60)
        let activeRequests = requestTimestamps.filter { $0 > oneMinuteAgo }

        return RateLimitStats(
            currentRequests: activeRequests.count,
            maxRequests: maxRequestsPerMinute,
            burstTokens: burstTokens,
            maxBurst: maxBurst
        )
    }
}

public enum RateLimitStatus: Sendable, Equatable {
    case allowed
    case limited(retryAfter: Int)  // seconds
}

public struct RateLimitStats: Sendable, Content {
    public let currentRequests: Int
    public let maxRequests: Int
    public let burstTokens: Int
    public let maxBurst: Int

    public var utilizationPercentage: Double {
        Double(currentRequests) / Double(maxRequests) * 100
    }
}

/// Middleware for applying rate limiting to routes
public struct RateLimitMiddleware: AsyncMiddleware {
    private let rateLimiter: RateLimiter
    private let logger: Logger

    public init(rateLimiter: RateLimiter, logger: Logger) {
        self.rateLimiter = rateLimiter
        self.logger = logger
    }

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let status = await rateLimiter.checkLimit()

        switch status {
        case .allowed:
            return try await next.respond(to: request)

        case .limited(let retryAfter):
            logger.warning(
                "Request rate limited",
                metadata: [
                    "path": .string(request.url.string),
                    "method": .string(request.method.rawValue),
                    "retryAfter": .string("\(retryAfter)s"),
                ]
            )

            var headers = HTTPHeaders()
            headers.add(name: "X-RateLimit-Limit", value: "60")
            headers.add(name: "X-RateLimit-Remaining", value: "0")
            headers.add(name: "X-RateLimit-Reset", value: "\(Int(Date().timeIntervalSince1970) + retryAfter)")
            headers.add(name: "Retry-After", value: "\(retryAfter)")

            let response = Response(
                status: .tooManyRequests,
                headers: headers,
                body: .init(string: "Rate limit exceeded. Please retry after \(retryAfter) seconds.")
            )

            return response
        }
    }
}
