import Foundation
import Testing

@testable import Brochure

@Suite("Template Versioning Tests")
struct TemplateVersioningTests {

    @Test("Should create template version with semantic versioning")
    func testTemplateVersionCreation() throws {
        let version = TemplateVersion(major: 1, minor: 2, patch: 3)

        #expect(version.major == 1)
        #expect(version.minor == 2)
        #expect(version.patch == 3)
        #expect(version.toString() == "1.2.3")
    }

    @Test("Should parse version string correctly")
    func testVersionStringParsing() throws {
        let version = try TemplateVersion(fromString: "2.1.0")

        #expect(version.major == 2)
        #expect(version.minor == 1)
        #expect(version.patch == 0)
    }

    @Test("Should reject invalid version strings")
    func testInvalidVersionStrings() throws {
        let invalidVersions = [
            "1.2",  // Missing patch
            "1.2.3.4",  // Too many components
            "a.b.c",  // Non-numeric
            "",  // Empty
            "1.-1.0",  // Negative numbers
        ]

        for invalidVersion in invalidVersions {
            #expect(throws: TemplateVersionError.self) {
                try TemplateVersion(fromString: invalidVersion)
            }
        }
    }

    @Test("Should compare versions correctly")
    func testVersionComparison() throws {
        let v1_0_0 = TemplateVersion(major: 1, minor: 0, patch: 0)
        let v1_0_1 = TemplateVersion(major: 1, minor: 0, patch: 1)
        let v1_1_0 = TemplateVersion(major: 1, minor: 1, patch: 0)
        let v2_0_0 = TemplateVersion(major: 2, minor: 0, patch: 0)

        // Test less than
        #expect(v1_0_0 < v1_0_1)
        #expect(v1_0_1 < v1_1_0)
        #expect(v1_1_0 < v2_0_0)

        // Test greater than
        #expect(v2_0_0 > v1_1_0)
        #expect(v1_1_0 > v1_0_1)
        #expect(v1_0_1 > v1_0_0)

        // Test equality
        let v1_0_0_copy = TemplateVersion(major: 1, minor: 0, patch: 0)
        #expect(v1_0_0 == v1_0_0_copy)
    }

    @Test("Should check version compatibility")
    func testVersionCompatibility() throws {
        let v1_0_0 = TemplateVersion(major: 1, minor: 0, patch: 0)
        let v1_2_3 = TemplateVersion(major: 1, minor: 2, patch: 3)
        let v2_0_0 = TemplateVersion(major: 2, minor: 0, patch: 0)

        // Same major version should be compatible
        #expect(v1_0_0.isCompatible(with: v1_2_3))
        #expect(v1_2_3.isCompatible(with: v1_0_0))

        // Different major version should not be compatible
        #expect(!v1_0_0.isCompatible(with: v2_0_0))
        #expect(!v2_0_0.isCompatible(with: v1_0_0))
    }

    @Test("Should create versioned template")
    func testVersionedTemplate() throws {
        let version = TemplateVersion(major: 1, minor: 0, patch: 0)
        let template = Template(
            id: "landing-page",
            name: "Landing Page",
            description: "Test template",
            category: .landingPage,
            structure: TemplateStructure(),
            version: version
        )

        #expect(template.version == version)
        #expect(template.version.toString() == "1.0.0")
    }

    @Test("Should validate template compatibility")
    func testTemplateCompatibilityValidation() throws {
        let v1_0_0 = TemplateVersion(major: 1, minor: 0, patch: 0)
        let v1_2_0 = TemplateVersion(major: 1, minor: 2, patch: 0)
        let v2_0_0 = TemplateVersion(major: 2, minor: 0, patch: 0)

        let template1 = Template(
            id: "test",
            name: "Test",
            description: "Test",
            category: .landingPage,
            structure: TemplateStructure(),
            version: v1_0_0
        )

        // Should be compatible with same major version
        #expect(template1.isCompatible(withVersion: v1_2_0))

        // Should not be compatible with different major version
        #expect(!template1.isCompatible(withVersion: v2_0_0))
    }

    @Test("Should handle template migration information")
    func testTemplateMigrationInfo() throws {
        let currentVersion = TemplateVersion(major: 1, minor: 0, patch: 0)
        let targetVersion = TemplateVersion(major: 1, minor: 1, patch: 0)

        let template = Template(
            id: "test",
            name: "Test",
            description: "Test",
            category: .landingPage,
            structure: TemplateStructure(),
            version: currentVersion
        )

        let migrationInfo = template.migrationInfo(to: targetVersion)

        #expect(migrationInfo.fromVersion == currentVersion)
        #expect(migrationInfo.toVersion == targetVersion)
        #expect(migrationInfo.isBreakingChange == false)  // Minor version change
        #expect(migrationInfo.canAutoMigrate == true)  // Same major version
    }

    @Test("Should detect breaking changes in major version updates")
    func testBreakingChangeDetection() throws {
        let v1_0_0 = TemplateVersion(major: 1, minor: 0, patch: 0)
        let v2_0_0 = TemplateVersion(major: 2, minor: 0, patch: 0)

        let template = Template(
            id: "test",
            name: "Test",
            description: "Test",
            category: .landingPage,
            structure: TemplateStructure(),
            version: v1_0_0
        )

        let migrationInfo = template.migrationInfo(to: v2_0_0)

        #expect(migrationInfo.isBreakingChange == true)  // Major version change
        #expect(migrationInfo.canAutoMigrate == false)  // Cannot auto-migrate major changes
    }

    @Test("Should generate version metadata")
    func testVersionMetadata() throws {
        let version = TemplateVersion(major: 1, minor: 2, patch: 3)
        let template = Template(
            id: "landing-page",
            name: "Landing Page",
            description: "Test template",
            category: .landingPage,
            structure: TemplateStructure(),
            version: version
        )

        let metadata = template.versionMetadata()

        #expect(metadata["version"] as? String == "1.2.3")
        #expect(metadata["major"] as? Int == 1)
        #expect(metadata["minor"] as? Int == 2)
        #expect(metadata["patch"] as? Int == 3)
        #expect(metadata["template_id"] as? String == "landing-page")
    }
}
