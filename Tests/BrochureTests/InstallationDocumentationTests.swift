import Foundation
import Testing

@testable import Brochure

@Suite("Installation Documentation", .disabled("Documentation files have been removed from the project"))
struct InstallationDocumentationTests {

    private func findProjectRoot() -> URL? {
        var currentURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

        // Walk up the directory tree looking for Package.swift
        while currentURL.path != "/" {
            let packageSwiftPath = currentURL.appendingPathComponent("Package.swift").path
            if FileManager.default.fileExists(atPath: packageSwiftPath) {
                return currentURL
            }
            currentURL = currentURL.deletingLastPathComponent()
        }

        return nil
    }

    @Test("Installation documentation files exist")
    func testDocumentationFilesExist() {
        // Find project root by looking for Package.swift
        guard let projectRoot = findProjectRoot() else {
            fatalError("Could not find project root")
        }

        let baseDir = projectRoot.appendingPathComponent("Documentation/BrochureCLI").path

        // Check that main installation guide exists
        let installationGuide = "\(baseDir)/INSTALLATION.md"
        #expect(FileManager.default.fileExists(atPath: installationGuide))

        // Check that quick start guide exists
        let quickStartGuide = "\(baseDir)/QUICKSTART.md"
        #expect(FileManager.default.fileExists(atPath: quickStartGuide))

        // Check that install script exists
        let installScript = projectRoot.appendingPathComponent("scripts/install-brochure-cli.sh").path
        #expect(FileManager.default.fileExists(atPath: installScript))

        // Verify install script is executable
        let attributes = try? FileManager.default.attributesOfItem(atPath: installScript)
        let permissions = attributes?[.posixPermissions] as? NSNumber
        #expect(permissions?.uint16Value ?? 0 & 0o111 != 0)  // Check executable bits
    }

    @Test("Installation guide contains essential curl examples")
    func testInstallationGuideContent() throws {
        guard let projectRoot = findProjectRoot() else {
            fatalError("Could not find project root")
        }
        let installationGuide = projectRoot.appendingPathComponent("Documentation/BrochureCLI/INSTALLATION.md").path
        let content = try String(contentsOfFile: installationGuide, encoding: .utf8)

        // Check for essential curl commands
        #expect(content.contains("curl -fsSL https://cli.neonlaw.com/brochure/install.sh | bash"))
        #expect(
            content.contains("curl -L -o brochure https://cli.neonlaw.com/brochure/latest/darwin-universal/brochure")
        )
        #expect(content.contains("curl -L -o brochure https://cli.neonlaw.com/brochure/latest/linux-x64/brochure"))

        // Check for checksum verification examples
        #expect(content.contains("shasum -a 256 -c brochure.sha256"))
        #expect(content.contains("sha256sum -c brochure.sha256"))

        // Check for version-specific installation
        #expect(content.contains("curl -fsSL https://cli.neonlaw.com/brochure/install.sh | bash -s v1.2.0"))

        // Check for custom directory installation
        #expect(content.contains("INSTALL_DIR=$HOME/.local/bin"))

        // Check for platform-specific sections
        #expect(content.contains("### macOS"))
        #expect(content.contains("### Linux"))

        // Check for CI/CD examples
        #expect(content.contains("GitHub Actions"))
        #expect(content.contains("GitLab CI"))
        #expect(content.contains("CircleCI"))

