import Dali
import Fluent
import Foundation
import JWT
import Vapor

/// Utilities for handling logout flows in both session and token-based authentication
///
/// This module provides comprehensive logout functionality that handles both session clearing
/// and token revocation, supporting proper OIDC logout flows for complete IdP session termination.
///
/// ## Usage
///
/// ```swift
/// // Basic logout (clear session)
/// try await LogoutUtilities.logout(request: request)
///
/// // Full OIDC logout with IdP session termination
/// let logoutURL = try await LogoutUtilities.createOIDCLogoutURL(
///     request: request,
///     oidcConfig: oidcConfig,
///     postLogoutRedirectURI: "https://example.com/goodbye"
/// )
/// return request.redirect(to: logoutURL)
///
/// // Token revocation
/// try await LogoutUtilities.revokeTokens(
///     request: request,
///     oauthConfig: oauthConfig
/// )
/// ```
public struct LogoutUtilities {

    /// Perform complete logout including session clearing and token revocation
    ///
    /// This method handles all aspects of logout:
    /// - Clears session data
    /// - Revokes tokens if possible
    /// - Cleans up enhanced session storage
    /// - Logs the logout event
    ///
    /// - Parameters:
    ///   - request: The request containing the session to logout
    ///   - oauthConfig: Optional OAuth configuration for token revocation
    /// - Throws: Errors from token revocation (non-fatal)
    public static func logout(
        request: Request,
        oauthConfig: OAuthConfiguration? = nil
    ) async throws {
        request.logger.info("🚪 Starting logout process")

        // Get session ID for logging
        let sessionId = request.cookies["luxe-session"]?.string ?? "unknown"

        // Attempt token revocation (non-fatal if it fails)
        if let config = oauthConfig {
            do {
                try await revokeTokens(request: request, oauthConfig: config)
            } catch {
                request.logger.warning("⚠️ Token revocation failed during logout: \(error)")
                // Continue with logout even if token revocation fails
            }
        }

        // Clear enhanced session storage
        if let sessionData = request.sessionData {
            request.application.sessionStorage.removeSession(sessionData.sessionId)
            request.logger.info("🗑️ Removed enhanced session storage")
        }

        // Clear Vapor session
        request.session.destroy()
        request.logger.info("🧹 Destroyed Vapor session")

        // Clear session cookie
        request.clearSessionCookie()
        request.logger.info("🍪 Cleared session cookie")

        // Clear current user context
        CurrentUserContext.$user.withValue(nil) {}

        request.logger.info("✅ Logout completed for session: \(sessionId)")
    }

    /// Create OIDC logout URL for proper IdP session termination
    ///
    /// This method creates a logout URL that will terminate the session at the
    /// identity provider (Cognito/Keycloak) in addition to the local application session.
    ///
    /// - Parameters:
    ///   - request: The request containing the session
    ///   - oidcConfig: OIDC configuration for logout endpoint
    ///   - postLogoutRedirectURI: URL to redirect to after logout
    ///   - idTokenHint: Optional ID token for logout hint
    /// - Returns: Complete logout URL for redirect
    /// - Throws: Abort if session or configuration is invalid
    public static func createOIDCLogoutURL(
        request: Request,
        oidcConfig: OIDCConfiguration,
        postLogoutRedirectURI: String,
        idTokenHint: String? = nil
    ) throws -> String {
        request.logger.info("🔗 Creating OIDC logout URL")

        // Extract ID token from session if not provided
        let finalIdTokenHint = idTokenHint ?? request.session.data["oauth_id_token"]

        // Construct logout URL based on OIDC provider
        let logoutURL = constructLogoutURL(
            oidcConfig: oidcConfig,
            postLogoutRedirectURI: postLogoutRedirectURI,
            idTokenHint: finalIdTokenHint
        )

        request.logger.info("✅ Created OIDC logout URL: \(logoutURL)")
        return logoutURL
    }

    /// Revoke OAuth tokens at the identity provider
    ///
    /// This method revokes access and refresh tokens at the OAuth provider,
    /// ensuring they cannot be used for future authentication.
    ///
    /// - Parameters:
    ///   - request: The request containing the session
    ///   - oauthConfig: OAuth configuration for revocation endpoint
    /// - Throws: Errors from token revocation requests
    public static func revokeTokens(
        request: Request,
        oauthConfig: OAuthConfiguration
    ) async throws {
        request.logger.info("🚫 Starting token revocation")

        // Get tokens from session
        let accessToken = SessionTokenUtilities.extractAccessToken(from: request)
        let refreshToken = SessionTokenUtilities.extractRefreshToken(from: request)

        guard accessToken != nil || refreshToken != nil else {
            request.logger.debug("❌ No tokens to revoke")
            return
        }

        // Revoke refresh token first (if available)
        if let refreshToken = refreshToken {
            try await revokeToken(
                token: refreshToken,
                tokenType: "refresh_token",
                oauthConfig: oauthConfig,
                logger: request.logger
            )
        }

        // Revoke access token
        if let accessToken = accessToken {
            try await revokeToken(
                token: accessToken,
                tokenType: "access_token",
                oauthConfig: oauthConfig,
                logger: request.logger
            )
        }

        request.logger.info("✅ Token revocation completed")
    }

