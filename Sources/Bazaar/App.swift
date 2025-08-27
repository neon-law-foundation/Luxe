import Bouncer
import Dali
import Fluent
import FluentPostgresDriver
import OpenAPIRuntime
@preconcurrency import OpenAPIVapor
import Queues
import QueuesRedisDriver
import Redis
import SotoSES
import TouchMenu
import Vapor
import VaporElementary

// Response types for /app/me endpoint

/// Response structure for the /app/me endpoint containing user and person information.
///
/// This response provides complete user profile data including both authentication
/// information (user record) and personal details (person record).
public struct MeResponse: Content {
    /// The authenticated user's information.
    public let user: UserInfo

    /// The person record associated with the user.
    public let person: PersonInfo
}

/// User information structure containing authentication details.
///
/// This structure represents the core authentication record for a user,
/// including their unique identifier and username (typically an email address).
public struct UserInfo: Content {
    /// The user's unique identifier as a UUID string.
    public let id: String

    /// The user's username, typically their email address.
    public let username: String

    /// The user's role in the system (customer, staff, admin).
    public let role: String
}

/// Person information structure containing profile details.
///
/// This structure represents the personal profile information associated
/// with a user account, including their name and contact information.
public struct PersonInfo: Content {
    /// The person's unique identifier as a UUID string.
    public let id: String

    /// The person's full name.
    public let name: String

    /// The person's email address.
    public let email: String
}

