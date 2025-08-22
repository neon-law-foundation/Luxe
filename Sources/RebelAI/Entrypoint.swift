import Foundation
import Logging
import MCP

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private let logger = Logger(label: "rebel-ai.search-cases")

/// Searches legal cases using the Docket Alarm API
func searchDocketAlarmCases(query: String) async throws -> String {
    logger.info(
        "searchDocketAlarmCases function started",
        metadata: [
            "query": "\(query)",
            "query_length": "\(query.count)",
            "utf8_valid": "\(query.utf8CString.count > 0)",
        ]
    )

    let username = "admin@neonlaw.com"
    let password = "alKlATAn"
    let baseURL = "https://www.docketalarm.com/api/v1/"

    logger.debug(
        "API configuration",
        metadata: [
            "username": "\(username)",
            "base_url": "\(baseURL)",
            "password_length": "\(password.count)",
        ]
    )

    // Create Basic Auth credentials
    let credentials = "\(username):\(password)"
    let credentialsData = credentials.data(using: .utf8)!
    let base64Credentials = credentialsData.base64EncodedString()

    logger.debug(
        "Auth credentials created",
        metadata: [
            "base64_length": "\(base64Credentials.count)"
        ]
    )

    // Construct the search URL - try different endpoint variations
    guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
        logger.error("Failed to URL encode query", metadata: ["query": "\(query)"])
        throw NSError(
            domain: "DocketAlarmError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Invalid search query"]
        )
    }

    logger.debug("Query URL encoded", metadata: ["encoded_query": "\(encodedQuery)"])

    // Try the search endpoint as documented
    let fullURL = "\(baseURL)search/?q=\(encodedQuery)"
    logger.debug("Full URL constructed", metadata: ["url": "\(fullURL)"])

    guard let url = URL(string: fullURL) else {
        logger.error("Failed to create URL object", metadata: ["url_string": "\(fullURL)"])
        throw NSError(
            domain: "DocketAlarmError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Invalid URL construction"]
        )
    }

    logger.debug("URL object created successfully", metadata: ["url": "\(url)"])

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("RebelAI-MCP/1.0", forHTTPHeaderField: "User-Agent")

    var headerMetadata: [String: Logger.MetadataValue] = [
        "method": "\(request.httpMethod ?? "nil")",
        "url": "\(request.url?.absoluteString ?? "nil")",
    ]

    if let headers = request.allHTTPHeaderFields {
        for (key, value) in headers {
            if key == "Authorization" {
                headerMetadata["header_\(key)"] = "Basic [REDACTED] (length: \(value.count))"
            } else {
                headerMetadata["header_\(key)"] = "\(value)"
            }
        }
    }

    logger.debug("HTTP request configured", metadata: headerMetadata)

    logger.info("Making HTTP request")
    let requestStartTime = Date()

    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        let requestDuration = Date().timeIntervalSince(requestStartTime)

        logger.info(
            "HTTP request completed",
            metadata: [
                "duration_seconds": "\(String(format: "%.2f", requestDuration))",
                "response_size_bytes": "\(data.count)",
            ]
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error(
                "Response is not HTTPURLResponse",
                metadata: [
                    "response_type": "\(type(of: response))"
                ]
            )
            throw NSError(
                domain: "DocketAlarmError",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response"]
            )
        }

        var responseMetadata: [String: Logger.MetadataValue] = [
            "status_code": "\(httpResponse.statusCode)",
            "status_description": "\(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))",
        ]

        for (key, value) in httpResponse.allHeaderFields {
            responseMetadata["response_header_\(key)"] = "\(value)"
        }

        let responseBody = String(data: data, encoding: .utf8) ?? "Unable to decode response"
        responseMetadata["body_length"] = "\(responseBody.count)"

        if responseBody.count < 1000 {
            responseMetadata["full_body"] = "\(responseBody)"
        } else {
            responseMetadata["body_preview"] = "\(String(responseBody.prefix(500)))"
            responseMetadata["body_suffix"] = "\(String(responseBody.suffix(200)))"
        }

        logger.debug("HTTP response details", metadata: responseMetadata)

        // Handle different status codes - Docket Alarm might return 200 even for auth errors
        logger.debug("Processing HTTP status code", metadata: ["status_code": "\(httpResponse.statusCode)"])

        if httpResponse.statusCode == 200 {
            logger.info("HTTP 200 response received")
        } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            logger.error("Authentication error", metadata: ["status_code": "\(httpResponse.statusCode)"])
            return """
                Search Results for: '\(query)'

                Source: Docket Alarm API

                Authentication Error: The trial credentials may have expired or require different authentication.
                Status Code: \(httpResponse.statusCode)

                Please check the API credentials or authentication method.

                ---
                Search powered by Docket Alarm API
                """
        } else {
            logger.error(
                "HTTP error",
                metadata: [
                    "status_code": "\(httpResponse.statusCode)",
                    "response_body": "\(responseBody)",
                ]
            )
            throw NSError(
                domain: "DocketAlarmError",
                code: httpResponse.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "API request failed with status code: \(httpResponse.statusCode). Response: \(responseBody)"
                ]
            )
        }

        // Parse the JSON response
        logger.debug("Attempting to parse JSON response")
        if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            var jsonMetadata: [String: Logger.MetadataValue] = [
                "json_keys": "\(Array(jsonObject.keys))"
            ]

            // Log key information about the response structure
            if let count = jsonObject["count"] as? Int {
                jsonMetadata["total_results"] = "\(count)"
            }
            if let results = jsonObject["search_results"] as? [[String: Any]] {
                jsonMetadata["search_results_count"] = "\(results.count)"
            }

            logger.info("JSON parsing successful", metadata: jsonMetadata)

            // Format the response for display
            logger.debug("Calling formatDocketAlarmResponse")
            let formattedResponse = formatDocketAlarmResponse(jsonObject, query: query)
            logger.debug("Response formatted", metadata: ["formatted_length": "\(formattedResponse.count)"])
            return formattedResponse
        } else {
            logger.warning("JSON parsing failed, falling back to raw response")
            // Fallback to raw response if JSON parsing fails
            let rawResponse = String(data: data, encoding: .utf8) ?? "Unable to parse response"
            return """
                Search Results for: '\(query)'

                Source: Docket Alarm API

                Raw Response:
                \(rawResponse)
                """
        }
    } catch {
        let requestDuration = Date().timeIntervalSince(requestStartTime)
        var errorMetadata: [String: Logger.MetadataValue] = [
            "duration_seconds": "\(String(format: "%.2f", requestDuration))",
            "error": "\(error)",
            "error_type": "\(type(of: error))",
            "error_description": "\(error.localizedDescription)",
        ]

        if let urlError = error as? URLError {
            errorMetadata["url_error_code"] = "\(urlError.code.rawValue)"
            errorMetadata["url_error_description"] = "\(urlError.localizedDescription)"
            if let failingURL = urlError.failingURL {
                errorMetadata["failing_url"] = "\(failingURL)"
            }
        }

        logger.error("HTTP request failed", metadata: errorMetadata)
        throw NSError(
            domain: "DocketAlarmError",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Network error: \(error.localizedDescription)"]
        )
    }

    logger.info("searchDocketAlarmCases function completed successfully")
}

