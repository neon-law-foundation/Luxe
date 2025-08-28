import Foundation
import Logging
import Testing
import Vapor

@testable import PitBoss

@Suite("RateLimiter Tests")
struct RateLimiterTests {

    @Test("Should allow requests within rate limit")
    func testAllowedRequests() async throws {
        // Arrange
        let logger = Logger(label: "test")
        let rateLimiter = RateLimiter(
            maxRequestsPerMinute: 60,
            maxBurst: 10,
            logger: logger
        )

        // Act & Assert
        for _ in 0..<10 {
            let status = await rateLimiter.checkLimit()
            #expect(status == .allowed)
        }
    }

    @Test("Should enforce burst limit")
    func testBurstLimit() async throws {
        // Arrange
        let logger = Logger(label: "test")
        let rateLimiter = RateLimiter(
            maxRequestsPerMinute: 60,
            maxBurst: 5,
            logger: logger
        )

        // Act - Make requests up to burst limit
        for _ in 0..<5 {
            let status = await rateLimiter.checkLimit()
            #expect(status == .allowed)
        }

        // Assert - Next request should be rate limited
        let limitedStatus = await rateLimiter.checkLimit()
        if case .limited(let retryAfter) = limitedStatus {
            #expect(retryAfter > 0)
        } else {
            #expect(Bool(false), "Expected rate limited status")
        }
    }

    @Test("Should reset rate limits")
    func testReset() async throws {
        // Arrange
        let logger = Logger(label: "test")
        let rateLimiter = RateLimiter(
            maxRequestsPerMinute: 60,
            maxBurst: 5,
            logger: logger
        )

        // Fill up the burst limit
        for _ in 0..<5 {
            _ = await rateLimiter.checkLimit()
        }

        // Act - Reset the limiter
        await rateLimiter.reset()

        // Assert - Should allow requests again
        let status = await rateLimiter.checkLimit()
        #expect(status == .allowed)
    }

    @Test("Should provide accurate statistics")
    func testStatistics() async throws {
        // Arrange
        let logger = Logger(label: "test")
        let rateLimiter = RateLimiter(
            maxRequestsPerMinute: 60,
            maxBurst: 10,
            logger: logger
        )

        // Act - Make some requests
        for _ in 0..<5 {
            _ = await rateLimiter.checkLimit()
        }

        let stats = await rateLimiter.getStats()

        // Assert
        #expect(stats.currentRequests == 5)
        #expect(stats.maxRequests == 60)
        #expect(stats.maxBurst == 10)
        #expect(stats.utilizationPercentage > 0)
        #expect(stats.utilizationPercentage < 10)  // 5/60 = 8.3%
    }

    @Test("Should handle middleware integration")
    func testMiddleware() async throws {
        // Arrange
        let app = try await Application.make(.testing)
        defer {
            Task {
                try await app.asyncShutdown()
            }
        }

        let logger = Logger(label: "test")
        let rateLimiter = RateLimiter(
            maxRequestsPerMinute: 60,
            maxBurst: 3,
            logger: logger
        )

        let middleware = RateLimitMiddleware(rateLimiter: rateLimiter, logger: logger)
        app.middleware.use(middleware)

        app.get("test") { req in
            "OK"
        }

        // Act - Make requests up to limit
        for _ in 0..<3 {
            try await app.test(.GET, "/test") { res in
                #expect(res.status == .ok)
            }
        }

        // Assert - Next request should be rate limited
        try await app.test(.GET, "/test") { res in
            #expect(res.status == .tooManyRequests)
            #expect(res.headers["X-RateLimit-Limit"].first != nil)
            #expect(res.headers["Retry-After"].first != nil)
        }
    }
}
