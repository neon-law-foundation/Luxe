import Dali
import Foundation
import Vapor

/// Validates AWS ALB/Cognito OIDC headers for authentication
public struct ALBHeaderValidator: Sendable {

    /// Required ALB OIDC headers
    public enum RequiredHeader: String, CaseIterable {
        case oidcData = "x-amzn-oidc-data"
        case oidcAccessToken = "x-amzn-oidc-accesstoken"
        case oidcIdentity = "x-amzn-oidc-identity"

        var displayName: String {
            switch self {
            case .oidcData: return "OIDC Data"
            case .oidcAccessToken: return "OIDC Access Token"
            case .oidcIdentity: return "OIDC Identity"
            }
        }
    }

    /// Validation result for ALB headers
    public struct ValidationResult {
        public let isValid: Bool
        public let errors: [String]
        public let warnings: [String]
        public let extractedData: ExtractedData?

        public struct ExtractedData {
            public let cognitoSub: String
            public let email: String?
            public let name: String?
            public let cognitoGroups: [String]
            public let username: String

            /// Converts to CognitoData for database operations
            public func toCognitoData(albHeaders: [String: String] = [:]) -> CognitoUserService.CognitoData {
                CognitoUserService.CognitoData(
                    cognitoSub: cognitoSub,
                    cognitoGroups: cognitoGroups,
                    username: username,
                    email: email ?? username,
                    name: name,
                    albHeaders: albHeaders
                )
            }
        }

        public var hasErrors: Bool { !errors.isEmpty }
        public var hasWarnings: Bool { !warnings.isEmpty }
    }

    private let logger: Logger
    private let requireAllHeaders: Bool

    public init(logger: Logger, requireAllHeaders: Bool = false) {
        self.logger = logger
        self.requireAllHeaders = requireAllHeaders
    }

    /// Validates ALB OIDC headers in the request
    public func validate(request: Request) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []

        // Extract headers
        let headers = extractHeaders(from: request)

        // Validate required headers presence
        let (headerErrors, headerWarnings) = validateHeadersPresence(headers)
        errors.append(contentsOf: headerErrors)
        warnings.append(contentsOf: headerWarnings)

        // If we have critical headers, try to extract and validate data
        var extractedData: ValidationResult.ExtractedData?
        if let oidcData = headers[.oidcData] {
            let (dataErrors, dataWarnings, data) = validateOIDCData(oidcData)
            errors.append(contentsOf: dataErrors)
            warnings.append(contentsOf: dataWarnings)
            extractedData = data
        }

        // Validate consistency between headers
        if let identity = headers[.oidcIdentity], let data = extractedData {
            let consistencyErrors = validateHeaderConsistency(identity: identity, extractedData: data)
            errors.append(contentsOf: consistencyErrors)
        }

        let isValid = errors.isEmpty

        logger.debug(
            "ALB header validation",
            metadata: [
                "valid": .string(String(isValid)),
                "error_count": .string(String(errors.count)),
                "warning_count": .string(String(warnings.count)),
            ]
        )

