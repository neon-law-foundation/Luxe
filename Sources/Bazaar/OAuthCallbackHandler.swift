import Bouncer
import Dali
import Fluent
import Foundation
import JWT
import Vapor

/// Handles OAuth callback from Cognito or Dex after successful authentication.
///
/// This handler processes the authorization code returned by the OIDC provider,
/// exchanges it for tokens, and creates a session for the user.
public func handleOAuthCallback(_ req: Request) async throws -> Response {
    req.logger.info("🔐 OAuth callback handler started")

    // Extract the authorization code and state from query parameters using AuthService
    let (code, originalPath) = try AuthService.extractCallbackParameters(from: req)
    req.logger.info("✅ OAuth callback received authorization code")
    req.logger.info("🔗 OAuth callback state (original path): \(originalPath ?? "nil")")

    // Get the OIDC configuration
    let oidcConfig = OIDCConfiguration.create(from: req.application.environment)
    req.logger.info("🔧 OIDC configuration loaded - issuer: \(oidcConfig.issuer)")

    // Determine endpoints and redirect URI based on environment
    let redirectUri: String
    let tokenEndpoint: String

    if Environment.get("ENV") == "PRODUCTION" {
        // Production uses Cognito
        redirectUri = "https://www.sagebrush.services/oauth2/idpresponse"
        tokenEndpoint = "https://sagebrush-auth.auth.us-west-2.amazoncognito.com/oauth2/token"
        req.logger.info("🏭 Using PRODUCTION configuration (Cognito)")
        req.logger.info("📍 Redirect URI: \(redirectUri)")
        req.logger.info("🔗 Token endpoint: \(tokenEndpoint)")
    } else {
        // Development uses Dex
        redirectUri = "http://localhost:8080/auth/dex/callback"
        tokenEndpoint = "\(oidcConfig.issuer)/token"
        req.logger.info("🔨 Using DEVELOPMENT configuration (Dex)")
        req.logger.info("📍 Redirect URI: \(redirectUri)")
        req.logger.info("🔗 Token endpoint: \(tokenEndpoint)")
    }

    // Exchange the authorization code for tokens using AuthService
    req.logger.info("🔄 Exchanging authorization code for tokens...")
    let tokenResponse = try await AuthService.exchangeCodeForTokens(
        code: code,
        clientId: oidcConfig.clientId,
        redirectUri: redirectUri,
        tokenEndpoint: tokenEndpoint,
        client: req.client
    )
    req.logger.info("✅ Token exchange successful")

    // Decode the ID token to get user information using AuthService
    req.logger.info("🔍 Decoding ID token to get user information...")
    let username = try AuthService.decodeUsernameFromToken(tokenResponse.idToken)
    req.logger.info("👤 Extracted username from token: \(username)")

    // Create a session using AuthService
    let sessionId = UUID().uuidString
    req.logger.info("🍪 Creating session with ID: \(sessionId)")
    let cookie = AuthService.createSessionCookie(sessionId: sessionId)

    // Store the session using AuthService
    if var sessions = req.application.storage[SessionStorageKey.self] {
        AuthService.storeSession(
            sessionId: sessionId,
            username: username,
            accessToken: tokenResponse.accessToken,
            in: &sessions
        )
        req.application.storage[SessionStorageKey.self] = sessions
    }
    req.logger.info("💾 Session stored in memory for username: \(username)")

    // Set the cookie and redirect to the original destination
    let redirectPath = AuthService.determineRedirectPath(from: originalPath)
    req.logger.info("🔀 Redirecting to: \(redirectPath)")
    let response = req.redirect(to: redirectPath)
    response.cookies["luxe-session"] = cookie

    return response
}