/// Formats the Docket Alarm API response for display
func formatDocketAlarmResponse(_ jsonResponse: [String: Any], query: String) -> String {
    var formatMetadata: [String: Logger.MetadataValue] = [
        "query": "\(query)",
        "json_keys": "\(Array(jsonResponse.keys))",
    ]

    for (key, value) in jsonResponse {
        formatMetadata["json_\(key)"] = "\(type(of: value)) = \(String(describing: value).prefix(100))"
    }

    logger.debug("formatDocketAlarmResponse started", metadata: formatMetadata)

    var formattedResponse = """
        Search Results for: '\(query)'

        Source: Docket Alarm API

        """

    // Extract relevant information from the actual API response structure
    if let searchResults = jsonResponse["search_results"] as? [[String: Any]] {
        let totalCount = jsonResponse["count"] as? Int ?? searchResults.count
        logger.info(
            "Found search_results array",
            metadata: [
                "results_count": "\(searchResults.count)",
                "total_count": "\(totalCount)",
            ]
        )
        formattedResponse += "Found \(totalCount) total cases (showing first \(searchResults.count)):\n\n"

        for (index, result) in searchResults.enumerated() {
            let title = result["title"] as? String ?? "Unknown Case"
            let court = result["court"] as? String ?? "Unknown Court"
            let dateFiled = result["date_filed"] as? String ?? "Unknown Date"
            let docket = result["docket"] as? String ?? "N/A"
            let caseType = result["type"] as? String ?? ""

            logger.debug(
                "Processing search result",
                metadata: [
                    "index": "\(index + 1)",
                    "result_keys": "\(Array(result.keys))",
                    "title": "\(title)",
                    "court": "\(court)",
                    "date_filed": "\(dateFiled)",
                    "docket": "\(docket)",
                    "case_type": "\(caseType)",
                ]
            )

            formattedResponse += """
                \(index + 1). \(title)
                   Court: \(court)
                   Docket: \(docket)\(caseType.isEmpty ? "" : " (\(caseType))")
                   Date Filed: \(dateFiled)

                """
        }
    } else if let error = jsonResponse["error"] as? String {
        logger.warning("Found error in JSON response", metadata: ["error": "\(error)"])
        formattedResponse += "Error: \(error)\n"
    } else if let success = jsonResponse["success"] as? Bool, success == false {
        logger.warning("Found success=false in JSON response")
        formattedResponse += "Search failed. Please try a different query.\n"
    } else {
        logger.warning(
            "JSON response structure not recognized",
            metadata: [
                "available_keys": "\(Array(jsonResponse.keys))"
            ]
        )
        formattedResponse += "Found cases: (Raw JSON response structure not recognized)\n"
        formattedResponse += "\(jsonResponse)\n"
    }

    formattedResponse += "\n---\nSearch powered by Docket Alarm API"

    logger.debug(
        "formatDocketAlarmResponse completed",
        metadata: [
            "formatted_length": "\(formattedResponse.count)"
        ]
    )

    return formattedResponse
}

