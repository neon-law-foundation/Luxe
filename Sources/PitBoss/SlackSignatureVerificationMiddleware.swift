import Crypto
import Foundation
import Vapor

/// Middleware for verifying Slack request signatures
public struct SlackSignatureVerificationMiddleware: AsyncMiddleware {
    private let signingSecret: String
    private let maxTimestampAge: TimeInterval

    public init(signingSecret: String, maxTimestampAge: TimeInterval = 300) {  // 5 minutes default
        self.signingSecret = signingSecret
        self.maxTimestampAge = maxTimestampAge
    }

    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Skip verification for health checks
        if request.url.string.contains("/health") {
            return try await next.respond(to: request)
        }

        // Extract required headers
        guard let slackSignature = request.headers["X-Slack-Signature"].first,
            let timestampString = request.headers["X-Slack-Request-Timestamp"].first,
            let timestamp = TimeInterval(timestampString)
        else {
            request.logger.warning(
                "Missing Slack signature headers",
                metadata: [
                    "path": .string(request.url.string),
                    "headers": .dictionary(
                        Dictionary(
                            request.headers.map { ($0.name, .string($0.value)) },
                            uniquingKeysWith: { first, _ in first }
                        )
                    ),
                ]
            )
            throw Abort(.unauthorized, reason: "Missing required Slack signature headers")
        }

        // Check timestamp to prevent replay attacks
        let currentTime = Date().timeIntervalSince1970
        let timeDifference = abs(currentTime - timestamp)

        if timeDifference > maxTimestampAge {
            request.logger.warning(
                "Slack request timestamp too old",
                metadata: [
                    "timestamp": .string(timestampString),
                    "currentTime": .string("\(currentTime)"),
                    "difference": .string("\(timeDifference)s"),
                ]
            )
            throw Abort(.unauthorized, reason: "Request timestamp is too old")
        }

        // Get the raw body
        guard let bodyData = request.body.data else {
            request.logger.warning("Missing request body for signature verification")
            throw Abort(.badRequest, reason: "Request body is required")
        }

        // Reconstruct the signature base string
        let bodyString = String(data: Data(bodyData.readableBytesView), encoding: .utf8) ?? ""
        let baseString = "v0:\(timestampString):\(bodyString)"

        // Generate the signature
        let key = SymmetricKey(data: signingSecret.data(using: .utf8)!)
        let signature = HMAC<SHA256>.authenticationCode(
            for: baseString.data(using: .utf8)!,
            using: key
        )

        // Format as hex string with v0= prefix
        let computedSignature = "v0=" + signature.compactMap { String(format: "%02x", $0) }.joined()

        // Compare signatures (constant time comparison to prevent timing attacks)
        guard constantTimeCompare(slackSignature, computedSignature) else {
            request.logger.warning(
                "Invalid Slack signature",
                metadata: [
                    "providedSignature": .string(String(slackSignature.prefix(20)) + "..."),
                    "path": .string(request.url.string),
                ]
            )
            throw Abort(.unauthorized, reason: "Invalid request signature")
        }

        request.logger.debug(
            "Slack signature verified successfully",
            metadata: [
                "path": .string(request.url.string)
            ]
        )

        return try await next.respond(to: request)
    }

    /// Constant-time string comparison to prevent timing attacks
    private func constantTimeCompare(_ a: String, _ b: String) -> Bool {
        guard a.count == b.count else { return false }

        var result = 0
        for (charA, charB) in zip(a.utf8, b.utf8) {
            result |= Int(charA ^ charB)
        }

        return result == 0
    }
}

// MARK: - Request Extensions

extension Request {
    /// Extract Slack timestamp from request headers
    public var slackTimestamp: TimeInterval? {
        guard let timestampString = headers["X-Slack-Request-Timestamp"].first else {
            return nil
        }
        return TimeInterval(timestampString)
    }

    /// Extract Slack signature from request headers
    public var slackSignature: String? {
        headers["X-Slack-Signature"].first
    }

    /// Check if this is a Slack URL verification request
    public var isSlackURLVerification: Bool {
        guard let contentType = headers.contentType,
            contentType.type == "application" && contentType.subType == "json"
        else {
            return false
        }

        // Try to decode and check for url_verification type
        if let bodyData = body.data,
            let payload = try? JSONDecoder().decode(SlackWebhookPayload.self, from: Data(bodyData.readableBytesView)),
            payload.type == "url_verification"
        {
            return true
        }

        return false
    }
}
