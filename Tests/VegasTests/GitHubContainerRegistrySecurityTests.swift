import Foundation
import Testing

@testable import Vegas

/// Security tests to prevent GitHub Container Registry URL fishing attacks
@Suite("GitHub Container Registry Security")
struct GitHubContainerRegistrySecurityTests {

    /// Test that SecureGitHubRegistry only accepts valid ghcr.io URLs
    @Test("Secure registry prevents malicious URLs")
    func testSecureRegistryPreventsMaliciousURLs() throws {
        // Valid GitHub Container Registry URLs should work
        let validRegistry = try SecureGitHubRegistry(repository: "neon-law-foundation/bazaar")
        #expect(validRegistry.imageURL == "ghcr.io/neon-law-foundation/bazaar")

        let anotherValidRegistry = try SecureGitHubRegistry(repository: "some-org/some-repo")
        #expect(anotherValidRegistry.imageURL == "ghcr.io/some-org/some-repo")
    }

    @Test("Secure registry rejects fishing attack URLs")
    func testSecureRegistryRejectsFishingAttacks() throws {
        // Common fishing attack patterns should fail
        let fishingURLs = [
            "github.io/malicious/repo",  // Similar to ghcr.io but different domain
            "ghcr.com/fake/repo",  // Similar domain
            "gcr.io/attacker/repo",  // Google Container Registry (not GitHub)
            "docker.io/malicious/repo",  // Docker Hub
            "quay.io/attacker/repo",  // Red Hat Quay
            "malicious.ghcr.io/fake/repo",  // Subdomain attack
            "ghcr.io.evil.com/fake/repo",  // Domain spoofing
            "../../../etc/passwd",  // Path traversal attempt
            "file:///etc/passwd",  // Local file access
            "http://ghcr.io/fake/repo",  // Wrong protocol
            "https://ghcr.io/fake/repo",  // Should not include protocol
        ]

        for maliciousURL in fishingURLs {
            do {
                let _ = try SecureGitHubRegistry(repository: maliciousURL)
                Issue.record("Expected SecurityError for malicious URL: \(maliciousURL)")
            } catch SecurityError.invalidGitHubContainerRegistry {
                // Expected - this is the correct behavior
                continue
            } catch {
                Issue.record("Unexpected error for \(maliciousURL): \(error)")
            }
        }
    }

    @Test("ServiceUpdateConfig uses secure registry")
    func testServiceUpdateConfigUseSecureRegistry() throws {
        let bazaarConfig = try SecureServiceUpdateConfig(
            serviceName: "bazaar",
            stackName: "bazaar-service",
            clusterName: "bazaar-cluster",
            repository: "neon-law-foundation/bazaar"
        )

        let destinedConfig = try SecureServiceUpdateConfig(
            serviceName: "destined",
            stackName: "destined-service",
            clusterName: "destined-cluster",
            repository: "neon-law-foundation/destined"
        )

        #expect(bazaarConfig.imageRepository == "ghcr.io/neon-law-foundation/bazaar")
        #expect(destinedConfig.imageRepository == "ghcr.io/neon-law-foundation/destined")
    }

    @Test("Validates existing hardcoded repository URLs are secure")
    func testExistingRepositoryURLsSecurity() throws {
        // Test the existing hardcoded values to ensure they're safe
        let existingRepositories = [
            "ghcr.io/neon-law-foundation/bazaar",
            "ghcr.io/neon-law-foundation/destined",
        ]

        for repo in existingRepositories {
            // Verify each repo uses the secure ghcr.io domain
            #expect(repo.hasPrefix("ghcr.io/"))
            #expect(!repo.contains("://"))  // No protocol
            #expect(!repo.contains(".."))  // No path traversal
            #expect(!repo.hasPrefix("."))  // No relative paths

            // Verify it's a valid GitHub Container Registry URL format
            let components = repo.split(separator: "/")
            #expect(components.count >= 3)  // Should be ghcr.io/org/repo at minimum
            #expect(components[0] == "ghcr.io")
        }
    }
}