/// Configures the unified Bazaar+SagebrushWeb Vapor application.
///
/// This function sets up:
/// - Error middleware for handling exceptions
/// - PostgreSQL database connection
/// - OIDC authentication configuration
/// - OpenAPI-generated routes under /api
/// - SagebrushWeb routes for the website
/// - Health check endpoint at /health
///
/// The API includes authenticated endpoints like /api/me that require
/// Bearer token authentication in the Authorization header.
/// The web routes serve SagebrushWeb pages and handle authentication.
///
/// - Parameter app: The Vapor application to configure
/// - Throws: Configuration errors if setup fails
public func configureApp(_ app: Application) async throws {
    // Configure middleware
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))

    // Configure static file serving from Bazaar's Public directory
    let publicDirectory = app.directory.workingDirectory + "Sources/Bazaar/Public/"
    app.middleware.use(FileMiddleware(publicDirectory: publicDirectory))

    // Configure DALI models and database (must be done before any database usage)
    try configureDali(app)

    // Configure queue system with Redis
    try configureQueues(app)

    // Configure email service with AWS SES
    try await configureEmailService(app)

    // Configure job system with email jobs
    try await configureJobSystem(app)

    // Configure OIDC
    let oidcConfig = OIDCConfiguration.create(from: app.environment)
    let oidcMiddleware = OIDCMiddleware(configuration: oidcConfig)

    // Configure header-based authentication with smart routing
    // Only /app and /api routes require authentication, all others are public
    let albAuthenticator = ALBHeaderAuthenticator(configuration: oidcConfig)
    let smartAuth = SmartAuthMiddleware(authenticator: albAuthenticator)

    // Use SmartAuthMiddleware for all routes (replaces SessionMiddleware)
    // In testing environment, mock headers will be injected by test utilities
    app.middleware.use(smartAuth)

    // MARK: - SagebrushWeb Routes

    app.get { req in
        HTMLResponse {
            HomePage(currentUser: CurrentUserContext.user)
        }
    }

    app.get("physical-address") { _ in
        HTMLResponse {
            PhysicalAddressPage()
        }
    }

    app.get("onboarding") { _ in
        HTMLResponse {
            OnboardingPage()
        }
    }

    app.get("ceo-search") { req -> Response in
        // Load the markdown file from the main Markdown directory
        let markdownDirectory = app.directory.workingDirectory + "Sources/Bazaar/Markdown"
        let filePath = "\(markdownDirectory)/ceo-search.md"

        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            throw Abort(.notFound, reason: "CEO Search page not found")
        }

        // Parse the frontmatter to get metadata
        guard let post = BlogPost.parseFrontmatter(from: content, filename: "ceo-search") else {
            throw Abort(.internalServerError, reason: "Invalid CEO Search page format")
        }

        // Extract the actual content (after frontmatter)
        let lines = content.components(separatedBy: .newlines)
        var contentStartIndex = 0
        var frontmatterEndFound = false

        for (index, line) in lines.enumerated() {
            if index > 0 && line == "---" && !frontmatterEndFound {
                contentStartIndex = index + 1
                frontmatterEndFound = true
                break
            }
        }

        let markdownBody = lines[contentStartIndex...].joined(separator: "\n")

        return try await HTMLResponse {
            MarkdownPage(post: post, markdownContent: markdownBody)
        }.encodeResponse(for: req)
    }

    app.get("blog") { _ in
        HTMLResponse {
            BlogPage()
        }
    }

    // Dynamic blog post routing
    app.get("blog", ":slug") { req -> Response in
        guard let slug = req.parameters.get("slug") else {
            throw Abort(.badRequest)
        }

        // Load the markdown file using the app's working directory
        let markdownDirectory = app.directory.workingDirectory + "Sources/Bazaar/Markdown/Blog"
        let filePath = "\(markdownDirectory)/\(slug).md"

        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            throw Abort(.notFound, reason: "Blog post not found: \(slug)")
        }

        // Parse the frontmatter to get metadata
        guard let post = BlogPost.parseFrontmatter(from: content, filename: slug) else {
            throw Abort(.internalServerError, reason: "Invalid blog post format")
        }

        // Extract the actual content (after frontmatter)
        let lines = content.components(separatedBy: .newlines)
        var contentStartIndex = 0
        var frontmatterEndFound = false

        for (index, line) in lines.enumerated() {
            if index > 0 && line == "---" && !frontmatterEndFound {
                contentStartIndex = index + 1
                frontmatterEndFound = true
                break
            }
        }

        let markdownBody = lines[contentStartIndex...].joined(separator: "\n")

        return try await HTMLResponse {
            BlogPostPage(post: post, markdownContent: markdownBody)
        }.encodeResponse(for: req)
    }

    // Newsletter routes for public viewing
    app.get("newsletters") { req -> Response in
        let service = NewsletterService(database: req.db)

        // Parse query parameters
        let page = req.query[Int.self, at: "page"] ?? 1
        let limit = min(req.query[Int.self, at: "limit"] ?? 20, 100)
        let typeQuery = req.query[String.self, at: "type"]

        let newsletterType: Newsletter.NewsletterName?
        if let typeQuery = typeQuery {
            switch typeQuery {
            case "nv-sci-tech":
                newsletterType = .nvSciTech
            case "sagebrush":
                newsletterType = .sagebrush
            case "neon-law":
                newsletterType = .neonLaw
            default:
                throw Abort(.badRequest, reason: "Invalid newsletter type")
            }
        } else {
            newsletterType = nil
        }

        do {
            let result = try await service.findSentWithPagination(
                type: newsletterType,
                page: page,
                limit: limit
            )

            let pagination = PaginationInfo(
                page: result.page,
                limit: result.limit,
                total: result.total,
                totalPages: result.totalPages
            )

            let currentUser = CurrentUserContext.user

            let archivePage = NewsletterArchivePage(
                newsletters: result.newsletters,
                pagination: pagination,
                currentType: newsletterType,
                currentUser: currentUser
            )

            return try await HTMLResponse { archivePage }.encodeResponse(for: req)
        } catch {
            req.logger.error("Newsletter archive error: \(error)")
            throw Abort(.internalServerError, reason: "Failed to load newsletter archive")
        }
    }

    app.get("newsletters", ":type", ":date") { req -> Response in
        guard let typeStr = req.parameters.get("type"),
            let dateStr = req.parameters.get("date")
        else {
            throw Abort(.badRequest, reason: "Missing newsletter type or date")
        }

        // Validate newsletter type
        let newsletterType: Newsletter.NewsletterName
        switch typeStr {
        case "nv-sci-tech":
            newsletterType = .nvSciTech
        case "sagebrush":
            newsletterType = .sagebrush
        case "neon-law":
            newsletterType = .neonLaw
        default:
            throw Abort(.badRequest, reason: "Invalid newsletter type")
        }

        // Validate date format (YYYYMM)
        guard dateStr.count == 6,
            let _ = Int(dateStr)
        else {
            throw Abort(.badRequest, reason: "Invalid date format. Expected YYYYMM")
        }

        let service = NewsletterService(database: req.db)

        do {
            // For now, find the most recent sent newsletter of the given type
            // TODO: Implement date-based lookup using the YYYYMM format
            let newsletters = try await service.findSent()
            guard let newsletter = newsletters.first(where: { $0.name == newsletterType }) else {
                throw Abort(.notFound, reason: "Newsletter not found")
            }

            return try await HTMLResponse {
                NewsletterPage(
                    newsletter: newsletter,
                    currentUser: CurrentUserContext.user
                )
            }.encodeResponse(for: req)
        } catch let error as NewsletterError {
            throw Abort(.notFound, reason: error.localizedDescription)
        } catch {
            throw Abort(.internalServerError, reason: "Failed to load newsletter")
        }
    }

    app.get("pricing") { req in
        HTMLResponse {
            PricingPage(currentUser: CurrentUserContext.user)
        }
    }

    app.get("privacy") { _ in
        HTMLResponse {
            PrivacyPolicyPage()
        }
    }

    app.get("mailroom-terms") { _ in
        HTMLResponse {
            MailroomTermsPage()
        }
    }

    app.get("trifecta") { req in
        HTMLResponse {
            TrifectaPage(currentUser: CurrentUserContext.user)
        }
    }

    app.get("for-lawyers") { req in
        HTMLResponse {
            ForLawyersPage(currentUser: CurrentUserContext.user)
        }
    }

    // Standards routes
    app.get("standards") { _ in
        Response(
            status: .ok,
            headers: HTTPHeaders([("Content-Type", "text/html")]),
            body: Response.Body(string: StandardsHomePage().content.render())
        )
    }

    app.get("standards", "spec") { req in
        HTMLResponse {
            StandardsSpecPage()
        }
    }

    app.get("standards", "notations") { req in
        HTMLResponse {
            StandardsNotationsPage()
        }
    }

    app.get("standards", "notations", "**") { req in
        // Remove empty, "standards" and "notations" path components
        let pathComponents = req.url.path.components(separatedBy: "/").dropFirst(3)
        let notationPath = pathComponents.joined(separator: "/")

        return HTMLResponse {
            StandardsNotationPage(notationPath: notationPath)
        }
    }

    // Login route that redirects to OIDC authorization endpoint (Cognito or Keycloak)
    app.get("login") { req -> Response in
        let oidcConfig = OIDCConfiguration.create(from: req.application.environment)

        do {
            try AuthService.validateConfiguration(oidcConfig)
        } catch let error as ValidationError {
            throw Abort(.internalServerError, reason: error.message)
        }

        // Get the original path the user was trying to access
        let redirectPath = req.query[String.self, at: "redirect"] ?? "/"

        let authorizationURL = AuthService.buildAuthorizationURL(
            oidcConfig: oidcConfig,
            redirectPath: redirectPath
        )

        return req.redirect(to: authorizationURL)
    }

    // OAuth callback routes for both Keycloak (development) and Cognito (production)
    app.get("auth", "callback", use: handleOAuthCallback)
    app.post("auth", "callback", use: handleOAuthCallback)

    // Cognito callback route for production
    app.get("oauth2", "idpresponse", use: handleOAuthCallback)
    app.post("oauth2", "idpresponse", use: handleOAuthCallback)

    // Logout route
    app.get("auth", "logout") { req -> Response in
        // No server-side session to clear with header-based auth

        // Get OIDC configuration and build logout URL
        let oidcConfig = OIDCConfiguration.create(from: req.application.environment)
        let logoutURL = AuthService.buildLogoutURL(oidcConfig: oidcConfig)

        // Clear any legacy session cookies and redirect
        let response = req.redirect(to: logoutURL)
        response.cookies["luxe-session"] = AuthService.createLogoutCookie()
        return response
    }

    // Protected app routes - authentication handled by SmartAuthMiddleware
    let appRoutes = app.grouped("app")
    let protectedRoutes = appRoutes.grouped(PostgresRoleMiddleware())

    protectedRoutes.get("me") { req async throws in
        guard let user = CurrentUserContext.user else {
            throw Abort(.internalServerError, reason: "Current user not available")
        }

        let userService = UserService(database: req.db)
        let (validUser, person) = try await userService.prepareUserProfile(user: user)

        let userInfo = UserInfo(
            id: validUser.id?.uuidString ?? "",
            username: validUser.username,
            role: validUser.role.rawValue
        )

        let personInfo = PersonInfo(
            id: person.id?.uuidString ?? "",
            name: person.name,
            email: person.email
        )

        // Content negotiation: return JSON for API clients, HTML for browsers
        if req.headers.accept.contains(where: { $0.mediaType.type == "application" && $0.mediaType.subType == "json" })
        {
            let response = MeResponse(user: userInfo, person: personInfo)
            return try await response.encodeResponse(for: req)
        } else {
            let page = MePage(
                user: userInfo,
                person: personInfo,
                currentUser: user
            )
            return try await HTMLResponse { page }.encodeResponse(for: req)
        }
    }

    // User settings routes
    protectedRoutes.get("settings") { req async throws in
        guard let user = CurrentUserContext.user else {
            throw Abort(.internalServerError, reason: "Current user not available")
        }

        let userService = UserService(database: req.db)
        let (validUser, person) = try await userService.prepareUserProfile(user: user)

        let subscriptionService = NewsletterSubscriptionService(database: req.db)
        let subscriptionPreferences = try await subscriptionService.getUserSubscriptionPreferences(
            userId: validUser.id!
        )

        let userInfo = UserInfo(
            id: validUser.id?.uuidString ?? "",
            username: validUser.username,
            role: validUser.role.rawValue
        )

        let personInfo = PersonInfo(
            id: person.id?.uuidString ?? "",
            name: person.name,
            email: person.email
        )

        let page = UserSettingsPage(
            user: userInfo,
            person: personInfo,
            subscriptionPreferences: subscriptionPreferences,
            currentUser: user
        )
        return try await HTMLResponse { page }.encodeResponse(for: req)
    }

    protectedRoutes.post("settings", "newsletters") { req async throws in
        guard let user = CurrentUserContext.user else {
            throw Abort(.internalServerError, reason: "Current user not available")
        }

        guard let userId = user.id else {
            throw Abort(.internalServerError, reason: "User ID not available")
        }

        // Parse form data
        let formData = try req.content.decode([String: String].self)

        let subscriptionService = NewsletterSubscriptionService(database: req.db)

        // Update newsletter preferences based on form checkboxes
        try await subscriptionService.updateSubscriptions(
            userId: userId,
            sciTech: formData["sci_tech"] == "true",
            sagebrush: formData["sagebrush"] == "true",
            neonLaw: formData["neon_law"] == "true"
        )

        // Redirect back to settings page with success
        return req.redirect(to: "/app/settings")
    }

    // Admin routes - authentication and role check handled by SmartAuthMiddleware
    // PostgresRoleMiddleware sets the database role based on the authenticated user
    let adminRoutes = app.grouped("admin")
        .grouped(PostgresRoleMiddleware())

    // Admin dashboard route
    adminRoutes.get { req async throws in
        let currentUser = CurrentUserContext.user
        let page = AdminDashboardPage(currentUser: currentUser)
        return try await HTMLResponse { page }.encodeResponse(for: req)
    }

    // Special admin route to fix Cognito authentication issues
    adminRoutes.post("fix-cognito-user") { req async throws -> Response in
        struct FixCognitoUserRequest: Content {
            let personEmail: String
            let cognitoSubId: String
            let role: String?
        }

        guard let currentUser = CurrentUserContext.user, currentUser.role == .admin else {
            throw Abort(.forbidden, reason: "Admin access required")
        }

        let requestData = try req.content.decode(FixCognitoUserRequest.self)
        let userRole = UserRole(rawValue: requestData.role ?? "admin") ?? .admin

        let adminService = AdminUserService(database: req.db)

        struct SuccessResponse: Content {
            let success: Bool
            let message: String
            let userId: String
        }

        struct ErrorResponse: Content {
            let success: Bool
            let message: String
            let error: String
        }

        do {
            let createdUser = try await adminService.createUserForExistingPerson(
                personEmail: requestData.personEmail,
                cognitoSubId: requestData.cognitoSubId,
                role: userRole
            )

            let response = SuccessResponse(
                success: true,
                message:
                    "User created successfully for \(requestData.personEmail) with Cognito sub ID \(requestData.cognitoSubId)",
                userId: createdUser.id?.uuidString ?? "unknown"
            )

            return try await response.encodeResponse(for: req)
        } catch {
            let errorResponse = ErrorResponse(
                success: false,
                message: "Failed to create user: \(error.localizedDescription)",
                error: String(describing: error)
            )

            return try await errorResponse.encodeResponse(status: .badRequest, for: req)
        }
    }

    // Admin route to manually trigger encouragement email for testing
    adminRoutes.post("trigger-encouragement-email") { req async throws -> Response in
        guard let currentUser = CurrentUserContext.user, currentUser.role == .admin else {
            throw Abort(.forbidden, reason: "Admin access required")
        }

        do {
            try await req.application.triggerEncouragementEmail()

            struct SuccessResponse: Codable {
                let success: Bool
                let message: String
            }

            let successResponse = SuccessResponse(
                success: true,
                message: "Daily encouragement email triggered successfully"
            )

            let response = try Response(
                status: .ok,
                body: .init(data: JSONEncoder().encode(successResponse))
            )
            response.headers.contentType = .json
            return response
        } catch {
            struct ErrorResponse: Codable {
                let success: Bool
                let message: String
            }

            let errorResponse = ErrorResponse(
                success: false,
                message: "Failed to trigger encouragement email: \(error.localizedDescription)"
            )

            let response = try Response(
                status: .internalServerError,
                body: .init(data: JSONEncoder().encode(errorResponse))
            )
            response.headers.contentType = .json
            return response
        }
    }

    // Newsletter admin routes
    adminRoutes.get("newsletters") { req async throws in
        let service = NewsletterService(database: req.db)
        let newsletters = try await service.findAll()
        let currentUser = CurrentUserContext.user
        let page = AdminNewsletterPage(newsletters: newsletters, currentUser: currentUser)
        return try await HTMLResponse { page }.encodeResponse(for: req)
    }

    adminRoutes.get("newsletters", "new") { req async throws in
        let currentUser = CurrentUserContext.user
        let page = AdminNewsletterCreatePage(currentUser: currentUser)
        return try await HTMLResponse { page }.encodeResponse(for: req)
    }

    adminRoutes.get("newsletters", ":id") { req async throws in
        guard let newsletterId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid newsletter ID")
        }

        let service = NewsletterService(database: req.db)
        guard let newsletter = try await service.findById(newsletterId) else {
            throw Abort(.notFound, reason: "Newsletter not found")
        }

        let currentUser = CurrentUserContext.user
        let page = AdminNewsletterDetailPage(newsletter: newsletter, currentUser: currentUser)
        return try await HTMLResponse { page }.encodeResponse(for: req)
    }

    adminRoutes.get("newsletters", "subscribers") { req async throws in
        let typeString = req.query[String.self, at: "type"]
        let newsletterType: Newsletter.NewsletterName?

        if let typeString = typeString {
            switch typeString {
            case "nv-sci-tech":
                newsletterType = .nvSciTech
            case "sagebrush":
                newsletterType = .sagebrush
            case "neon-law":
                newsletterType = .neonLaw
            default:
                newsletterType = nil
            }
        } else {
            newsletterType = nil
        }

        let subscriptionService = NewsletterSubscriptionService(database: req.db)
        let subscribers: [SubscriberInfo]

        if let type = newsletterType {
            subscribers = try await subscriptionService.getSubscribers(for: type)
        } else {
            subscribers = try await subscriptionService.getAllSubscribers()
        }

        let currentUser = CurrentUserContext.user
        let page = AdminNewsletterSubscribersPage(
            subscribers: subscribers,
            newsletterType: newsletterType,
            currentUser: currentUser
        )
        return try await HTMLResponse { page }.encodeResponse(for: req)
    }

    adminRoutes.get("newsletters", "analytics") { req async throws in
        let analyticsService = NewsletterAnalyticsService(database: req.db)
        let overallAnalytics = try await analyticsService.getOverallAnalytics()
        let recentEvents = try await analyticsService.getRecentEvents(limit: 20)

        let currentUser = CurrentUserContext.user
        let page = AdminNewsletterAnalyticsPage(
            overallAnalytics: overallAnalytics,
            recentEvents: recentEvents,
            currentUser: currentUser
        )
        return try await HTMLResponse { page }.encodeResponse(for: req)
    }

    try configureAdminRoutes(adminRoutes)

    // MARK: - Public Routes (before API setup to avoid OIDC dependency issues)

    print("Registering health and version routes...")

    // Health check endpoint
    app.get("health") { _ in
        print("Health endpoint hit!")
        return "OK"
    }

    // Version endpoint
    app.get("version") { req async throws -> Response in
        print("Version endpoint hit!")
        let version = TouchMenu.Version(serviceName: "Bazaar")
        let jsonData = try version.toJSON()
        let response = Response(status: .ok, body: .init(data: jsonData))
        response.headers.contentType = .json
        return response
    }

    print("Health and version routes registered successfully")

    // MARK: - API Routes

    // Add OIDC middleware to specific protected routes
    let apiRoutes = app.grouped("api")

    // Protected /me route with authentication and role switching
    apiRoutes.grouped(oidcMiddleware).grouped(PostgresRoleMiddleware()).get("me") { req async throws -> Response in
        guard let user = CurrentUserContext.user else {
            throw Abort(.unauthorized, reason: "User not authenticated")
        }

        let userService = UserService(database: req.db)
        let validUser = try await userService.prepareUserForAPI(user: user)

        let rolePayload: Components.Schemas.UserDetail.rolePayload =
            switch validUser.role {
            case .customer: .customer
            case .staff: .staff
            case .admin: .admin
            }

        let userDetail = Components.Schemas.UserDetail(
            id: validUser.id?.uuidString ?? UUID().uuidString,
            username: validUser.username,
            role: rolePayload
        )

        let personDetail = Components.Schemas.PersonDetail(
            id: validUser.person?.id?.uuidString ?? UUID().uuidString,
            name: validUser.person?.name ?? "Unknown",
            email: validUser.person?.email ?? validUser.username
        )

        let meResponse = Components.Schemas.MeResponse(
            user: userDetail,
            person: personDetail
        )

        let response = try Response(status: .ok, body: .init(data: JSONEncoder().encode(meResponse)))
        response.headers.contentType = .json
        return response
    }

    // Manual legal jurisdictions route since OpenAPI registration isn't working
    apiRoutes.get("legal-jurisdictions") { req async throws -> Response in
        print("Manual legal-jurisdictions handler called")
        do {
            let service = LegalJurisdictionService(database: req.db)
            let jurisdictions = try await service.listJurisdictionsForAPI()

            print("Found \(jurisdictions.count) legal jurisdictions")
            let response = try Response(status: .ok, body: .init(data: JSONEncoder().encode(jurisdictions)))
            response.headers.contentType = .json
            return response
        } catch {
            print("Error fetching legal jurisdictions: \(error)")
            let emptyArray: [[String: String]] = []
            let response = try Response(status: .ok, body: .init(data: JSONEncoder().encode(emptyArray)))
            response.headers.contentType = .json
            return response
        }
    }

    // Manual trademark search route since OpenAPI registration isn't working consistently
    apiRoutes.post("trademark", "search") { req async throws -> Response in
        print("Manual trademark search handler called")
        do {
            // Decode the request body
            let searchRequest = try req.content.decode(Components.Schemas.TrademarkSearchRequest.self)

            // Use the BazaarAPIServer implementation
            let apiServer = BazaarAPIServer(database: req.db, oidcMiddleware: oidcMiddleware)
            let input = Operations.searchTrademarks.Input(body: .json(searchRequest))
            let output = try await apiServer.searchTrademarks(input)

            switch output {
            case .ok(let okResponse):
                switch okResponse.body {
                case .json(let searchResponse):
                    let response = try Response(status: .ok, body: .init(data: JSONEncoder().encode(searchResponse)))
                    response.headers.contentType = .json
                    return response
                }
            case .badRequest(let badResponse):
                switch badResponse.body {
                case .json(let errorResponse):
                    let response = try Response(
                        status: .badRequest,
                        body: .init(data: JSONEncoder().encode(errorResponse))
                    )
                    response.headers.contentType = .json
                    return response
                }
            case .internalServerError(let errorResponse):
                switch errorResponse.body {
                case .json(let errorResponse):
                    let response = try Response(
                        status: .internalServerError,
                        body: .init(data: JSONEncoder().encode(errorResponse))
                    )
                    response.headers.contentType = .json
                    return response
                }
            case .undocumented(let statusCode, _):
                let errorResponse = Components.Schemas._Error(
                    message: "Undocumented response with status code: \(statusCode)"
                )
                let response = try Response(
                    status: .init(statusCode: statusCode),
                    body: .init(data: JSONEncoder().encode(errorResponse))
                )
                response.headers.contentType = .json
                return response
            }
        } catch {
            print("Error in trademark search: \(error)")
            let errorResponse = Components.Schemas._Error(
                message: "Trademark search failed: \(error.localizedDescription)"
            )
            let response = try Response(
                status: .internalServerError,
                body: .init(data: JSONEncoder().encode(errorResponse))
            )
            response.headers.contentType = .json
            return response
        }
    }

    // Keep OpenAPI registration for now but use manual routes above
    let transport = VaporTransport(routesBuilder: apiRoutes)
    let server = BazaarAPIServer(database: app.db, oidcMiddleware: oidcMiddleware)
    print("Registering OpenAPI handlers...")
    try server.registerHandlers(on: transport, serverURL: Servers.Server1.url())
    print("OpenAPI handlers registered successfully")

}