        return ValidationResult(
            isValid: isValid,
            errors: errors,
            warnings: warnings,
            extractedData: extractedData
        )
    }

    /// Extracts ALB headers from the request
    private func extractHeaders(from request: Request) -> [RequiredHeader: String] {
        var headers: [RequiredHeader: String] = [:]

        for header in RequiredHeader.allCases {
            if let value = request.headers.first(name: header.rawValue) {
                headers[header] = value
            }
        }

        return headers
    }

    /// Validates the presence of required headers
    private func validateHeadersPresence(_ headers: [RequiredHeader: String]) -> (errors: [String], warnings: [String])
    {
        var errors: [String] = []
        var warnings: [String] = []

        // OIDC Data is absolutely required
        if headers[.oidcData] == nil {
            errors.append("Missing required header: \(RequiredHeader.oidcData.rawValue)")
        }

        // Other headers are optional but recommended
        if requireAllHeaders {
            for header in RequiredHeader.allCases where header != .oidcData {
                if headers[header] == nil {
                    errors.append("Missing required header: \(header.rawValue)")
                }
            }
        } else {
            for header in RequiredHeader.allCases where header != .oidcData {
                if headers[header] == nil {
                    warnings.append("Missing optional header: \(header.rawValue)")
                }
            }
        }

        return (errors, warnings)
    }

    /// Validates and parses OIDC data from ALB header
    private func validateOIDCData(
        _ oidcData: String
    ) -> (errors: [String], warnings: [String], data: ValidationResult.ExtractedData?) {
        var errors: [String] = []
        let warnings: [String] = []

        // Basic format validation
        guard !oidcData.isEmpty else {
            errors.append("OIDC data header is empty")
            return (errors, warnings, nil)
        }

        // Try to decode JWT payload (ALB provides base64-encoded JWT)
        do {
            let payload = try decodeALBJWTPayload(oidcData)
            let extractedData = try createExtractedData(from: payload)

            // Validate payload contents
            let payloadErrors = validatePayloadContents(payload)
            errors.append(contentsOf: payloadErrors)

            return (errors, warnings, extractedData)
        } catch {
            errors.append("Failed to decode OIDC data: \(error.localizedDescription)")
            return (errors, warnings, nil)
        }
    }

    /// Validates consistency between different headers
    private func validateHeaderConsistency(identity: String, extractedData: ValidationResult.ExtractedData) -> [String]
    {
        var errors: [String] = []

        // Identity header should match username or email from JWT
        if !identity.isEmpty && identity != extractedData.username && identity != extractedData.email {
            errors.append("OIDC identity header '\(identity)' does not match JWT data")
        }

        return errors
    }

    /// Decodes ALB JWT payload (simplified - ALB handles signature verification)
    private func decodeALBJWTPayload(_ tokenData: String) throws -> ALBJWTPayload {
        // ALB provides the JWT token, we need to extract the payload
        // For development, we might get base64-encoded payload directly

        let parts = tokenData.components(separatedBy: ".")
        guard parts.count >= 2 else {
            throw ValidationError("Invalid JWT format - expected 3 parts separated by dots")
        }

        // Decode the payload part (second part)
        let payloadPart = parts[1]
        guard let payloadData = Data(base64URLEncodedString: payloadPart) else {
            throw ValidationError("Failed to decode JWT payload from base64")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        return try decoder.decode(ALBJWTPayload.self, from: payloadData)
    }

    /// Creates extracted data from JWT payload
    private func createExtractedData(from payload: ALBJWTPayload) throws -> ValidationResult.ExtractedData {
        guard let sub = payload.sub else {
            throw ValidationError("Missing 'sub' claim in JWT payload")
        }

        return ValidationResult.ExtractedData(
            cognitoSub: sub,
            email: payload.email,
            name: payload.name,
            cognitoGroups: payload.cognitoGroups ?? [],
            username: payload.email ?? payload.preferredUsername ?? sub
        )
    }

    /// Validates JWT payload contents
    private func validatePayloadContents(_ payload: ALBJWTPayload) -> [String] {
        var errors: [String] = []

        // Validate required claims
        if payload.sub == nil || payload.sub?.isEmpty == true {
            errors.append("Missing or empty 'sub' claim in JWT")
        }

        if payload.email == nil || payload.email?.isEmpty == true {
            errors.append("Missing or empty 'email' claim in JWT")
        }

        // Validate expiration
        if let exp = payload.exp, exp < Date() {
            errors.append("JWT token has expired")
        }

        // Validate issuer format (should be Cognito User Pool)
        if let iss = payload.iss, !iss.contains("cognito") {
            errors.append("Unexpected issuer in JWT: \(iss)")
        }

        return errors
    }
}

// MARK: - JWT Payload Structure

/// Simplified JWT payload structure for ALB OIDC data
public struct ALBJWTPayload: Codable {
    public let iss: String?  // Issuer
    public let aud: String?  // Audience
    public let exp: Date?  // Expiration
    public let sub: String?  // Subject (Cognito User ID)
    public let email: String?  // User email
    public let name: String?  // Display name
    public let preferredUsername: String?  // Preferred username
    public let cognitoGroups: [String]?  // Cognito groups

    enum CodingKeys: String, CodingKey {
        case iss, aud, exp, sub, email, name
        case preferredUsername = "preferred_username"
        case cognitoGroups = "cognito:groups"
    }
}

// MARK: - Base64 URL Decoding Extension

extension Data {
    init?(base64URLEncodedString string: String) {
        var base64 =
            string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if necessary
        while base64.count % 4 != 0 {
            base64 += "="
        }

        self.init(base64Encoded: base64)
    }
}
