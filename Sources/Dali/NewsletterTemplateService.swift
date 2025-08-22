import Fluent
import FluentPostgresDriver
import Foundation

/// Service for managing newsletter templates
public struct NewsletterTemplateService {
    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    /// Get all active newsletter templates
    public func getActiveTemplates() async throws -> [NewsletterTemplate] {
        guard let postgresDB = database as? PostgresDatabase else {
            throw NewsletterTemplateError.databaseError
        }

        let result = try await postgresDB.sql()
            .raw(
                """
                SELECT 
                    id, name, description, template_content, category, is_active,
                    created_by, created_at, updated_at
                FROM marketing.newsletter_templates 
                WHERE is_active = true
                ORDER BY category, name
                """
            )
            .all()

        return try result.compactMap { row in
            guard let id = try row.decode(column: "id", as: UUID?.self),
                let name = try row.decode(column: "name", as: String?.self),
                let templateContent = try row.decode(column: "template_content", as: String?.self),
                let category = try row.decode(column: "category", as: String?.self),
                let isActive = try row.decode(column: "is_active", as: Bool?.self),
                let createdBy = try row.decode(column: "created_by", as: UUID?.self),
                let createdAt = try row.decode(column: "created_at", as: Date?.self),
                let updatedAt = try row.decode(column: "updated_at", as: Date?.self)
            else { return nil }

            let description = try row.decode(column: "description", as: String?.self)

            return NewsletterTemplate(
                id: id,
                name: name,
                description: description,
                templateContent: templateContent,
                category: category,
                isActive: isActive,
                createdBy: createdBy,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }
    }

    /// Get template by ID
    public func getTemplate(id: UUID) async throws -> NewsletterTemplate? {
        guard let postgresDB = database as? PostgresDatabase else {
            throw NewsletterTemplateError.databaseError
        }

        let result = try await postgresDB.sql()
            .raw(
                """
                SELECT 
                    id, name, description, template_content, category, is_active,
                    created_by, created_at, updated_at
                FROM marketing.newsletter_templates 
                WHERE id = \(bind: id)
                """
            )
            .first()

        guard let row = result else { return nil }

        guard let templateId = try row.decode(column: "id", as: UUID?.self),
            let name = try row.decode(column: "name", as: String?.self),
            let templateContent = try row.decode(column: "template_content", as: String?.self),
            let category = try row.decode(column: "category", as: String?.self),
            let isActive = try row.decode(column: "is_active", as: Bool?.self),
            let createdBy = try row.decode(column: "created_by", as: UUID?.self),
            let createdAt = try row.decode(column: "created_at", as: Date?.self),
            let updatedAt = try row.decode(column: "updated_at", as: Date?.self)
        else { return nil }

        let description = try row.decode(column: "description", as: String?.self)

        return NewsletterTemplate(
            id: templateId,
            name: name,
            description: description,
            templateContent: templateContent,
            category: category,
            isActive: isActive,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Create a new newsletter template
    public func createTemplate(
        name: String,
        description: String?,
        templateContent: String,
        category: String,
        createdBy: UUID
    ) async throws -> NewsletterTemplate {
        guard let postgresDB = database as? PostgresDatabase else {
            throw NewsletterTemplateError.databaseError
        }

        let id = UUID()
        let now = Date()

        _ = try await postgresDB.sql()
            .raw(
                """
                INSERT INTO marketing.newsletter_templates 
                (id, name, description, template_content, category, created_by, created_at, updated_at)
                VALUES (\(bind: id), \(bind: name), \(bind: description), \(bind: templateContent), \(bind: category), \(bind: createdBy), \(bind: now), \(bind: now))
                """
            )
            .run()

        return NewsletterTemplate(
            id: id,
            name: name,
            description: description,
            templateContent: templateContent,
            category: category,
            isActive: true,
            createdBy: createdBy,
            createdAt: now,
            updatedAt: now
        )
    }

    /// Update an existing template
    public func updateTemplate(
        id: UUID,
        name: String,
        description: String?,
        templateContent: String,
        category: String
    ) async throws -> NewsletterTemplate? {
        guard let postgresDB = database as? PostgresDatabase else {
            throw NewsletterTemplateError.databaseError
        }

        let now = Date()

        _ = try await postgresDB.sql()
            .raw(
                """
                UPDATE marketing.newsletter_templates 
                SET name = \(bind: name), 
                    description = \(bind: description), 
                    template_content = \(bind: templateContent),
                    category = \(bind: category),
                    updated_at = \(bind: now)
                WHERE id = \(bind: id)
                """
            )
            .run()

        return try await getTemplate(id: id)
    }

    /// Apply template to newsletter content with merge tags
    public func applyTemplate(_ template: NewsletterTemplate, mergeData: [String: String]) -> String {
        var content = template.templateContent

        // Replace merge tags like {{user_name}}, {{newsletter_type}} etc.
        for (key, value) in mergeData {
            content = content.replacingOccurrences(of: "{{\(key)}}", with: value)
        }

        return content
    }
}

// MARK: - Supporting Types

public struct NewsletterTemplate: Sendable {
    public let id: UUID
    public let name: String
    public let description: String?
    public let templateContent: String
    public let category: String
    public let isActive: Bool
    public let createdBy: UUID
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID,
        name: String,
        description: String?,
        templateContent: String,
        category: String,
        isActive: Bool,
        createdBy: UUID,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.templateContent = templateContent
        self.category = category
        self.isActive = isActive
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum NewsletterTemplateError: Error, LocalizedError {
    case databaseError
    case templateNotFound
    case invalidTemplateData

    public var errorDescription: String? {
        switch self {
        case .databaseError:
            return "Database error occurred"
        case .templateNotFound:
            return "Template not found"
        case .invalidTemplateData:
            return "Invalid template data"
        }
    }
}