/// Configure the queue system with Redis driver
private func configureQueues(_ app: Application) throws {
    let isLocalDevelopment = app.environment != .production

    if isLocalDevelopment {
        // For local development, connect to Redis running in Docker
        app.logger.info("Configuring Redis queue for local development")
        // Use the simple URL configuration as per Vapor docs
        try app.queues.use(.redis(url: "redis://127.0.0.1:6379"))
    } else {
        // For production, use environment variable or default Redis URL with auth
        let redisURL = Environment.get("REDIS_URL") ?? "redis://127.0.0.1:6379"
        try app.queues.use(.redis(url: redisURL))
        app.logger.info("Configuring Redis queue for production", metadata: ["url": .string(redisURL)])
    }

    app.logger.info("✅ Redis queue configuration completed")
}

/// Configure the email service with AWS SES
private func configureEmailService(_ app: Application) async throws {
    let isProduction = app.environment == .production

    let configuration: EmailConfiguration
    if isProduction {
        configuration = EmailConfiguration.production()
        app.logger.info("Configuring EmailService for production")
    } else {
        configuration = EmailConfiguration.local()
        app.logger.info("Configuring EmailService for local development")
    }

    let emailService = try await EmailService(
        configuration: configuration,
        logger: app.logger
    )

    app.storage[EmailServiceKey.self] = emailService

    // Add lifecycle handler to properly shut down the EmailService
    app.lifecycle.use(EmailServiceLifecycleHandler(emailService: emailService, logger: app.logger))

    app.logger.info("✅ EmailService configuration completed")
}

/// Configure the job system with email jobs and job registry
private func configureJobSystem(_ app: Application) async throws {
    let isProduction = app.environment == .production

    // Configure job queue settings based on environment
    let configuration: JobQueueConfiguration
    if isProduction {
        configuration = JobQueueConfiguration.production
        app.logger.info("Configuring job system for production")
    } else {
        configuration = JobQueueConfiguration.development
        app.logger.info("Configuring job system for development")
    }

    app.configureJobQueue(configuration)

    // Register email job with Vapor Queues directly
    app.queues.add(SimpleEmailJob())

    // Register scheduled jobs
    app.scheduleDailyEncouragementEmail()

    // Per Vapor docs: Do NOT start workers in-process during app startup
    // Workers should be started separately with: swift run App queues
    app.logger.info("Job types registered. Start workers with: swift run Bazaar queues")

    app.logger.info("✅ Job system configuration completed")
}

/// Implementation of the Bazaar API server protocol generated from OpenAPI specification
struct BazaarAPIServer: APIProtocol {
    let database: Database
    let oidcMiddleware: OIDCMiddleware

    /// Handles GET /api/version endpoint
    /// - Parameter input: The request input containing headers
    /// - Returns: Version information for the Bazaar service
    func getVersion(_ input: Operations.getVersion.Input) async throws -> Operations.getVersion.Output {
        let version = TouchMenu.Version(serviceName: "Bazaar")

        // Parse the build date from the environment variable string
        let buildDate: Date
        if let buildDateString = ProcessInfo.processInfo.environment["BUILD_DATE"],
            let parsedDate = ISO8601DateFormatter().date(from: buildDateString)
        {
            buildDate = parsedDate
        } else {
            buildDate = Date()
        }

        let versionSchema = Components.Schemas.Version(
            serviceName: version.serviceName,
            gitCommit: version.gitCommit,
            gitTag: version.gitTag,
            buildDate: buildDate,
            swiftVersion: version.swiftVersion
        )

        return .ok(.init(body: .json(versionSchema)))
    }

    /// Handles GET /api/users endpoint with admin scope validation
    /// - Parameter input: The request input containing headers and query parameters
    /// - Returns: Response containing list of users or error
    func getUsers(_ input: Operations.getUsers.Input) async throws -> Operations.getUsers.Output {
        // For now, implement a simple mock response since the generated code structure is not yet available
        // This will need to be updated once the OpenAPI generator creates the proper types

        // Mock user data - in production this would query the database
        let users = [
            Components.Schemas.User(email: "admin@luxe.com"),
            Components.Schemas.User(email: "user@luxe.com"),
            Components.Schemas.User(email: "test@luxe.com"),
        ]

        return .ok(.init(body: .json(users)))
    }

