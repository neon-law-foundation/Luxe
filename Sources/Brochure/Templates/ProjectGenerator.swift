import Foundation
import Logging

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Generates a project from a template.
public struct ProjectGenerator {
    private let logger: Logger
    private let fileManager = FileManager.default
    private let renderer: TemplateRenderer

    public init(logger: Logger? = nil) {
        self.logger = logger ?? Logger(label: "ProjectGenerator")
        self.renderer = TemplateRenderer(logger: self.logger)
    }

    /// Generate a complete project from a template.
    public func generate(
        template: Template,
        at projectPath: URL,
        with context: TemplateContext
    ) async throws {
        logger.info("Generating project from template: \(template.name)")

        // Validate context has required values
        try context.validate(requiredKeys: template.requiredContext)

        // Create project directory
        try createProjectDirectory(at: projectPath)

        // Create directory structure
        try await createDirectories(template.structure.directories, at: projectPath)

        // Generate files
        try await generateFiles(template.structure.files, at: projectPath, context: context)

        // Copy assets
        try await copyAssets(template.structure.assets, to: projectPath)

        // Set file permissions
        try await setFilePermissions(template.structure, at: projectPath)

        logger.info("Project generation completed successfully")
    }

    /// Create the project root directory.
    private func createProjectDirectory(at path: URL) throws {
        logger.debug("Creating project directory: \(path.path)")

        try fileManager.createDirectory(
            at: path,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    /// Create all directories in the template structure.
    private func createDirectories(
        _ directories: [DirectoryTemplate],
        at basePath: URL
    ) async throws {
        for directory in directories {
            let fullPath = basePath.appendingPathComponent(directory.path)

            logger.debug("Creating directory: \(directory.path)")

            try fileManager.createDirectory(
                at: fullPath,
                withIntermediateDirectories: true,
                attributes: nil
            )

            // Set directory permissions if not default
            if directory.permissions != .default {
                try fileManager.setAttributes(
                    [.posixPermissions: directory.permissions.rawValue],
                    ofItemAtPath: fullPath.path
                )
            }
        }
    }

    /// Generate all files from templates.
    private func generateFiles(
        _ files: [FileTemplate],
        at basePath: URL,
        context: TemplateContext
    ) async throws {
        for file in files {
            let fullPath = basePath.appendingPathComponent(file.path)

            logger.debug("Generating file: \(file.path)")

            // Ensure parent directory exists
            let parentDirectory = fullPath.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDirectory.path) {
                try fileManager.createDirectory(
                    at: parentDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }

            // Process content based on type
            let content: String
            switch file.content {
            case .template(let templateString):
                content = try renderer.render(templateString, context: context)

            case .static(let staticContent):
                content = staticContent

            case .binary(let data):
                // Write binary data directly
                try data.write(to: fullPath)
                continue
            }

            // Write text content
            do {
                try content.write(
                    to: fullPath,
                    atomically: true,
                    encoding: file.encoding
                )
            } catch {
                throw TemplateError.fileWriteFailed(file.path, error)
            }
        }
    }

    /// Copy assets to the project.
    private func copyAssets(
        _ assets: [AssetTemplate],
        to basePath: URL
    ) async throws {
        for asset in assets {
            let fullPath = basePath.appendingPathComponent(asset.path)

            logger.debug("Copying asset: \(asset.path)")

            // Ensure parent directory exists
            let parentDirectory = fullPath.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDirectory.path) {
                try fileManager.createDirectory(
                    at: parentDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }

            switch asset.content {
            case .embedded(let data):
                try data.write(to: fullPath)

            case .base64(let base64String):
                guard let data = Data(base64Encoded: base64String) else {
                    throw TemplateError.invalidTemplate("Invalid base64 data for asset: \(asset.path)")
                }
                try data.write(to: fullPath)

            case .external(let url):
                // Download external resource
                let (data, _) = try await URLSession.shared.data(from: url)
                try data.write(to: fullPath)
            }
        }
    }

    /// Set file permissions for generated files.
    private func setFilePermissions(
        _ structure: TemplateStructure,
        at basePath: URL
    ) async throws {
        // Set file permissions
        for file in structure.files {
            if file.permissions != .default {
                let fullPath = basePath.appendingPathComponent(file.path)

                try fileManager.setAttributes(
                    [.posixPermissions: file.permissions.rawValue],
                    ofItemAtPath: fullPath.path
                )
            }
        }

        // Set asset permissions
        for asset in structure.assets {
            if asset.permissions != .default {
                let fullPath = basePath.appendingPathComponent(asset.path)

                try fileManager.setAttributes(
                    [.posixPermissions: asset.permissions.rawValue],
                    ofItemAtPath: fullPath.path
                )
            }
        }
    }
}
