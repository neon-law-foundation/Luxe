# Imperial OAuth Integration Analysis for Bouncer Target

## Overview

This document analyzes how Imperial OAuth configuration can reuse the existing OIDCConfiguration in the Bouncer
target and ensure redirect URIs align with existing OAuth callback handlers.

## Current OIDC Architecture

### OIDCConfiguration Structure

The existing `OIDCConfiguration` in Bouncer contains:

- `issuer`: OIDC provider URL (Cognito/Keycloak)

- `clientId`: OAuth client identifier

- `jwksURL`: JSON Web Key Set endpoint for token validation

### Environment-Specific Configuration

- **Production (AWS Cognito)**:
  - Issuer: `https://cognito-idp.us-west-2.amazonaws.com/us-west-2_sagebrush-cognito`
  - Client ID: From `COGNITO_CLIENT_ID` env var
  - JWKS URL: `https://cognito-idp.us-west-2.amazonaws.com/us-west-2_sagebrush-cognito/.well-known/jwks.json`

- **Development (Keycloak)**:
  - Issuer: `http://localhost:2222/realms/luxe`
  - Client ID: `luxe-client`
  - JWKS URL: `http://localhost:2222/realms/luxe/protocol/openid-connect/certs`

## Existing OAuth Callback Infrastructure

### Current OAuth Flow

1. User initiates login
2. Redirect to OIDC provider (Cognito/Keycloak)
3. After authentication, provider redirects to callback URL:
   - Production: `https://www.sagebrush.services/oauth2/idpresponse`
   - Development: `http://localhost:8080/auth/callback`
4. `OAuthCallbackHandler` exchanges authorization code for tokens
5. Session is created and stored using `SessionStorageKey`

### Token Exchange Endpoints

- **Production (Cognito)**: `https://sagebrush-auth.auth.us-west-2.amazoncognito.com/oauth2/token`

- **Development (Keycloak)**: `{issuer}/protocol/openid-connect/token`

## Imperial Integration Strategy

### 1. Extending OIDCConfiguration for Imperial

Imperial will need additional OAuth endpoints beyond what's currently in OIDCConfiguration:

```swift
public extension OIDCConfiguration {
    /// Authorization endpoint for Imperial OAuth flow
    var authorizationEndpoint: String {
        if Environment.get("ENV") == "PRODUCTION" {
            return "https://sagebrush-auth.auth.us-west-2.amazoncognito.com/oauth2/authorize"
        } else {
            return "\(issuer)/protocol/openid-connect/auth"
        }
    }

    /// Token endpoint for Imperial OAuth flow
    var tokenEndpoint: String {
        if Environment.get("ENV") == "PRODUCTION" {
            return "https://sagebrush-auth.auth.us-west-2.amazoncognito.com/oauth2/token"
        } else {
            return "\(issuer)/protocol/openid-connect/token"
        }
    }

    /// Redirect URI for Imperial OAuth callbacks
    var redirectURI: String {
        if Environment.get("ENV") == "PRODUCTION" {
            return "https://www.sagebrush.services/oauth2/idpresponse"
        } else {
            return "http://localhost:8080/auth/callback"
        }
    }
}
```

### 2. Imperial Provider Configuration

Imperial can be configured to work with our existing OIDC providers by creating a custom provider:

```swift
struct OIDCProvider: FederatedServiceTokens {
    static var idKey: String = "sub"
    var clientID: String
    var clientSecret: String?
    var authorizationURL: String
    var tokenURL: String
    var redirectURI: String
    var scope: [String] = ["openid", "email", "profile"]
}
```

### 3. Redirect URI Alignment

The existing OAuth callback infrastructure is already compatible with Imperial:

- The callback routes (`/auth/callback` and `/oauth2/idpresponse`) are already registered

- The `OAuthCallbackHandler` can be adapted to work with Imperial's token response

- Session management through `SessionStorageKey` can be shared

### 4. Session Integration

Imperial sessions can integrate with the existing session infrastructure:

- Use the same `SessionStorageKey` for consistency

- Store Imperial tokens in the same format as current OAuth tokens

- Leverage `CurrentUserContext` for user state management

## Implementation Recommendations

### Phase 1: Configuration Extension

1. Extend `OIDCConfiguration` with OAuth flow endpoints (authorization, token, redirect)
2. Create helper methods to generate Imperial-compatible configuration
3. Ensure all environment variables are properly mapped

### Phase 2: Imperial Provider Setup

1. Create a custom OIDC provider for Imperial that uses our configuration
2. Support both Cognito (production) and Keycloak (development) providers
3. Handle client secret requirements (Cognito requires it, Keycloak doesn't for public clients)

### Phase 3: Middleware Integration

1. Create `ImperialAuthMiddleware` that wraps Imperial's authentication
2. Integrate with existing `SessionStorageKey` and `CurrentUserContext`
3. Support both JWT (API) and session (HTML) authentication modes

### Phase 4: Route Compatibility

1. Ensure Imperial uses existing callback routes
2. Adapt `OAuthCallbackHandler` to support Imperial's token format
3. Maintain backward compatibility with existing OAuth flow

## Security Considerations

1. **Client Secrets**: Production (Cognito) requires client secrets, while development (Keycloak) uses public
   clients. Imperial must handle both scenarios.

2. **HTTPS Requirements**: Production URLs must use HTTPS for security. Development can use HTTP for localhost.

3. **Session Security**: Imperial sessions should use the same security measures as existing sessions (HTTPOnly
   cookies, secure flag in production, SameSite protection).

4. **Token Validation**: Imperial should leverage the existing JWKS validation infrastructure in OIDCConfiguration.

## Conclusion

Imperial can successfully integrate with the existing OIDC infrastructure in Bouncer by:

1. Extending OIDCConfiguration with OAuth-specific endpoints
2. Creating custom OIDC providers for Imperial
3. Reusing existing callback routes and session management
4. Maintaining compatibility with both Cognito and Keycloak

The existing architecture is well-suited for Imperial integration with minimal modifications required.