    /// Handles GET /api/legal-jurisdictions endpoint
    /// - Parameter input: The request input containing headers and query parameters
    /// - Returns: Response containing list of legal jurisdictions
    func getLegalJurisdictions(
        _ input: Operations.getLegalJurisdictions.Input
    ) async throws -> Operations.getLegalJurisdictions.Output {
        print("getLegalJurisdictions handler called")
        do {
            let service = LegalJurisdictionService(database: database)
            let jurisdictionsData = try await service.listJurisdictionsForAPI()

            let jurisdictions = jurisdictionsData.map { data in
                Components.Schemas.LegalJurisdiction(name: data["name"] ?? "", code: data["code"] ?? "")
            }

            print("Found \(jurisdictions.count) legal jurisdictions")
            return .ok(.init(body: .json(jurisdictions)))
        } catch {
            // Log error and return empty array for now
            print("Error fetching legal jurisdictions: \(error)")
            return .ok(.init(body: .json([])))
        }
    }

    /// Handles GET /api/me endpoint
    func getMe(_ input: Operations.getMe.Input) async throws -> Operations.getMe.Output {
        print("OpenAPI getMe handler called - this should not be called since manual route takes precedence")
        // Return unauthorized to ensure tests fail if this route is accidentally called
        return .unauthorized(
            .init(
                body: .json(Components.Schemas._Error(message: "OpenAPI route called instead of manual route"))
            )
        )
    }

    /// Handles GET /api/me/settings endpoint
    func getUserSettings(_ input: Operations.getUserSettings.Input) async throws -> Operations.getUserSettings.Output {
        print("OpenAPI getUserSettings handler called - this should not be called since manual route takes precedence")
        return .unauthorized(
            .init(
                body: .json(Components.Schemas._Error(message: "OpenAPI route called instead of manual route"))
            )
        )
    }

    /// Handles PUT /api/me/newsletter-preferences endpoint
    func updateNewsletterPreferences(
        _ input: Operations.updateNewsletterPreferences.Input
    ) async throws -> Operations.updateNewsletterPreferences.Output {
        print(
            "OpenAPI updateNewsletterPreferences handler called - this should not be called since manual route takes precedence"
        )
        return .unauthorized(
            .init(
                body: .json(Components.Schemas._Error(message: "OpenAPI route called instead of manual route"))
            )
        )
    }

    /// Handles POST /api/validate endpoint for notation validation
    func validateNotation(_ input: Operations.validateNotation.Input) async throws -> Operations.validateNotation.Output
    {
        do {
            // Extract the validation request from the input
            let validationRequest: Components.Schemas.ValidationRequest
            switch input.body {
            case .json(let request):
                validationRequest = request
            }

            // Create the validation service
            let validationService = NotationValidationService(database: database)

            // Convert from OpenAPI schema to internal service request
            let serviceRequest = NotationValidationService.ValidationRequest(
                content: validationRequest.content,
                validateOnly: validationRequest.validateOnly ?? true,
                returnWarnings: validationRequest.returnWarnings ?? true
            )

            // Perform validation
            let serviceResponse = try await validationService.validate(serviceRequest)

            // Convert from internal service response to OpenAPI schema
            let errors = serviceResponse.errors.map { error in
                Components.Schemas.ValidationError(
                    _type: error.type,
                    field: error.field,
                    message: error.message,
                    line: error.line,
                    suggestion: error.suggestion
                )
            }

            let warnings = serviceResponse.warnings.map { warning in
                Components.Schemas.ValidationWarning(
                    _type: warning.type,
                    variable: warning.variable,
                    message: warning.message,
                    line: warning.line
                )
            }

            let response = Components.Schemas.ValidationResponse(
                valid: serviceResponse.valid,
                errors: errors,
                warnings: warnings
            )

            return .ok(.init(body: .json(response)))

        } catch let decodingError as DecodingError {
            let errorResponse = Components.Schemas.ValidationResponse(
                valid: false,
                errors: [
                    Components.Schemas.ValidationError(
                        _type: "invalid_request",
                        field: nil,
                        message: "Invalid request format: \(decodingError.localizedDescription)",
                        line: nil,
                        suggestion:
                            "Ensure your request includes 'content', 'validateOnly', and 'returnWarnings' fields"
                    )
                ],
                warnings: []
            )
            return .badRequest(.init(body: .json(errorResponse)))
        } catch {
            let errorResponse = Components.Schemas.ValidationResponse(
                valid: false,
                errors: [
                    Components.Schemas.ValidationError(
                        _type: "server_error",
                        field: nil,
                        message: "Internal server error: \(error.localizedDescription)",
                        line: nil,
                        suggestion: "Please try again later or contact support"
                    )
                ],
                warnings: []
            )
            return .internalServerError(.init(body: .json(errorResponse)))
        }
    }

    /// Handles POST /api/trademark/search endpoint
    /// - Parameter input: The request input containing trademark search parameters
    /// - Returns: Response containing trademark search results and Neon Law consultation info
    func searchTrademarks(_ input: Operations.searchTrademarks.Input) async throws -> Operations.searchTrademarks.Output
    {
        // Extract the search request from the input
        let searchRequest: Components.Schemas.TrademarkSearchRequest
        switch input.body {
        case .json(let request):
            searchRequest = request
        }

        // For now, implement a mock search response since this would normally
        // integrate with the USPTO TESS database or a trademark search API
        let mockResults = createMockTrademarkResults(for: searchRequest.searchTerm)

        // Get suggested classes based on common business types
        let suggestedClasses = getSuggestedUSPTOClasses()

        // Create Neon Law consultation information
        let neonLawConsultation = Components.Schemas.TrademarkSearchResponse.neonLawConsultationPayload(
            available: true,
            pricePerClass: 499,
            contactEmail: "trademarks@neonlaw.com"
        )

        let searchResponse = Components.Schemas.TrademarkSearchResponse(
            searchTerm: searchRequest.searchTerm,
            totalResults: mockResults.count,
            results: mockResults,
            suggestedClasses: suggestedClasses,
            neonLawConsultation: neonLawConsultation
        )

        return .ok(.init(body: .json(searchResponse)))
    }

    /// Creates mock trademark search results for demonstration purposes
    /// In production, this would query the USPTO TESS database
    private func createMockTrademarkResults(for searchTerm: String) -> [Components.Schemas.TrademarkResult] {
        let similarTerm = searchTerm.uppercased()

        return [
            Components.Schemas.TrademarkResult(
                serialNumber: "88123456",
                markText: "\(similarTerm) CORP",
                status: "LIVE",
                filingDate: "2020-01-10",
                registrationDate: "2021-03-21",
                classes: [35, 42],
                owner: "\(searchTerm) Corporation Inc.",
                similarity: 0.85
            ),
            Components.Schemas.TrademarkResult(
                serialNumber: "90234567",
                markText: "\(similarTerm) SOLUTIONS",
                status: "PENDING",
                filingDate: "2022-01-01",
                registrationDate: nil,
                classes: [42],
                owner: "\(searchTerm) Solutions LLC",
                similarity: 0.75
            ),
        ]
    }

    /// Returns suggested USPTO classes for common business types
    private func getSuggestedUSPTOClasses() -> [Components.Schemas.USPTOClass] {
        [
            Components.Schemas.USPTOClass(
                classNumber: 35,
                description: "Advertising; business management; business administration; office functions",
                category: .services,
                commonExamples: ["Business consulting", "Marketing services", "Office administration"]
            ),
            Components.Schemas.USPTOClass(
                classNumber: 42,
                description: "Scientific and technological services and research and design relating thereto",
                category: .services,
                commonExamples: ["Software development", "Technology consulting", "Computer services"]
            ),
            Components.Schemas.USPTOClass(
                classNumber: 9,
                description: "Scientific, research, navigation, surveying, photographic, cinematographic apparatus",
                category: .goods,
                commonExamples: ["Computer software", "Mobile applications", "Electronic devices"]
            ),
        ]
    }

    /// Handles POST /api/lawyers/contact endpoint
    /// - Parameter input: The request input containing the lawyer inquiry data
    /// - Returns: Response with inquiry ID and confirmation message
    func submitLawyerInquiry(
        _ input: Operations.submitLawyerInquiry.Input
    ) async throws -> Operations.submitLawyerInquiry.Output {
        // Extract the request body
        guard case let .json(requestBody) = input.body else {
            return .badRequest(.init(body: .json(.init(message: "Invalid request format"))))
        }

        // Generate a unique ID for this inquiry
        let inquiryId = UUID()
        let submittedAt = Date()

        // Log the inquiry for now (will be saved to database later)
        print("New lawyer inquiry received:")
        print("  ID: \(inquiryId)")
        print("  Firm: \(requestBody.firm_name)")
        print("  Contact: \(requestBody.contact_name)")
        print("  Email: \(requestBody.email)")
        print("  Nevada Bar: \(requestBody.nevada_bar_member?.rawValue ?? "not specified")")
        print("  Current Software: \(requestBody.current_software ?? "not specified")")
        print("  Use Cases: \(requestBody.use_cases ?? "not specified")")
        print("  Submitted: \(submittedAt)")

        // TODO: Save to database once migration is created
        // TODO: Send notification email to support team

        // Create the response
        let response = Components.Schemas.LawyerInquiryResponse(
            id: inquiryId.uuidString,
            message: "Thank you for your interest in Sagebrush Legal AI. We will contact you within 1 business day.",
            submittedAt: submittedAt
        )

        return .created(.init(body: .json(response)))
    }

    // MARK: - Newsletter API Methods

    /// Handles GET /api/admin/newsletters endpoint
    func getNewsletters(_ input: Operations.getNewsletters.Input) async throws -> Operations.getNewsletters.Output {
        let service = NewsletterService(database: database)

        do {
            let newsletters = try await service.findAll()
            let responseNewsletters = newsletters.map { newsletter in
                Components.Schemas.Newsletter(
                    id: newsletter.id.uuidString,
                    name: Components.Schemas.Newsletter.namePayload(rawValue: newsletter.name.rawValue)
                        ?? .nv_hyphen_sci_hyphen_tech,
                    subjectLine: newsletter.subjectLine,
                    markdownContent: newsletter.markdownContent,
                    sentAt: newsletter.sentAt,
                    recipientCount: newsletter.recipientCount,
                    createdBy: newsletter.createdBy.uuidString,
                    createdAt: newsletter.createdAt,
                    updatedAt: newsletter.updatedAt
                )
            }

            return .ok(.init(body: .json(responseNewsletters)))
        } catch {
            return .undocumented(statusCode: 500, .init(headerFields: [:], body: nil))
        }
    }