        // Check for troubleshooting section
        #expect(content.contains("## Troubleshooting"))
        #expect(content.contains("Command not found"))
        #expect(content.contains("Permission denied"))
    }

    @Test("Quick start guide contains essential commands")
    func testQuickStartGuideContent() throws {
        guard let projectRoot = findProjectRoot() else {
            fatalError("Could not find project root")
        }
        let quickStartGuide = projectRoot.appendingPathComponent("Documentation/BrochureCLI/QUICKSTART.md").path
        let content = try String(contentsOfFile: quickStartGuide, encoding: .utf8)

        // Check for 30-second installation
        #expect(content.contains("30-Second Installation"))
        #expect(content.contains("curl -fsSL https://cli.neonlaw.com/brochure/install.sh | bash"))

        // Check for platform-specific download URLs
        #expect(content.contains("darwin-universal"))
        #expect(content.contains("darwin-arm64"))
        #expect(content.contains("darwin-x64"))
        #expect(content.contains("linux-x64"))

        // Check for verification examples
        #expect(content.contains("brochure verify --self"))
        #expect(content.contains("brochure --version"))

        // Check for one-liner examples
        #expect(content.contains("Manual Download with Verification"))
        #expect(content.contains("shasum -a 256 -c"))
        #expect(content.contains("sha256sum -c"))

        // Check for JSON examples
        #expect(content.contains("jq -r '.latest'"))
        #expect(content.contains("versions.json"))
    }

    @Test("Install script has proper structure")
    func testInstallScriptStructure() throws {
        guard let projectRoot = findProjectRoot() else {
            fatalError("Could not find project root")
        }
        let installScript = projectRoot.appendingPathComponent("scripts/install-brochure-cli.sh").path
        let content = try String(contentsOfFile: installScript, encoding: .utf8)

        // Check shebang
        #expect(content.hasPrefix("#!/bin/bash"))

        // Check for essential functions
        #expect(content.contains("detect_platform()"))
        #expect(content.contains("download_binary()"))
        #expect(content.contains("install_binary()"))
        #expect(content.contains("verify_installation()"))

        // Check for configuration variables
        #expect(content.contains("BASE_URL="))
        #expect(content.contains("VERSION="))
        #expect(content.contains("INSTALL_DIR="))

        // Check for error handling
        #expect(content.contains("set -euo pipefail"))
        #expect(content.contains("log_error"))

        // Check for platform detection
        #expect(content.contains("uname -s"))
        #expect(content.contains("uname -m"))
        #expect(content.contains("darwin"))
        #expect(content.contains("linux"))

        // Check for checksum verification
        #expect(content.contains("shasum -a 256"))
        #expect(content.contains("sha256sum"))
        #expect(content.contains("EXPECTED_SHA"))
        #expect(content.contains("ACTUAL_SHA"))

        // Check for cleanup
        #expect(content.contains("cleanup()"))
        #expect(content.contains("trap cleanup EXIT"))
    }

    @Test("Documentation contains complete download URL structure")
    func testDownloadURLStructure() throws {
        guard let projectRoot = findProjectRoot() else {
            fatalError("Could not find project root")
        }
        let installationGuide = projectRoot.appendingPathComponent("Documentation/BrochureCLI/INSTALLATION.md").path
        let content = try String(contentsOfFile: installationGuide, encoding: .utf8)

        // Check base URL structure
        #expect(content.contains("https://cli.neonlaw.com/brochure/"))

        // Check version paths
        #expect(content.contains("/latest/"))
        #expect(content.contains("/v1.2.0/"))

        // Check platform paths
        #expect(content.contains("/darwin-universal/"))
        #expect(content.contains("/darwin-arm64/"))
        #expect(content.contains("/darwin-x64/"))
        #expect(content.contains("/linux-x64/"))

        // Check file types
        #expect(content.contains("/brochure"))
        #expect(content.contains("/brochure.sha256"))

        // Check special files
        #expect(content.contains("/versions.json"))
        #expect(content.contains("/install.sh"))
    }

    @Test("Documentation includes all supported platforms")
    func testSupportedPlatforms() throws {
        guard let projectRoot = findProjectRoot() else {
            fatalError("Could not find project root")
        }
        let installationGuide = projectRoot.appendingPathComponent("Documentation/BrochureCLI/INSTALLATION.md").path
        let content = try String(contentsOfFile: installationGuide, encoding: .utf8)

        // Check platform table exists
        #expect(content.contains("| Platform | Architecture | Download URL |"))

        // Check all supported platform/architecture combinations
        #expect(content.contains("macOS | Universal"))
        #expect(content.contains("macOS | ARM64"))
        #expect(content.contains("macOS | x64"))
        #expect(content.contains("Linux | x64"))

        // Check architecture detection
        #expect(content.contains("Apple Silicon"))
        #expect(content.contains("Intel"))
    }

    @Test("Documentation provides comprehensive verification examples")
    func testVerificationExamples() throws {
        guard let projectRoot = findProjectRoot() else {
            fatalError("Could not find project root")
        }
        let installationGuide = projectRoot.appendingPathComponent("Documentation/BrochureCLI/INSTALLATION.md").path
        let content = try String(contentsOfFile: installationGuide, encoding: .utf8)

        // Check built-in verify command examples
        #expect(content.contains("brochure verify --self"))
        #expect(content.contains("brochure verify --binary"))
        #expect(content.contains("brochure verify --download"))
        #expect(content.contains("--remote-checksum"))
        #expect(content.contains("--checksum-url"))
        #expect(content.contains("--json"))

        // Check manual verification
        #expect(content.contains("shasum -a 256 -c"))
        #expect(content.contains("sha256sum -c"))

        // Check verification workflow
        #expect(content.contains("Download binary and checksum"))
        #expect(content.contains("Verify checksum"))
        #expect(content.contains("Make executable"))
    }

    @Test("Documentation includes CI/CD integration examples")
    func testCICDExamples() throws {
        guard let projectRoot = findProjectRoot() else {
            fatalError("Could not find project root")
        }
        let installationGuide = projectRoot.appendingPathComponent("Documentation/BrochureCLI/INSTALLATION.md").path
        let content = try String(contentsOfFile: installationGuide, encoding: .utf8)

        // Check GitHub Actions example
        #expect(content.contains("name: Deploy with Brochure CLI"))
        #expect(content.contains("uses: actions/checkout@v4"))
        #expect(content.contains("curl -fsSL https://cli.neonlaw.com/brochure/install.sh | bash"))

        // Check GitLab CI example
        #expect(content.contains("image: alpine:latest"))
        #expect(content.contains("apk add --no-cache curl"))

        // Check CircleCI example
        #expect(content.contains("docker:"))
        #expect(content.contains("circleci/"))

        // Check environment variables
        #expect(content.contains("AWS_ACCESS_KEY_ID"))
        #expect(content.contains("AWS_SECRET_ACCESS_KEY"))
    }

    @Test("Documentation provides comprehensive error handling")
    func testErrorHandling() throws {
        guard let projectRoot = findProjectRoot() else {
            fatalError("Could not find project root")
        }
        let installationGuide = projectRoot.appendingPathComponent("Documentation/BrochureCLI/INSTALLATION.md").path
        let content = try String(contentsOfFile: installationGuide, encoding: .utf8)

        // Check common error scenarios
        #expect(content.contains("Command not found: brochure"))
        #expect(content.contains("Permission denied"))
        #expect(content.contains("Checksum verification fails"))
        #expect(content.contains("cannot be opened because the developer cannot be verified"))

        // Check solutions
        #expect(content.contains("Check if binary is installed"))
        #expect(content.contains("Check if /usr/local/bin is in PATH"))
        #expect(content.contains("Add to PATH"))
        #expect(content.contains("Use sudo"))
        #expect(content.contains("xattr -d com.apple.quarantine"))

        // Check PATH instructions for different shells
        #expect(content.contains("~/.bashrc"))
        #expect(content.contains("~/.zshrc"))
    }
}