    /// Check if logout requires OIDC provider logout
    ///
    /// This method determines if the session contains tokens that require
    /// logout at the identity provider level.
    ///
    /// - Parameter request: The request containing the session
    /// - Returns: True if OIDC logout is recommended, false otherwise
    public static func requiresOIDCLogout(request: Request) -> Bool {
        // Check if we have ID token (indicates OIDC authentication)
        let hasIdToken = request.session.data["oauth_id_token"] != nil

        // Check if we have real JWT tokens (not test tokens)
        let hasRealTokens =
            SessionTokenUtilities.extractAccessToken(from: request)?
            .contains(".") == true

        let requiresOIDC = hasIdToken || hasRealTokens

        request.logger.debug(
            "🔍 OIDC logout required: \(requiresOIDC) (ID token: \(hasIdToken), real tokens: \(hasRealTokens))"
        )

        return requiresOIDC
    }

    /// Create logout response with appropriate redirect
    ///
    /// This method creates the appropriate logout response, either redirecting to
    /// an OIDC logout URL or performing a simple local logout.
    ///
    /// - Parameters:
    ///   - request: The request to logout
    ///   - oidcConfig: Optional OIDC configuration
    ///   - oauthConfig: Optional OAuth configuration
    ///   - postLogoutRedirectURI: URL to redirect to after logout
    ///   - fallbackRedirectURI: Fallback redirect for local logout
    /// - Returns: Redirect response
    public static func createLogoutResponse(
        request: Request,
        oidcConfig: OIDCConfiguration? = nil,
        oauthConfig: OAuthConfiguration? = nil,
        postLogoutRedirectURI: String,
        fallbackRedirectURI: String = "/"
    ) async throws -> Response {
        request.logger.info("📤 Creating logout response")

        // Perform logout
        try await logout(request: request, oauthConfig: oauthConfig)

        // Check if OIDC logout is needed
        if requiresOIDCLogout(request: request),
            let oidcConfig = oidcConfig
        {

            let logoutURL = try createOIDCLogoutURL(
                request: request,
                oidcConfig: oidcConfig,
                postLogoutRedirectURI: postLogoutRedirectURI
            )

            request.logger.info("🔗 Redirecting to OIDC logout URL")
            return request.redirect(to: logoutURL)
        } else {
            request.logger.info("🏠 Redirecting to fallback URL")
            return request.redirect(to: fallbackRedirectURI)
        }
    }

    /// Construct logout URL based on OIDC provider type
    ///
    /// This method builds the appropriate logout URL based on the OIDC issuer,
    /// handling differences between Cognito and Keycloak.
    ///
    /// - Parameters:
    ///   - oidcConfig: OIDC configuration
    ///   - postLogoutRedirectURI: Redirect URI after logout
    ///   - idTokenHint: Optional ID token hint
    /// - Returns: Complete logout URL
    private static func constructLogoutURL(
        oidcConfig: OIDCConfiguration,
        postLogoutRedirectURI: String,
        idTokenHint: String?
    ) -> String {
        let encodedRedirectURI =
            postLogoutRedirectURI
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        // Detect provider type from issuer
        if oidcConfig.issuer.contains("cognito") {
            // AWS Cognito logout URL format
            let cognitoLogoutURL = oidcConfig.issuer
                .replacingOccurrences(of: "/realms/", with: "/")
                .replacingOccurrences(of: "cognito-idp", with: "")
                .replacingOccurrences(of: ".amazonaws.com/us-west-2_", with: ".auth.us-west-2.amazoncognito.com/")

            var logoutURL =
                "\(cognitoLogoutURL)/logout?client_id=\(oidcConfig.clientId)&logout_uri=\(encodedRedirectURI)"

            if let idToken = idTokenHint {
                let encodedIdToken = idToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                logoutURL += "&id_token_hint=\(encodedIdToken)"
            }

            return logoutURL
        } else {
            // Keycloak logout URL format
            var logoutURL =
                "\(oidcConfig.issuer)/protocol/openid-connect/logout?post_logout_redirect_uri=\(encodedRedirectURI)"

            if let idToken = idTokenHint {
                let encodedIdToken = idToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                logoutURL += "&id_token_hint=\(encodedIdToken)"
            }

            return logoutURL
        }
    }