    /// Handles POST /api/admin/newsletters endpoint
    func createNewsletter(_ input: Operations.createNewsletter.Input) async throws -> Operations.createNewsletter.Output
    {
        guard case let .json(requestBody) = input.body else {
            return .badRequest(.init(body: .json(.init(message: "Invalid request format"))))
        }

        // Get current user from OIDC context
        guard let currentUser = CurrentUserContext.user else {
            return .unauthorized(.init(body: .json(.init(message: "Authentication required"))))
        }

        let service = NewsletterService(database: database)

        do {
            let newsletterName: Newsletter.NewsletterName
            switch requestBody.name {
            case .nv_hyphen_sci_hyphen_tech:
                newsletterName = .nvSciTech
            case .sagebrush:
                newsletterName = .sagebrush
            case .neon_hyphen_law:
                newsletterName = .neonLaw
            }

            let newsletter = try await service.create(
                name: newsletterName,
                subjectLine: requestBody.subjectLine,
                markdownContent: requestBody.markdownContent,
                createdBy: currentUser.id!
            )

            let response = Components.Schemas.Newsletter(
                id: newsletter.id.uuidString,
                name: Components.Schemas.Newsletter.namePayload(rawValue: newsletter.name.rawValue)
                    ?? .nv_hyphen_sci_hyphen_tech,
                subjectLine: newsletter.subjectLine,
                markdownContent: newsletter.markdownContent,
                sentAt: newsletter.sentAt,
                recipientCount: newsletter.recipientCount,
                createdBy: newsletter.createdBy.uuidString,
                createdAt: newsletter.createdAt,
                updatedAt: newsletter.updatedAt
            )

            return .created(.init(body: .json(response)))
        } catch let error as NewsletterError {
            return .badRequest(.init(body: .json(.init(message: error.localizedDescription))))
        } catch {
            return .undocumented(statusCode: 500, .init(headerFields: [:], body: nil))
        }
    }

    /// Handles GET /api/admin/newsletters/{newsletterId} endpoint
    func getNewsletterById(
        _ input: Operations.getNewsletterById.Input
    ) async throws -> Operations.getNewsletterById.Output {
        guard let newsletterId = UUID(uuidString: input.path.newsletterId) else {
            return .undocumented(statusCode: 400, .init(headerFields: [:], body: nil))
        }

        let service = NewsletterService(database: database)

        do {
            guard let newsletter = try await service.findById(newsletterId) else {
                return .notFound(.init(body: .json(.init(message: "Newsletter not found"))))
            }

            let response = Components.Schemas.Newsletter(
                id: newsletter.id.uuidString,
                name: Components.Schemas.Newsletter.namePayload(rawValue: newsletter.name.rawValue)
                    ?? .nv_hyphen_sci_hyphen_tech,
                subjectLine: newsletter.subjectLine,
                markdownContent: newsletter.markdownContent,
                sentAt: newsletter.sentAt,
                recipientCount: newsletter.recipientCount,
                createdBy: newsletter.createdBy.uuidString,
                createdAt: newsletter.createdAt,
                updatedAt: newsletter.updatedAt
            )

            return .ok(.init(body: .json(response)))
        } catch {
            return .undocumented(statusCode: 500, .init(headerFields: [:], body: nil))
        }
    }

    /// Handles PUT /api/admin/newsletters/{newsletterId} endpoint
    func updateNewsletter(_ input: Operations.updateNewsletter.Input) async throws -> Operations.updateNewsletter.Output
    {
        guard let newsletterId = UUID(uuidString: input.path.newsletterId) else {
            return .undocumented(statusCode: 400, .init(headerFields: [:], body: nil))
        }

        guard case let .json(requestBody) = input.body else {
            return .badRequest(.init(body: .json(.init(message: "Invalid request format"))))
        }

        let service = NewsletterService(database: database)

        do {
            let newsletter = try await service.update(
                id: newsletterId,
                subjectLine: requestBody.subjectLine,
                markdownContent: requestBody.markdownContent
            )

            let response = Components.Schemas.Newsletter(
                id: newsletter.id.uuidString,
                name: Components.Schemas.Newsletter.namePayload(rawValue: newsletter.name.rawValue)
                    ?? .nv_hyphen_sci_hyphen_tech,
                subjectLine: newsletter.subjectLine,
                markdownContent: newsletter.markdownContent,
                sentAt: newsletter.sentAt,
                recipientCount: newsletter.recipientCount,
                createdBy: newsletter.createdBy.uuidString,
                createdAt: newsletter.createdAt,
                updatedAt: newsletter.updatedAt
            )

            return .ok(.init(body: .json(response)))
        } catch let error as NewsletterError {
            return .badRequest(.init(body: .json(.init(message: error.localizedDescription))))
        } catch {
            return .undocumented(statusCode: 500, .init(headerFields: [:], body: nil))
        }
    }

    /// Handles DELETE /api/admin/newsletters/{newsletterId} endpoint
    func deleteNewsletter(_ input: Operations.deleteNewsletter.Input) async throws -> Operations.deleteNewsletter.Output
    {
        guard let newsletterId = UUID(uuidString: input.path.newsletterId) else {
            return .undocumented(statusCode: 400, .init(headerFields: [:], body: nil))
        }

        let service = NewsletterService(database: database)

        do {
            try await service.delete(id: newsletterId)
            return .noContent(.init())
        } catch let error as NewsletterError {
            return .badRequest(.init(body: .json(.init(message: error.localizedDescription))))
        } catch {
            return .undocumented(statusCode: 500, .init(headerFields: [:], body: nil))
        }
    }

    /// Handles POST /api/admin/newsletters/{newsletterId}/send endpoint
    func sendNewsletter(_ input: Operations.sendNewsletter.Input) async throws -> Operations.sendNewsletter.Output {
        guard let newsletterId = UUID(uuidString: input.path.newsletterId) else {
            return .undocumented(statusCode: 400, .init(headerFields: [:], body: nil))
        }

        let service = NewsletterService(database: database)

        do {
            let newsletter = try await service.send(id: newsletterId)

            let response = Components.Schemas.Newsletter(
                id: newsletter.id.uuidString,
                name: Components.Schemas.Newsletter.namePayload(rawValue: newsletter.name.rawValue)
                    ?? .nv_hyphen_sci_hyphen_tech,
                subjectLine: newsletter.subjectLine,
                markdownContent: newsletter.markdownContent,
                sentAt: newsletter.sentAt,
                recipientCount: newsletter.recipientCount,
                createdBy: newsletter.createdBy.uuidString,
                createdAt: newsletter.createdAt,
                updatedAt: newsletter.updatedAt
            )

            return .ok(.init(body: .json(response)))
        } catch let error as NewsletterError {
            return .badRequest(.init(body: .json(.init(message: error.localizedDescription))))
        } catch {
            return .undocumented(statusCode: 500, .init(headerFields: [:], body: nil))
        }
    }

    /// Handles GET /api/newsletters endpoint
    func getPublicNewsletters(
        _ input: Operations.getPublicNewsletters.Input
    ) async throws -> Operations.getPublicNewsletters.Output {
        let service = NewsletterService(database: database)

        // Parse query parameters
        let page = input.query.page ?? 1
        let limit = min(input.query.limit ?? 20, 100)  // Cap at 100

        let newsletterType: Newsletter.NewsletterName?
        if let typeQuery = input.query._type {
            switch typeQuery {
            case .nv_hyphen_sci_hyphen_tech:
                newsletterType = .nvSciTech
            case .sagebrush:
                newsletterType = .sagebrush
            case .neon_hyphen_law:
                newsletterType = .neonLaw
            }
        } else {
            newsletterType = nil
        }

        do {
            let result = try await service.findSentWithPagination(
                type: newsletterType,
                page: page,
                limit: limit
            )

            let responseNewsletters = result.newsletters.map { newsletter in
                Components.Schemas.Newsletter(
                    id: newsletter.id.uuidString,
                    name: Components.Schemas.Newsletter.namePayload(rawValue: newsletter.name.rawValue)
                        ?? .nv_hyphen_sci_hyphen_tech,
                    subjectLine: newsletter.subjectLine,
                    markdownContent: newsletter.markdownContent,
                    sentAt: newsletter.sentAt,
                    recipientCount: newsletter.recipientCount,
                    createdBy: newsletter.createdBy.uuidString,
                    createdAt: newsletter.createdAt,
                    updatedAt: newsletter.updatedAt
                )
            }

            let paginationInfo = Operations.getPublicNewsletters.Output.Ok.Body.jsonPayload.paginationPayload(
                page: result.page,
                limit: result.limit,
                total: result.total,
                totalPages: result.totalPages
            )

            let response = Operations.getPublicNewsletters.Output.Ok.Body.jsonPayload(
                newsletters: responseNewsletters,
                pagination: paginationInfo
            )

            return .ok(.init(body: .json(response)))
        } catch {
            return .undocumented(statusCode: 500, .init(headerFields: [:], body: nil))
        }
    }

    /// Handles GET /api/newsletters/{newsletterType}/{date} endpoint
    func getPublicNewsletter(
        _ input: Operations.getPublicNewsletter.Input
    ) async throws -> Operations.getPublicNewsletter.Output {
        let newsletterType: Newsletter.NewsletterName
        switch input.path.newsletterType {
        case .nv_hyphen_sci_hyphen_tech:
            newsletterType = .nvSciTech
        case .sagebrush:
            newsletterType = .sagebrush
        case .neon_hyphen_law:
            newsletterType = .neonLaw
        }

        let service = NewsletterService(database: database)

        do {
            // For this implementation, we'll just find the most recent sent newsletter of the given type
            // TODO: Implement date-based lookup using the YYYYMM format
            let newsletters = try await service.findSent()
            guard let newsletter = newsletters.first(where: { $0.name == newsletterType }) else {
                return .notFound(.init(body: .json(.init(message: "Newsletter not found"))))
            }

            let response = Components.Schemas.PublicNewsletter(
                id: newsletter.id.uuidString,
                name: Components.Schemas.PublicNewsletter.namePayload(rawValue: newsletter.name.rawValue)
                    ?? .nv_hyphen_sci_hyphen_tech,
                subjectLine: newsletter.subjectLine,
                markdownContent: newsletter.markdownContent,
                sentAt: newsletter.sentAt ?? Date()
            )

            return .ok(.init(body: .json(response)))
        } catch {
            return .undocumented(statusCode: 500, .init(headerFields: [:], body: nil))
        }
    }
}