/// Sends an email using the Postmark API
func sendPostmarkEmail(to: String, from: String, subject: String, body: String) async throws -> Bool {
    guard let postmarkToken = ProcessInfo.processInfo.environment["POSTMARK_API_TOKEN"] else {
        throw NSError(
            domain: "PostmarkError",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "POSTMARK_API_TOKEN environment variable not set"]
        )
    }

    let url = URL(string: "https://api.postmarkapp.com/email")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(postmarkToken, forHTTPHeaderField: "X-Postmark-Server-Token")

    let emailData: [String: Any] = [
        "From": from,
        "To": to,
        "Subject": subject,
        "TextBody": body,
    ]

    request.httpBody = try JSONSerialization.data(withJSONObject: emailData)

    let (_, response) = try await URLSession.shared.data(for: request)

    if let httpResponse = response as? HTTPURLResponse {
        return httpResponse.statusCode == 200
    }

    return false
}

/// Main entry point for the RebelAI MCP server
@main
struct Entrypoint {
    static func main() async throws {
        // Set up logging
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = .debug
            return handler
        }

        let mainLogger = Logger(label: "rebel-ai.main")
        mainLogger.info("RebelAI server starting...")

        // Create the MCP server with tool capabilities
        let server = Server(
            name: "RebelAI",
            version: "1.0.0",
            capabilities: .init(
                tools: .init(listChanged: false)
            )
        )

        mainLogger.info("Server instance created")

        mainLogger.info("Registering method handlers...")

