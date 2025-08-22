import Foundation
import Vapor

/// Configuration for OpenID Connect (OIDC) authentication.
///
/// This struct encapsulates the necessary configuration parameters for connecting to an OIDC provider
/// such as AWS Cognito or Dex. It supports both production and development environments with
/// appropriate defaults.
///
/// ## Usage
///
/// Create configuration from environment variables:
///
/// ```swift
/// let config = OIDCConfiguration.create(from: app.environment)
/// ```
///
/// Or create manually:
///
/// ```swift
/// let config = OIDCConfiguration(
///     issuer: "https://cognito-idp.us-west-2.amazonaws.com/us-west-2_pool",
///     clientId: "your-client-id",
///     audienceId: "your-client-id"
/// )
/// ```
public struct OIDCConfiguration: Sendable {
    /// The OIDC issuer URL.
    ///
    /// This identifies the OIDC provider and is used to validate JWT tokens.
    /// For AWS Cognito, this follows the format: `https://cognito-idp.{region}.amazonaws.com/{userPoolId}`
    public let issuer: String

    /// The OIDC client ID.
    ///
    /// This identifies your application to the OIDC provider.
    public let clientId: String

    /// The OIDC audience ID.
    ///
    /// This identifies the intended audience for JWT tokens (typically the same as clientId).
    public let audienceId: String

    /// Creates a new OIDC configuration with the specified parameters.
    ///
    /// - Parameters:
    ///   - issuer: The OIDC issuer URL
    ///   - clientId: The OIDC client ID
    ///   - audienceId: The OIDC audience ID
    public init(issuer: String, clientId: String, audienceId: String) {
        self.issuer = issuer
        self.clientId = clientId
        self.audienceId = audienceId
    }

    /// Creates an OIDC configuration from environment variables.
    ///
    /// This method automatically detects the environment and uses appropriate defaults:
    ///
    /// **Production Environment (ENV=PRODUCTION):**
    /// - Uses AWS Cognito configuration
    /// - Environment variables: `COGNITO_ISSUER`, `COGNITO_CLIENT_ID`
    ///
    /// **Development Environment (default):**
    /// - Uses Dex configuration for local development
    /// - Environment variables: `DEX_ISSUER`, `DEX_CLIENT_ID`
    ///
    /// - Parameter environment: The Vapor environment to configure for
    /// - Returns: A configured `OIDCConfiguration` instance
    public static func create(from environment: Environment) -> OIDCConfiguration {
        let env = Environment.get("ENV") ?? "DEVELOPMENT"

        if env == "PRODUCTION" {
            let clientId = Environment.get("COGNITO_CLIENT_ID") ?? ""
            return OIDCConfiguration(
                issuer: Environment.get("COGNITO_ISSUER")
                    ?? "https://cognito-idp.us-west-2.amazonaws.com/us-west-2_sagebrush-cognito",
                clientId: clientId,
                audienceId: clientId
            )
        } else {
            let clientId = Environment.get("DEX_CLIENT_ID") ?? "luxe-client"
            return OIDCConfiguration(
                issuer: Environment.get("DEX_ISSUER") ?? "http://localhost:2222/dex",
                clientId: clientId,
                audienceId: clientId
            )
        }
    }
}