/// Configures admin routes for CRUD operations on people and legal jurisdictions.
///
/// This function sets up all admin routes with proper HTML responses and form handling.
/// All routes require admin authentication via AdminAuthMiddleware.
///
/// - Parameter adminRoutes: The route group to add admin routes to
/// - Throws: Configuration errors if setup fails
internal func configureAdminRoutes(_ adminRoutes: RoutesBuilder) throws {
    // People routes
    adminRoutes.get("people") { req async throws in
        let adminService = AdminPeopleService(database: req.db)
        let people = try await adminService.listPeople()
        return HTMLResponse {
            AdminPeopleListPage(people: people, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.get("people", "new") { req async throws in
        HTMLResponse {
            AdminPersonFormPage(person: nil, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.get("people", ":id") { req async throws in
        guard let personId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid person ID")
        }

        let adminService = AdminPeopleService(database: req.db)
        guard let person = try await adminService.getPerson(personId: personId) else {
            throw Abort(.notFound, reason: "Person not found")
        }

        return HTMLResponse {
            AdminPersonDetailPage(person: person, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.get("people", ":id", "edit") { req async throws in
        guard let personId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid person ID")
        }

        let adminService = AdminPeopleService(database: req.db)
        guard let person = try await adminService.getPerson(personId: personId) else {
            throw Abort(.notFound, reason: "Person not found")
        }

        return HTMLResponse {
            AdminPersonFormPage(person: person, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.post("people") { req async throws in
        struct CreatePersonData: Content {
            let name: String
            let email: String
        }

        let data = try req.content.decode(CreatePersonData.self)
        let adminService = AdminPeopleService(database: req.db)

        do {
            let person = try await adminService.createPerson(name: data.name, email: data.email)
            return req.redirect(to: "/admin/people/\(try person.requireID())")
        } catch let error as ValidationError {
            throw Abort(.badRequest, reason: error.message)
        }
    }

    adminRoutes.patch("people", ":id") { req async throws in
        guard let personId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid person ID")
        }

        struct UpdatePersonData: Content {
            let name: String
            let email: String
        }

        let data = try req.content.decode(UpdatePersonData.self)
        let adminService = AdminPeopleService(database: req.db)

        do {
            let person = try await adminService.updatePerson(personId: personId, name: data.name, email: data.email)
            return req.redirect(to: "/admin/people/\(try person.requireID())")
        } catch let error as ValidationError {
            throw Abort(.badRequest, reason: error.message)
        }
    }

    adminRoutes.get("people", ":id", "delete") { req async throws in
        guard let personId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid person ID")
        }

        let adminService = AdminPeopleService(database: req.db)

        do {
            guard let person = try await adminService.getPersonForDeletion(personId: personId) else {
                throw Abort(.notFound, reason: "Person not found")
            }

            return HTMLResponse {
                AdminPersonDeleteConfirmPage(person: person, currentUser: CurrentUserContext.user)
            }
        } catch let error as ValidationError {
            throw Abort(.forbidden, reason: error.message)
        }
    }

    // POST route to handle form submissions with method override
    adminRoutes.post("people", ":id") { req async throws in
        // Check for method override
        if let method = try? req.content.get(String.self, at: "_method"), method == "DELETE" {
            // Handle as DELETE request
            guard let personId = req.parameters.get("id", as: UUID.self) else {
                throw Abort(.badRequest, reason: "Invalid person ID")
            }

            guard let person = try await Person.find(personId, on: req.db) else {
                throw Abort(.notFound, reason: "Person not found")
            }

            // Protect admin@neonlaw.com from deletion
            if person.email == "admin@neonlaw.com" {
                throw Abort(.forbidden, reason: "Cannot delete the system administrator account")
            }

            // Delete in a transaction to ensure data consistency
            try await req.db.transaction { database in
                // First, delete any linked users to avoid foreign key constraint violation
                let linkedUsers = try await User.query(on: database)
                    .filter(\.$person.$id == personId)
                    .all()

                for user in linkedUsers {
                    try await user.delete(on: database)
                }

                // Then delete the person
                try await person.delete(on: database)
            }

            return req.redirect(to: "/admin/people")
        }

        // If not a DELETE, return method not allowed
        throw Abort(.methodNotAllowed)
    }

    adminRoutes.delete("people", ":id") { req async throws in
        guard let personId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid person ID")
        }

        let adminService = AdminPeopleService(database: req.db)

        do {
            try await adminService.deletePerson(personId: personId)
            return req.redirect(to: "/admin/people")
        } catch let error as ValidationError {
            throw Abort(.forbidden, reason: error.message)
        }
    }

    // Address routes
    adminRoutes.get("addresses") { req async throws in
        let adminService = AdminAddressService(database: req.db)
        let addresses = try await adminService.listAddresses()
        return HTMLResponse {
            AdminAddressListPage(addresses: addresses, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.get("addresses", "new") { req async throws in
        let adminService = AdminAddressService(database: req.db)
        let entities = try await adminService.listEntities()
        let people = try await adminService.listPeople()
        return HTMLResponse {
            AdminAddressFormPage(address: nil, entities: entities, people: people, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.get("addresses", ":id") { req async throws in
        guard let addressId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid address ID")
        }

        let adminService = AdminAddressService(database: req.db)
        guard let address = try await adminService.getAddress(addressId: addressId) else {
            throw Abort(.notFound, reason: "Address not found")
        }

        return HTMLResponse {
            AdminAddressDetailPage(address: address, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.get("addresses", ":id", "edit") { req async throws in
        guard let addressId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid address ID")
        }

        let adminService = AdminAddressService(database: req.db)
        guard let address = try await adminService.getAddress(addressId: addressId) else {
            throw Abort(.notFound, reason: "Address not found")
        }

        let entities = try await adminService.listEntities()
        let people = try await adminService.listPeople()
        return HTMLResponse {
            AdminAddressFormPage(
                address: address,
                entities: entities,
                people: people,
                currentUser: CurrentUserContext.user
            )
        }
    }

    adminRoutes.post("addresses") { req async throws in
        struct CreateAddressData: Content {
            let entityId: String?
            let personId: String?
            let street: String
            let city: String
            let state: String?
            let zip: String?
            let country: String
            let isVerified: String?
        }

        let data = try req.content.decode(CreateAddressData.self)
        let adminService = AdminAddressService(database: req.db)

        // Parse entity/person IDs
        let entityId: UUID? = {
            guard let entityIdString = data.entityId, !entityIdString.isEmpty else { return nil }
            return UUID(uuidString: entityIdString)
        }()

        let personId: UUID? = {
            guard let personIdString = data.personId, !personIdString.isEmpty else { return nil }
            return UUID(uuidString: personIdString)
        }()

        // Handle invalid UUIDs
        if data.entityId != nil && !data.entityId!.isEmpty && entityId == nil {
            throw Abort(.badRequest, reason: "Invalid entity ID format")
        }
        if data.personId != nil && !data.personId!.isEmpty && personId == nil {
            throw Abort(.badRequest, reason: "Invalid person ID format")
        }

        do {
            let address = try await adminService.createAddress(
                entityId: entityId,
                personId: personId,
                street: data.street,
                city: data.city,
                state: data.state?.isEmpty == true ? nil : data.state,
                zip: data.zip?.isEmpty == true ? nil : data.zip,
                country: data.country,
                isVerified: data.isVerified == "true"
            )
            return req.redirect(to: "/admin/addresses/\(try address.requireID())")
        } catch let error as ValidationError {
            throw Abort(.badRequest, reason: error.message)
        }
    }

    adminRoutes.patch("addresses", ":id") { req async throws in
        guard let addressId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid address ID")
        }

        struct UpdateAddressData: Content {
            let entityId: String?
            let personId: String?
            let street: String
            let city: String
            let state: String?
            let zip: String?
            let country: String
            let isVerified: String?
        }

        let data = try req.content.decode(UpdateAddressData.self)
        let adminService = AdminAddressService(database: req.db)

        // Parse entity/person IDs
        let entityId: UUID? = {
            guard let entityIdString = data.entityId, !entityIdString.isEmpty else { return nil }
            return UUID(uuidString: entityIdString)
        }()

        let personId: UUID? = {
            guard let personIdString = data.personId, !personIdString.isEmpty else { return nil }
            return UUID(uuidString: personIdString)
        }()

        // Handle invalid UUIDs
        if data.entityId != nil && !data.entityId!.isEmpty && entityId == nil {
            throw Abort(.badRequest, reason: "Invalid entity ID format")
        }
        if data.personId != nil && !data.personId!.isEmpty && personId == nil {
            throw Abort(.badRequest, reason: "Invalid person ID format")
        }

        do {
            let address = try await adminService.updateAddress(
                addressId: addressId,
                entityId: entityId,
                personId: personId,
                street: data.street,
                city: data.city,
                state: data.state?.isEmpty == true ? nil : data.state,
                zip: data.zip?.isEmpty == true ? nil : data.zip,
                country: data.country,
                isVerified: data.isVerified == "true"
            )
            return req.redirect(to: "/admin/addresses/\(try address.requireID())")
        } catch let error as ValidationError {
            throw Abort(.badRequest, reason: error.message)
        }
    }

    adminRoutes.get("addresses", ":id", "delete") { req async throws in
        guard let addressId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid address ID")
        }

        let adminService = AdminAddressService(database: req.db)
        guard let address = try await adminService.getAddress(addressId: addressId) else {
            throw Abort(.notFound, reason: "Address not found")
        }

        return HTMLResponse {
            AdminAddressDeleteConfirmPage(address: address, currentUser: CurrentUserContext.user)
        }
    }

    // POST route to handle form submissions with method override
    adminRoutes.post("addresses", ":id") { req async throws in
        // Check for method override
        if let method = try? req.content.get(String.self, at: "_method"), method == "DELETE" {
            // Handle as DELETE request
            guard let addressId = req.parameters.get("id", as: UUID.self) else {
                throw Abort(.badRequest, reason: "Invalid address ID")
            }

            let adminService = AdminAddressService(database: req.db)

            do {
                try await adminService.deleteAddress(addressId: addressId)
                return req.redirect(to: "/admin/addresses")
            } catch let error as ValidationError {
                throw Abort(.notFound, reason: error.message)
            }
        }

        // If not a DELETE, return method not allowed
        throw Abort(.methodNotAllowed)
    }

    adminRoutes.delete("addresses", ":id") { req async throws in
        guard let addressId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid address ID")
        }

        let adminService = AdminAddressService(database: req.db)

        do {
            try await adminService.deleteAddress(addressId: addressId)
            return req.redirect(to: "/admin/addresses")
        } catch let error as ValidationError {
            throw Abort(.notFound, reason: error.message)
        }
    }

    // Legal Jurisdictions routes
    adminRoutes.get("legal-jurisdictions") { req async throws in
        let service = LegalJurisdictionService(database: req.db)
        let jurisdictions = try await service.listJurisdictions()
        return HTMLResponse {
            AdminLegalJurisdictionsListPage(jurisdictions: jurisdictions, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.get("legal-jurisdictions", ":id") { req async throws in
        guard let jurisdictionId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid jurisdiction ID")
        }

        let service = LegalJurisdictionService(database: req.db)
        guard let jurisdiction = try await service.getJurisdiction(jurisdictionId: jurisdictionId) else {
            throw Abort(.notFound, reason: "Legal jurisdiction not found")
        }

        return HTMLResponse {
            AdminLegalJurisdictionDetailPage(jurisdiction: jurisdiction, currentUser: CurrentUserContext.user)
        }
    }

    // Questions routes
    adminRoutes.get("questions") { req async throws in
        let service = QuestionService(database: req.db)
        let questions = try await service.listQuestions()
        return HTMLResponse {
            AdminQuestionsListPage(questions: questions, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.get("questions", ":id") { req async throws in
        guard let questionId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid question ID")
        }

        let service = QuestionService(database: req.db)
        guard let question = try await service.getQuestion(questionId: questionId) else {
            throw Abort(.notFound, reason: "Question not found")
        }

        return HTMLResponse {
            AdminQuestionDetailPage(question: question, currentUser: CurrentUserContext.user)
        }
    }

    // User management routes - Create person and user together
    adminRoutes.get("users") { req async throws in
        let adminService = AdminUserService(database: req.db)

        // Get query parameters for search and pagination
        let searchTerm = req.query[String.self, at: "search"] ?? ""
        let roleFilter = req.query[String.self, at: "role"].flatMap { UserRole(rawValue: $0) }
        let page = max(1, req.query[Int.self, at: "page"] ?? 1)
        let limit = min(100, max(10, req.query[Int.self, at: "limit"] ?? 50))
        let offset = (page - 1) * limit

        // Use search if parameters provided, otherwise list all
        let peopleWithUsers: [(person: Person, user: User)]
        if !searchTerm.isEmpty || roleFilter != nil {
            peopleWithUsers = try await adminService.searchUsers(
                searchTerm: searchTerm,
                roleFilter: roleFilter,
                limit: limit,
                offset: offset
            )
        } else {
            peopleWithUsers = try await adminService.listPeopleWithUsers(limit: limit, offset: offset)
        }

        return HTMLResponse {
            AdminUsersListPage(peopleWithUsers: peopleWithUsers, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.get("users", "new") { req async throws in
        HTMLResponse {
            AdminUserFormPage(existingData: nil, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.post("users") { req async throws in
        struct CreateUserData: Content {
            let name: String
            let email: String
            let role: String
        }

        let data = try req.content.decode(CreateUserData.self)

        guard let userRole = UserRole(rawValue: data.role) else {
            throw Abort(.badRequest, reason: "Invalid user role")
        }

        // Automatically set username to match email (normalized to lowercase)
        let normalizedEmail = data.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let input = AdminUserService.CreatePersonAndUserInput(
            name: data.name,
            email: data.email,
            username: normalizedEmail,
            role: userRole
        )

        let adminService = AdminUserService(database: req.db)

        do {
            let result = try await adminService.createPersonAndUser(input)
            return req.redirect(to: "/admin/users/\(result.userId)")
        } catch let error as ValidationError {
            throw Abort(.badRequest, reason: error.message)
        } catch {
            // Check if it's a PostgreSQL error about duplicates
            let errorString = String(reflecting: error)
            if errorString.contains("already exists") {
                throw Abort(.badRequest, reason: "User with this email or username already exists")
            }
            // Re-throw other errors
            throw error
        }
    }

    adminRoutes.get("users", ":id") { req async throws in
        guard let userId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }

        let adminService = AdminUserService(database: req.db)
        guard let user = try await adminService.getUserWithPerson(userId: userId) else {
            throw Abort(.notFound, reason: "User not found")
        }

        return HTMLResponse {
            AdminUserDetailPage(user: user, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.get("users", ":id", "edit") { req async throws in
        guard let userId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }

        let adminService = AdminUserService(database: req.db)
        guard let user = try await adminService.getUserWithPerson(userId: userId) else {
            throw Abort(.notFound, reason: "User not found")
        }

        return HTMLResponse {
            AdminUserEditFormPage(user: user, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.patch("users", ":id") { req async throws in
        guard let userId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }

        struct UpdateUserData: Content {
            let role: String
        }

        let data = try req.content.decode(UpdateUserData.self)

        guard let userRole = UserRole(rawValue: data.role) else {
            throw Abort(.badRequest, reason: "Invalid user role")
        }

        let adminService = AdminUserService(database: req.db)

        do {
            let _ = try await adminService.updateUserRole(userId: userId, newRole: userRole)
            return req.redirect(to: "/admin/users/\(userId)")
        } catch let error as ValidationError {
            throw Abort(.badRequest, reason: error.message)
        }
    }

    adminRoutes.get("users", ":id", "delete") { req async throws in
        guard let userId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }

        let adminService = AdminUserService(database: req.db)

        do {
            guard let user = try await adminService.getUserForDeletion(userId: userId) else {
                throw Abort(.notFound, reason: "User not found")
            }

            return HTMLResponse {
                AdminUserDeleteConfirmPage(user: user, currentUser: CurrentUserContext.user)
            }
        } catch let error as ValidationError {
            throw Abort(.forbidden, reason: error.message)
        }
    }

    // POST route to handle form submissions with method override
    adminRoutes.post("users", ":id") { req async throws in
        // Check for method override
        if let method = try? req.content.get(String.self, at: "_method"), method == "DELETE" {
            // Handle as DELETE request
            guard let userId = req.parameters.get("id", as: UUID.self) else {
                throw Abort(.badRequest, reason: "Invalid user ID")
            }

            guard let user = try await User.find(userId, on: req.db) else {
                throw Abort(.notFound, reason: "User not found")
            }

            // Protect admin@neonlaw.com from deletion
            if user.username == "admin@neonlaw.com" {
                throw Abort(.forbidden, reason: "Cannot delete the system administrator account")
            }

            try await user.delete(on: req.db)

            return req.redirect(to: "/admin/users")
        }

        // If not a DELETE, return method not allowed
        throw Abort(.methodNotAllowed)
    }

    adminRoutes.delete("users", ":id") { req async throws in
        guard let userId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }

        let adminService = AdminUserService(database: req.db)

        do {
            try await adminService.deleteUser(userId: userId)
            return req.redirect(to: "/admin/users")
        } catch let error as ValidationError {
            throw Abort(.forbidden, reason: error.message)
        }
    }

    // Projects routes
    adminRoutes.get("projects") { req async throws in
        let adminService = AdminProjectsService(database: req.db)
        let projects = try await adminService.listProjects()
        return HTMLResponse {
            AdminProjectsListPage(projects: projects, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.get("projects", "new") { req async throws in
        HTMLResponse {
            AdminProjectFormPage(project: nil, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.post("projects") { req async throws in
        struct CreateProjectData: Content {
            let codename: String
        }

        let data = try req.content.decode(CreateProjectData.self)
        let adminService = AdminProjectsService(database: req.db)

        do {
            let project = try await adminService.createProject(codename: data.codename)
            return req.redirect(to: "/admin/projects/\(try project.requireID())")
        } catch let error as ValidationError {
            throw Abort(.badRequest, reason: error.message)
        }
    }

    adminRoutes.get("projects", ":id") { req async throws in
        guard let projectId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        let adminService = AdminProjectsService(database: req.db)
        guard let project = try await adminService.getProject(projectId: projectId) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        return HTMLResponse {
            AdminProjectDetailPage(project: project, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.get("projects", ":id", "edit") { req async throws in
        guard let projectId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        let adminService = AdminProjectsService(database: req.db)
        guard let project = try await adminService.getProject(projectId: projectId) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        return HTMLResponse {
            AdminProjectFormPage(project: project, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.patch("projects", ":id") { req async throws in
        guard let projectId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        struct UpdateProjectData: Content {
            let codename: String
        }

        let data = try req.content.decode(UpdateProjectData.self)
        let adminService = AdminProjectsService(database: req.db)

        do {
            let project = try await adminService.updateProject(projectId: projectId, codename: data.codename)
            return req.redirect(to: "/admin/projects/\(try project.requireID())")
        } catch let error as ValidationError {
            throw Abort(.badRequest, reason: error.message)
        }
    }

    adminRoutes.get("projects", ":id", "delete") { req async throws in
        guard let projectId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        let adminService = AdminProjectsService(database: req.db)
        guard let project = try await adminService.getProject(projectId: projectId) else {
            throw Abort(.notFound, reason: "Project not found")
        }

        return HTMLResponse {
            AdminProjectDeleteConfirmPage(project: project, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.post("projects", ":id", "delete") { req async throws in
        guard let projectId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        // Check if request has _method=DELETE in the body
        struct DeleteMethod: Content {
            let _method: String?
        }

        let deleteData = try? req.content.decode(DeleteMethod.self)
        if deleteData?._method?.uppercased() == "DELETE" {
            let adminService = AdminProjectsService(database: req.db)

            do {
                try await adminService.deleteProject(projectId: projectId)
                return req.redirect(to: "/admin/projects")
            } catch let error as ValidationError {
                throw Abort(.notFound, reason: error.message)
            }
        }

        // If not a DELETE, return method not allowed
        throw Abort(.methodNotAllowed)
    }

    adminRoutes.delete("projects", ":id") { req async throws in
        guard let projectId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid project ID")
        }

        let adminService = AdminProjectsService(database: req.db)

        do {
            try await adminService.deleteProject(projectId: projectId)
            return req.redirect(to: "/admin/projects")
        } catch let error as ValidationError {
            throw Abort(.notFound, reason: error.message)
        }
    }

    // Entities routes
    adminRoutes.get("entities") { req async throws in
        let adminService = AdminEntitiesService(database: req.db)
        let entities = try await adminService.listEntities()
        return HTMLResponse {
            AdminEntitiesListPage(entities: entities, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.get("entities", "new") { req async throws in
        let adminService = AdminEntitiesService(database: req.db)
        let entityTypes = try await adminService.listEntityTypes()

        return HTMLResponse {
            AdminEntityFormPage(entity: nil, entityTypes: entityTypes, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.post("entities") { req async throws in
        struct CreateEntityData: Content {
            let name: String
            let legalEntityTypeId: UUID
        }

        let data = try req.content.decode(CreateEntityData.self)
        let adminService = AdminEntitiesService(database: req.db)

        do {
            let entity = try await adminService.createEntity(name: data.name, legalEntityTypeId: data.legalEntityTypeId)
            return req.redirect(to: "/admin/entities/\(try entity.requireID())")
        } catch let error as ValidationError {
            throw Abort(.badRequest, reason: error.message)
        }
    }

    adminRoutes.get("entities", ":id") { req async throws in
        guard let entityId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid entity ID")
        }

        let adminService = AdminEntitiesService(database: req.db)
        guard let entity = try await adminService.getEntity(entityId: entityId) else {
            throw Abort(.notFound, reason: "Entity not found")
        }

        return HTMLResponse {
            AdminEntityDetailPage(entity: entity, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.get("entities", ":id", "edit") { req async throws in
        guard let entityId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid entity ID")
        }

        let adminService = AdminEntitiesService(database: req.db)
        guard let entity = try await adminService.getEntity(entityId: entityId) else {
            throw Abort(.notFound, reason: "Entity not found")
        }

        let entityTypes = try await adminService.listEntityTypes()

        return HTMLResponse {
            AdminEntityFormPage(entity: entity, entityTypes: entityTypes, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.patch("entities", ":id") { req async throws in
        guard let entityId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid entity ID")
        }

        struct UpdateEntityData: Content {
            let name: String
            let legalEntityTypeId: UUID
        }

        let data = try req.content.decode(UpdateEntityData.self)
        let adminService = AdminEntitiesService(database: req.db)

        do {
            let entity = try await adminService.updateEntity(
                entityId: entityId,
                name: data.name,
                legalEntityTypeId: data.legalEntityTypeId
            )
            return req.redirect(to: "/admin/entities/\(try entity.requireID())")
        } catch let error as ValidationError {
            throw Abort(.badRequest, reason: error.message)
        }
    }

    adminRoutes.get("entities", ":id", "delete") { req async throws in
        guard let entityId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid entity ID")
        }

        let adminService = AdminEntitiesService(database: req.db)
        guard let entity = try await adminService.getEntity(entityId: entityId) else {
            throw Abort(.notFound, reason: "Entity not found")
        }

        return HTMLResponse {
            AdminEntityDeleteConfirmPage(entity: entity, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.post("entities", ":id", "delete") { req async throws in
        guard let entityId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid entity ID")
        }

        // Check if request has _method=DELETE in the body
        struct DeleteMethod: Content {
            let _method: String?
        }

        let deleteData = try? req.content.decode(DeleteMethod.self)
        if deleteData?._method?.uppercased() == "DELETE" {
            let adminService = AdminEntitiesService(database: req.db)

            do {
                try await adminService.deleteEntity(entityId: entityId)
                return req.redirect(to: "/admin/entities")
            } catch let error as ValidationError {
                throw Abort(.notFound, reason: error.message)
            }
        }

        // If not a DELETE, return method not allowed
        throw Abort(.methodNotAllowed)
    }

    adminRoutes.delete("entities", ":id") { req async throws in
        guard let entityId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid entity ID")
        }

        let adminService = AdminEntitiesService(database: req.db)

        do {
            try await adminService.deleteEntity(entityId: entityId)
            return req.redirect(to: "/admin/entities")
        } catch let error as ValidationError {
            throw Abort(.notFound, reason: error.message)
        }
    }

    // Vendor routes
    adminRoutes.get("vendors") { req async throws in
        let service = AdminVendorService(database: req.db)
        let vendors = try await service.listVendors()
        return HTMLResponse {
            AdminVendorsListPage(vendors: vendors, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.get("vendors", "new") { req async throws in
        let service = AdminVendorService(database: req.db)
        let entities = try await service.listEntities()
        let people = try await service.listPeople()
        return HTMLResponse {
            AdminVendorFormPage(vendor: nil, entities: entities, people: people, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.get("vendors", ":id") { req async throws in
        guard let vendorId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid vendor ID")
        }

        let service = AdminVendorService(database: req.db)
        guard let vendor = try await service.getVendor(vendorId: vendorId) else {
            throw Abort(.notFound, reason: "Vendor not found")
        }

        return HTMLResponse {
            AdminVendorDetailPage(vendor: vendor, currentUser: CurrentUserContext.user)
        }
    }

    adminRoutes.get("vendors", ":id", "edit") { req async throws in
        guard let vendorId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid vendor ID")
        }

        let service = AdminVendorService(database: req.db)
        guard let vendor = try await service.getVendor(vendorId: vendorId) else {
            throw Abort(.notFound, reason: "Vendor not found")
        }

        let entities = try await service.listEntities()
        let people = try await service.listPeople()

        return HTMLResponse {
            AdminVendorFormPage(
                vendor: vendor,
                entities: entities,
                people: people,
                currentUser: CurrentUserContext.user
            )
        }
    }

    adminRoutes.post("vendors") { req async throws in
        struct CreateVendorData: Content {
            let name: String
            let vendorType: String
            let entityId: String?
            let personId: String?
        }

        let data = try req.content.decode(CreateVendorData.self)
        let service = AdminVendorService(database: req.db)

        let input: AdminVendorService.CreateVendorInput
        if data.vendorType == "entity" {
            guard let entityIdString = data.entityId, !entityIdString.isEmpty,
                let entityId = UUID(uuidString: entityIdString)
            else {
                throw Abort(.badRequest, reason: "Entity ID is required for entity vendors")
            }
            input = AdminVendorService.CreateVendorInput(name: data.name, entityID: entityId, personID: nil)
        } else if data.vendorType == "person" {
            guard let personIdString = data.personId, !personIdString.isEmpty,
                let personId = UUID(uuidString: personIdString)
            else {
                throw Abort(.badRequest, reason: "Person ID is required for person vendors")
            }
            input = AdminVendorService.CreateVendorInput(name: data.name, entityID: nil, personID: personId)
        } else {
            throw Abort(.badRequest, reason: "Invalid vendor type")
        }

        let vendor = try await service.createVendor(input)
        return req.redirect(to: "/admin/vendors/\(try vendor.requireID())")
    }

    adminRoutes.patch("vendors", ":id") { req async throws in
        guard let vendorId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid vendor ID")
        }

        struct UpdateVendorData: Content {
            let name: String
            let vendorType: String
            let entityId: String?
            let personId: String?
        }

        let data = try req.content.decode(UpdateVendorData.self)
        let service = AdminVendorService(database: req.db)

        let input: AdminVendorService.UpdateVendorInput
        if data.vendorType == "entity" {
            guard let entityIdString = data.entityId, !entityIdString.isEmpty,
                let entityId = UUID(uuidString: entityIdString)
            else {
                throw Abort(.badRequest, reason: "Entity ID is required for entity vendors")
            }
            input = AdminVendorService.UpdateVendorInput(name: data.name, entityID: entityId, personID: nil)
        } else if data.vendorType == "person" {
            guard let personIdString = data.personId, !personIdString.isEmpty,
                let personId = UUID(uuidString: personIdString)
            else {
                throw Abort(.badRequest, reason: "Person ID is required for person vendors")
            }
            input = AdminVendorService.UpdateVendorInput(name: data.name, entityID: nil, personID: personId)
        } else {
            throw Abort(.badRequest, reason: "Invalid vendor type")
        }

        let vendor = try await service.updateVendor(vendorId: vendorId, input)
        return req.redirect(to: "/admin/vendors/\(try vendor.requireID())")
    }

    adminRoutes.get("vendors", ":id", "delete") { req async throws in
        guard let vendorId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid vendor ID")
        }

        let service = AdminVendorService(database: req.db)
        guard let vendor = try await service.getVendor(vendorId: vendorId) else {
            throw Abort(.notFound, reason: "Vendor not found")
        }

        return HTMLResponse {
            AdminVendorDeleteConfirmPage(vendor: vendor, currentUser: CurrentUserContext.user)
        }
    }

    // POST route to handle form submissions with method override
    adminRoutes.post("vendors", ":id") { req async throws in
        // Check for method override
        if let method = try? req.content.get(String.self, at: "_method"), method == "DELETE" {
            // Handle as DELETE request
            guard let vendorId = req.parameters.get("id", as: UUID.self) else {
                throw Abort(.badRequest, reason: "Invalid vendor ID")
            }

            let service = AdminVendorService(database: req.db)
            try await service.deleteVendor(vendorId: vendorId)

            return req.redirect(to: "/admin/vendors")
        }

        // If not a DELETE, return method not allowed
        throw Abort(.methodNotAllowed)
    }

    adminRoutes.delete("vendors", ":id") { req async throws in
        guard let vendorId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid vendor ID")
        }

        let service = AdminVendorService(database: req.db)
        try await service.deleteVendor(vendorId: vendorId)

        return req.redirect(to: "/admin/vendors")
    }

}

/// Lifecycle handler for properly shutting down the EmailService
struct EmailServiceLifecycleHandler: LifecycleHandler {
    let emailService: EmailService
    let logger: Logger

    func shutdown(_ application: Application) {
        // Use Task to handle async shutdown in sync context
        Task {
            do {
                try await emailService.shutdown()
                logger.info("EmailService shutdown completed")
            } catch {
                logger.error("Failed to shutdown EmailService: \(error)")
            }
        }
    }
}