        // Register the lookup matter tool
        await server.withMethodHandler(ListTools.self) { _ in
            mainLogger.info("ListTools handler called")
            let lookupMatterTool = Tool(
                name: "lookup_matter",
                description: """
                    Looks up matter information by ID or title. This tool can be used to retrieve details about legal
                    matters in the system.

                    Example usage:
                    - "Look up matter ID 12345"
                    - "Get information for matter 67890"
                    - "Check status of matter ABC123"
                    - "Lookup matter Smith v. Smith"
                    - "Find matter Johnson v. City of Springfield"
                    - "Search for matter Doe v. Acme Corp"
                    - "Get matter XYZ Corp v. ABC Inc"
                    - "Check matter status for Brown v. Board"
                    - "Retrieve matter details for matter #456"

                    Trigger phrases: 'lookup matter', 'find matter', 'search matter', 'get matter', 'check matter',
                    'retrieve matter', 'matter lookup', 'matter search'

                    The tool accepts either numeric matter IDs or matter names in the format 'Plaintiff v. Defendant'.
                    """,
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "matter_id": .object([
                            "type": .string("string"),
                            "description": .string(
                                "The ID or title of the matter to look up. Can be a numeric ID or a matter name in the format 'Plaintiff v. Defendant'"
                            ),
                        ])
                    ]),
                ])
            )

            let lookupCaseTool = Tool(
                name: "lookup_case",
                description: """
                    Looks up case information by name. This tool can be used to retrieve details about legal
                    cases in the system.

                    Example usage:
                    - "Look up case Smith v. Smith"
                    - "Get information for case Johnson v. City of Springfield"
                    - "Check status of case Doe v. Acme Corp"
                    - "Lookup case XYZ Corp v. ABC Inc"
                    - "Find case Brown v. Board"
                    - "Search for case Case #456"

                    Trigger phrases: 'lookup case', 'find case', 'search case', 'get case', 'check case',
                    'retrieve case', 'case lookup', 'case search'

                    The tool accepts case names in the format 'Plaintiff v. Defendant'.
                    """,
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "case_name": .object([
                            "type": .string("string"),
                            "description": .string(
                                "The name of the case to look up in the format 'Plaintiff v. Defendant'"
                            ),
                        ])
                    ]),
                ])
            )

            let createOperatingAgreementTool = Tool(
                name: "create_operating_agreement",
                description: """
                    Creates an operating agreement specifically for LLC entities. This tool generates a comprehensive
                    operating agreement template that defines the ownership structure, management responsibilities,
                    and operational procedures for a Limited Liability Company.

                    IMPORTANT: This tool must be called AFTER lookup_matter so we know which matter the operating
                    agreement is for. The operating agreement will be tailored to the specific LLC structure.

                    Example usage:
                    - "Create an operating agreement for this LLC"
                    - "Draft an operating agreement"
                    - "Generate LLC operating agreement"
                    - "Create operating agreement for Sagebrush Services LLC"
                    - "Draft LLC governance document"
                    - "Generate member agreement"

                    Trigger phrases: 'create operating agreement', 'draft operating agreement', 'generate operating agreement',
                    'LLC operating agreement', 'operating agreement template', 'member agreement', 'LLC governance',
                    'company operating agreement'

                    The tool will prompt for clarification if matter context is missing or if the entity is not an LLC.
                    """,
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "matter_id": .object([
                            "type": .string("string"),
                            "description": .string(
                                "The ID or title of the matter this operating agreement is for. Required to provide proper context for the LLC."
                            ),
                        ]),
                        "llc_name": .object([
                            "type": .string("string"),
                            "description": .string(
                                "The full legal name of the LLC (e.g., 'Sagebrush Services LLC'). Optional - will be inferred from matter if not provided."
                            ),
                        ]),
                        "management_structure": .object([
                            "type": .string("string"),
                            "description": .string(
                                "The management structure of the LLC ('member-managed' or 'manager-managed'). Optional - defaults to member-managed."
                            ),
                        ]),
                    ]),
                    "required": .array([.string("matter_id")]),
                ])
            )

            let emailMotionTool = Tool(
                name: "email_motion",
                description: """
                    Sends an email motion using the Postmark API. This tool sends professional legal motion emails
                    from support@neonlaw.com to admin@neonlaw.com for legal proceedings and documentation.

                    Example usage:
                    - "Email motion to dismiss"
                    - "Send motion for summary judgment"
                    - "Email discovery motion"
                    - "Send motion to compel"
                    - "Email motion for continuance"
                    - "Send motion for sanctions"

                    Trigger phrases: 'email motion', 'send motion', 'motion email', 'email legal motion',
                    'send legal motion', 'motion notification'

                    The tool requires the motion subject and content to send the email.
                    """,
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "subject": .object([
                            "type": .string("string"),
                            "description": .string(
                                "The subject line for the motion email (e.g., 'Motion to Dismiss - Case #12345')"
                            ),
                        ]),
                        "motion_content": .object([
                            "type": .string("string"),
                            "description": .string(
                                "The content of the motion to be included in the email body"
                            ),
                        ]),
                        "case_number": .object([
                            "type": .string("string"),
                            "description": .string(
                                "The case number associated with this motion. Optional but recommended for proper tracking."
                            ),
                        ]),
                    ]),
                    "required": .array([.string("subject"), .string("motion_content")]),
                ])
            )

            let createStockIssuanceTool = Tool(
                name: "create_stock_issuance",
                description: """
                    Creates a stock issuance document for a company. This tool generates documentation for the
                    issuance of shares to an entity such as a trust, person, non-profit, or other organization.

                    Example usage:
                    - "Create a Stock Issuance for Sagebrush Services LLC of 100 shares for the Shook Family Trust"
                    - "Issue 500 shares of Neon Law LLC to John Smith"
                    - "Generate stock issuance for XYZ Corp issuing 1000 shares to ABC Foundation"
                    - "Create share issuance document for 250 shares to the Johnson Trust"

                    Trigger phrases: 'create stock issuance', 'issue shares', 'stock issuance', 'share issuance',
                    'generate stock document', 'create share document'

                    The tool requires the company name and the entity receiving the shares.
                    """,
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "company": .object([
                            "type": .string("string"),
                            "description": .string(
                                "The name of the company issuing the shares (e.g., 'Sagebrush Services LLC')"
                            ),
                        ]),
                        "recipient": .object([
                            "type": .string("string"),
                            "description": .string(
                                "The entity receiving the shares - can be a person, trust, non-profit, or other organization (e.g., 'Shook Family Trust', 'John Smith', 'ABC Foundation')"
                            ),
                        ]),
                        "shares": .object([
                            "type": .string("string"),
                            "description": .string(
                                "The number of shares being issued (e.g., '100', '500')"
                            ),
                        ]),
                    ]),
                    "required": .array([.string("company"), .string("recipient"), .string("shares")]),
                ])
            )

            let searchCasesTool = Tool(
                name: "search_cases",
                description: """
                    Searches for legal cases using the Docket Alarm API with natural language queries. This tool
                    performs full text search across legal cases and returns relevant results.

                    Example usage:
                    - "Search cases for contract disputes"
                    - "Find cases about employment law"
                    - "Lookup cases for trademark infringement"
                    - "Search for patent litigation cases"
                    - "Find bankruptcy proceedings"
                    - "Cases about real estate disputes"
                    - "Search docket for class action lawsuits"

                    Trigger phrases: 'search cases for', 'find cases', 'lookup cases', 'search legal cases',
                    'find legal cases', 'case search', 'cases about', 'search docket'

                    The tool accepts natural language queries and will search the Docket Alarm database for
                    relevant legal cases. Everything after "for" in "search cases for X" will be used as
                    the search inquiry.
                    """,
                inputSchema: .object([
                    "type": .string("object"),
                    "properties": .object([
                        "inquiry": .object([
                            "type": .string("string"),
                            "description": .string(
                                "Natural language search inquiry for legal cases (e.g., 'contract disputes', 'employment law', 'trademark infringement')"
                            ),
                        ])
                    ]),
                    "required": .array([.string("inquiry")]),
                ])
            )

            return ListTools.Result(tools: [
                lookupMatterTool, lookupCaseTool, createOperatingAgreementTool, createStockIssuanceTool,
                emailMotionTool, searchCasesTool,
            ])
        }

        // Register the tool call handler
        await server.withMethodHandler(CallTool.self) { params in
            mainLogger.info("CallTool handler called", metadata: ["tool": "\(params.name)"])
            guard
                params.name == "lookup_matter" || params.name == "lookup_case"
                    || params.name == "create_operating_agreement" || params.name == "create_stock_issuance"
                    || params.name == "email_motion" || params.name == "search_cases"
            else {
                throw MCPError.invalidParams("Unknown tool: \(params.name)")
            }

            if params.name == "lookup_matter" {
                guard let matterId = params.arguments?["matter_id"] else {
                    throw MCPError.invalidParams("missing matter_id")
                }

                // Return a formatted response
                return CallTool.Result(
                    content: [
                        .text(
                            """
                            Matter Description: Sagebrush Services
                            Company Overview
                            Sagebrush is a newly established services company focused on facilitating business transitions from Delaware to Nevada. The company provides specialized services to help businesses relocate and establish operations in Nevada's business-friendly environment.

                            Leadership and Community Connection
                            The company currently has no CEO and an active search is being conducted to find the right leader for this role. The company maintains strong ties to the Northern Nevada community, which provides Sagebrush with deep market knowledge and established relationships that benefit clients seeking to establish or relocate their business operations to the region.

                            Core Services
                            Virtual Mailbox Services: Sagebrush offers secure, reliable, and professional virtual mailbox services designed for modern businesses and individuals. Their digital mail delivery system provides:

                            Professional mail management solutions
                            Secure handling of business correspondence
                            Digital delivery capabilities for remote access
                            Reliable service infrastructure
                            Market Position
                            The company has already established a customer base of hundreds of satisfied clients who trust Sagebrush with their mail management needs. This demonstrates the company's ability to deliver reliable services and build customer confidence in their offerings.

                            Strategic Focus
                            Sagebrush specializes in helping businesses navigate the transition from Delaware's corporate structure to Nevada's advantageous business environment. This includes supporting the logistical and operational aspects of business relocation, with particular emphasis on mail handling and business communication services.

                            Geographic Advantage
                            With its strong presence in Reno and investment in the Northern Nevada community, Sagebrush is positioned to leverage local expertise and relationships to provide superior service to businesses making the Delaware-to-Nevada transition.
                            """
                        )
                    ],
                    isError: false
                )
            } else if params.name == "lookup_case" {
                guard let caseName = params.arguments?["case_name"] else {
                    throw MCPError.invalidParams("missing case_name")
                }

                // Return a formatted response
                return CallTool.Result(
                    content: [.text("The case '\(caseName)' is about an immigration matter in Las Vegas.")],
                    isError: false
                )
            } else if params.name == "create_operating_agreement" {
                guard let matterId = params.arguments?["matter_id"] else {
                    return CallTool.Result(
                        content: [
                            .text(
                                "I need to know which matter this operating agreement is for. Please run lookup_matter first or specify which LLC matter you'd like to create an operating agreement for. For example: 'Which matter is this operating agreement for?' or 'What is the matter ID?'"
                            )
                        ],
                        isError: false
                    )
                }

                let llcName: String = {
                    if let llcNameValue = params.arguments?["llc_name"],
                        case let .string(value) = llcNameValue
                    {
                        return value
                    }
                    return "[LLC Name from Matter]"
                }()

                let managementStructure: String = {
                    if let managementValue = params.arguments?["management_structure"],
                        case let .string(value) = managementValue
                    {
                        return value
                    }
                    return "member-managed"
                }()

                // Return a structured response that prompts for refinement
                let response = """
                    Starting LLC Operating Agreement creation for matter '\(matterId)'...

                    LLC Name: \(llcName)
                    Management Structure: \(managementStructure.capitalized)
                    Matter: \(matterId)

                    I'm creating a comprehensive operating agreement template for this LLC. To customize this operating agreement, I'll need some additional information:

                    1. Who are the members and what are their ownership percentages?
                    2. What are the capital contribution requirements for each member?
                    3. How will profits and losses be allocated and distributed?
                    4. What are the management responsibilities and decision-making procedures?
                    5. Are there any restrictions on member transfers or buyout provisions?
                    6. What are the dissolution and liquidation procedures?
                    7. Are there any special voting requirements or member meeting procedures?

                    Please provide any specific requirements for this LLC, and I'll help you develop a comprehensive
                    operating agreement that governs the LLC's operations and member relationships.
                    """

                return CallTool.Result(
                    content: [.text(response)],
                    isError: false
                )
            } else if params.name == "email_motion" {
                guard let subjectValue = params.arguments?["subject"],
                    case let .string(subject) = subjectValue
                else {
                    throw MCPError.invalidParams("missing subject")
                }
                guard let motionContentValue = params.arguments?["motion_content"],
                    case let .string(motionContent) = motionContentValue
                else {
                    throw MCPError.invalidParams("missing motion_content")
                }

                let caseNumber: String? = {
                    if let caseNumberValue = params.arguments?["case_number"],
                        case let .string(value) = caseNumberValue
                    {
                        return value
                    }
                    return nil
                }()

                // Prepare email content
                let emailBody = """
                    Legal Motion Email

                    \(caseNumber != nil ? "Case Number: \(caseNumber!)\n" : "")
                    Subject: \(subject)

                    Motion Content:
                    \(motionContent)

                    ---
                    This motion was sent via the RebelAI MCP server.
                    Sent from: support@neonlaw.com
                    Date: \(Date().formatted(date: .abbreviated, time: .standard))
                    """

                // Send email using Postmark API
                do {
                    let success = try await sendPostmarkEmail(
                        to: "admin@neonlaw.com",
                        from: "support@neonlaw.com",
                        subject: subject,
                        body: emailBody
                    )

                    if success {
                        let response = """
                            Motion email sent successfully!

                            To: admin@neonlaw.com
                            From: support@neonlaw.com
                            Subject: \(subject)
                            \(caseNumber != nil ? "Case Number: \(caseNumber!)" : "")

                            The motion has been delivered via Postmark API.
                            """

                        return CallTool.Result(
                            content: [.text(response)],
                            isError: false
                        )
                    } else {
                        return CallTool.Result(
                            content: [
                                .text("Failed to send motion email. Please check your Postmark API configuration.")
                            ],
                            isError: true
                        )
                    }
                } catch {
                    return CallTool.Result(
                        content: [.text("Error sending motion email: \(error.localizedDescription)")],
                        isError: true
                    )
                }
            } else if params.name == "create_stock_issuance" {
                guard let companyValue = params.arguments?["company"],
                    case let .string(company) = companyValue
                else {
                    throw MCPError.invalidParams("missing company")
                }
                guard let recipientValue = params.arguments?["recipient"],
                    case let .string(recipient) = recipientValue
                else {
                    throw MCPError.invalidParams("missing recipient")
                }
                guard let sharesValue = params.arguments?["shares"],
                    case let .string(shares) = sharesValue
                else {
                    throw MCPError.invalidParams("missing shares")
                }

                let response = """
                    STOCK ISSUANCE CERTIFICATE

                    Company: \(company)
                    Recipient: \(recipient)
                    Number of Shares: \(shares)

                    This certifies that \(recipient) is the registered holder of \(shares) shares of the capital stock of \(company), transferable only on the books of the Corporation by the holder hereof in person or by duly authorized attorney upon surrender of this Certificate properly endorsed.

                    This stock issuance is subject to the terms and conditions set forth in the Company's Articles of Incorporation and Bylaws, as they may be amended from time to time.

                    Date of Issuance: \(Date().formatted(date: .abbreviated, time: .omitted))

                    _________________________________
                    Secretary

                    _________________________________
                    President

                    [This is a template document. Please review with legal counsel before finalizing.]
                    """

                return CallTool.Result(
                    content: [.text(response)],
                    isError: false
                )
            } else if params.name == "search_cases" {
                logger.info(
                    "search_cases tool called",
                    metadata: [
                        "timestamp": "\(Date().description)",
                        "params_name": "\(params.name)",
                        "arguments_type": "\(type(of: params.arguments))",
                    ]
                )

                // Debug: Print all received arguments with detailed type information
                if let args = params.arguments {
                    var argsMetadata: [String: Logger.MetadataValue] = [
                        "args_count": "\(args.count)"
                    ]

                    for (key, value) in args {
                        argsMetadata["arg_\(key)_value"] = "\(value)"
                        argsMetadata["arg_\(key)_type"] = "\(type(of: value))"
                        // Note: value is MCP.Value, not native Swift String
                        if case let .string(stringValue) = value {
                            argsMetadata["arg_\(key)_length"] = "\(stringValue.count)"
                            argsMetadata["arg_\(key)_preview"] = "\(String(stringValue.prefix(100)))"
                        }
                    }

                    logger.debug("Arguments details", metadata: argsMetadata)
                } else {
                    logger.warning("Arguments is nil")
                }

                // Extract the inquiry parameter - need to extract string from MCP.Value
                guard let inquiryValue = params.arguments?["inquiry"],
                    case let .string(inquiry) = inquiryValue
                else {
                    let availableKeys = params.arguments?.keys.joined(separator: ", ") ?? "none"
                    let argumentDetails =
                        params.arguments?.map { "\($0.key): \(type(of: $0.value)) = \($0.value)" }.joined(
                            separator: "\n"
                        ) ?? "none"

                    var errorMetadata: [String: Logger.MetadataValue] = [
                        "available_keys": "\(availableKeys)",
                        "argument_details": "\(argumentDetails)",
                    ]

                    // Additional debugging for parameter extraction
                    if let args = params.arguments {
                        var caseVariations: [String] = []
                        for key in args.keys {
                            caseVariations.append("'\(key)' (lowercased: '\(key.lowercased())')")
                        }
                        errorMetadata["case_variations"] = "\(caseVariations.joined(separator: ", "))"

                        // Try to find inquiry with different approaches
                        if let value = args["inquiry"] {
                            errorMetadata["inquiry_key_found"] = "true"
                            errorMetadata["inquiry_value"] = "\(value)"
                            errorMetadata["inquiry_type"] = "\(type(of: value))"
                        }
                    }

                    logger.error("Parameter extraction failed - missing inquiry parameter", metadata: errorMetadata)

                    throw MCPError.invalidParams("missing inquiry parameter. Available parameters: \(availableKeys)")
                }

                logger.info(
                    "Successfully extracted inquiry parameter",
                    metadata: [
                        "raw_inquiry": "\(inquiry)",
                        "inquiry_length": "\(inquiry.count)",
                    ]
                )

                // Validate that inquiry is not empty after trimming
                let trimmedInquiry = inquiry.trimmingCharacters(in: .whitespacesAndNewlines)
                logger.debug(
                    "Inquiry trimmed",
                    metadata: [
                        "trimmed_inquiry": "\(trimmedInquiry)",
                        "trimmed_length": "\(trimmedInquiry.count)",
                    ]
                )

                guard !trimmedInquiry.isEmpty else {
                    logger.error("Inquiry is empty after trimming")
                    return CallTool.Result(
                        content: [
                            .text(
                                "Please provide a search inquiry. For example: 'contract disputes', 'employment law', or 'trademark infringement'"
                            )
                        ],
                        isError: true
                    )
                }

                logger.info("Proceeding with API call", metadata: ["inquiry": "\(trimmedInquiry)"])

                // Search using Docket Alarm API
                do {
                    logger.debug("Calling searchDocketAlarmCases")
                    let searchResults = try await searchDocketAlarmCases(query: trimmedInquiry)
                    logger.info(
                        "API call completed successfully",
                        metadata: [
                            "response_length": "\(searchResults.count)"
                        ]
                    )

                    return CallTool.Result(
                        content: [.text(searchResults)],
                        isError: false
                    )
                } catch {
                    logger.error(
                        "API call failed",
                        metadata: [
                            "error": "\(error)",
                            "error_type": "\(type(of: error))",
                            "error_description": "\(error.localizedDescription)",
                            "attempted_inquiry": "\(trimmedInquiry)",
                        ]
                    )

                    let errorMessage = """
                        Error searching legal cases: \(error.localizedDescription)

                        Please try again with a different search inquiry or check your network connection.

                        Inquiry attempted: '\(trimmedInquiry)'

                        Debug info: Error type \(type(of: error))
                        """

                    return CallTool.Result(
                        content: [.text(errorMessage)],
                        isError: true
                    )
                }
                logger.info("search_cases tool completed")
            }

            // This should never be reached due to the guard above ensuring all tool names are handled
            fatalError("Unhandled tool name despite guard validation")
        }

        mainLogger.info("Method handlers registered")

        // Create stdio transport and start the server
        mainLogger.info("Creating stdio transport...")
        let transport = StdioTransport()

        mainLogger.info("Starting server...")
        try await server.start(transport: transport)

        mainLogger.info("Server started successfully, waiting for completion...")

        // Keep the server running
        await server.waitUntilCompleted()

        mainLogger.info("Server completed")
    }
}