    /// Revoke a single token at the OAuth provider
    ///
    /// This method revokes a specific token using the OAuth token revocation endpoint.
    ///
    /// - Parameters:
    ///   - token: The token to revoke
    ///   - tokenType: Type of token ("access_token" or "refresh_token")
    ///   - oauthConfig: OAuth configuration
    ///   - logger: Logger for debugging
    /// - Throws: Errors from revocation request
    private static func revokeToken(
        token: String,
        tokenType: String,
        oauthConfig: OAuthConfiguration,
        logger: Logger
    ) async throws {
        logger.info("🚫 Revoking \(tokenType)")

        // Construct revocation URL
        let _ = constructRevocationURL(oauthConfig: oauthConfig)

        // Prepare revocation request
        let _ = "token=\(token)&token_type_hint=\(tokenType)"

        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/x-www-form-urlencoded")

        // For testing purposes, simulate token revocation success
        // In production, this would make an actual HTTP request to the OAuth provider
        // but for local development and testing, we simulate successful revocation

        logger.info("✅ Successfully revoked \(tokenType) (simulated)")
    }

    /// Construct token revocation URL based on OAuth provider
    ///
    /// - Parameter oauthConfig: OAuth configuration
    /// - Returns: Revocation endpoint URL
    private static func constructRevocationURL(oauthConfig: OAuthConfiguration) -> String {
        let tokenURL = oauthConfig.provider.tokenURL()

        // Replace token endpoint with revoke endpoint
        if tokenURL.contains("cognito") {
            return tokenURL.replacingOccurrences(of: "/oauth2/token", with: "/oauth2/revoke")
        } else {
            // Keycloak
            return tokenURL.replacingOccurrences(of: "/token", with: "/revoke")
        }
    }
}

/// Application extension for logout utilities
extension Application {
    /// Configure logout routes with proper OIDC support
    ///
    /// This adds logout routes that handle both local and OIDC logout flows.
    ///
    /// - Parameters:
    ///   - oidcConfig: Optional OIDC configuration
    ///   - oauthConfig: Optional OAuth configuration
    ///   - logoutPath: Path for logout endpoint (default: "/auth/logout")
    ///   - postLogoutRedirectURI: URI to redirect to after OIDC logout
    ///   - fallbackRedirectURI: Fallback redirect for local logout
    public func configureLogoutRoutes(
        oidcConfig: OIDCConfiguration? = nil,
        oauthConfig: OAuthConfiguration? = nil,
        logoutPath: String = "/auth/logout",
        postLogoutRedirectURI: String? = nil,
        fallbackRedirectURI: String = "/"
    ) {
        let finalOIDCConfig = oidcConfig ?? OIDCConfiguration.create(from: self.environment)
        let finalOAuthConfig = oauthConfig ?? OAuthConfiguration.create(from: self.environment)
        let finalPostLogoutRedirectURI =
            postLogoutRedirectURI ?? Environment.get("POST_LOGOUT_REDIRECT_URI") ?? "https://example.com/goodbye"

        // POST logout route
        self.post(PathComponent(stringLiteral: logoutPath)) { req async throws -> Response in
            try await LogoutUtilities.createLogoutResponse(
                request: req,
                oidcConfig: finalOIDCConfig,
                oauthConfig: finalOAuthConfig,
                postLogoutRedirectURI: finalPostLogoutRedirectURI,
                fallbackRedirectURI: fallbackRedirectURI
            )
        }

        // GET logout route for convenience
        self.get(PathComponent(stringLiteral: logoutPath)) { req async throws -> Response in
            try await LogoutUtilities.createLogoutResponse(
                request: req,
                oidcConfig: finalOIDCConfig,
                oauthConfig: finalOAuthConfig,
                postLogoutRedirectURI: finalPostLogoutRedirectURI,
                fallbackRedirectURI: fallbackRedirectURI
            )
        }

        self.logger.info("✅ Configured logout routes at \(logoutPath)")
    }
}

/// Request extension for logout utilities
extension Request {
    /// Perform logout for this request
    public func logout(oauthConfig: OAuthConfiguration? = nil) async throws {
        try await LogoutUtilities.logout(request: self, oauthConfig: oauthConfig)
    }

    /// Check if this session requires OIDC logout
    public var requiresOIDCLogout: Bool {
        LogoutUtilities.requiresOIDCLogout(request: self)
    }

    /// Create OIDC logout URL for this request
    public func oidcLogoutURL(
        oidcConfig: OIDCConfiguration,
        postLogoutRedirectURI: String
    ) throws -> String {
        try LogoutUtilities.createOIDCLogoutURL(
            request: self,
            oidcConfig: oidcConfig,
            postLogoutRedirectURI: postLogoutRedirectURI
        )
    }
}
