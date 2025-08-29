import ArgumentParser
import Foundation
import Testing

@testable import Brochure

// CommandError is coming from ArgumentParser but directly available, no typealias needed

/// Tests for the secure profiles command functionality.
///
/// These tests verify the ProfilesCommand and its subcommands handle argument parsing,
/// validation, and command structure correctly.
@Suite("ProfilesCommand Tests")
struct ProfilesCommandTests {

    @Test("ProfilesCommand has correct configuration")
    func testProfilesCommandConfiguration() throws {
        let config = ProfilesCommand.configuration

        #expect(config.commandName == "profiles")
        #expect(config.abstract.contains("secure AWS profile"))
        #expect(config.discussion.contains("keychain"))
        #expect(config.subcommands.count == 6)

        // Verify subcommands are included
        let subcommandTypes = config.subcommands.map { String(describing: $0) }
        #expect(subcommandTypes.contains("StoreProfileCommand"))
        #expect(subcommandTypes.contains("ListProfilesCommand"))
        #expect(subcommandTypes.contains("ShowProfileCommand"))
        #expect(subcommandTypes.contains("RemoveProfileCommand"))
        #expect(subcommandTypes.contains("MigrateProfileCommand"))
        #expect(subcommandTypes.contains("ClearProfilesCommand"))
    }

    @Test("StoreProfileCommand validates arguments correctly")
    func testStoreProfileCommandValidation() throws {
        // Test valid permanent credentials
        let validCommand = try StoreProfileCommand.parse([
            "--profile", "production",
            "--access-key", "AKIAIOSFODNN7EXAMPLE",
            "--secret-key", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            "--region", "us-east-1",
        ])

        #expect(validCommand.profile == "production")
        #expect(validCommand.accessKey == "AKIAIOSFODNN7EXAMPLE")
        #expect(validCommand.secretKey == "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY")
        #expect(validCommand.region == "us-east-1")
        #expect(validCommand.sessionToken == nil)
        #expect(!validCommand.force)
        #expect(!validCommand.verbose)

        // Test valid temporary credentials
        let tempCommand = try StoreProfileCommand.parse([
            "--profile", "temporary",
            "--access-key", "ASIAIOSFODNN7EXAMPLE",
            "--secret-key", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            "--session-token",
            "IQoJb3JpZ2luX2VjEHoaCXVzLWVhc3QtMSJHMEUCIEXAMPLETOKENVALIDSessionTokenExampleWithMoreCharactersToMeetMinimum",
            "--force",
            "--verbose",
        ])

        #expect(tempCommand.profile == "temporary")
        #expect(tempCommand.accessKey == "ASIAIOSFODNN7EXAMPLE")
        #expect(tempCommand.sessionToken?.starts(with: "IQoJb3JpZ2luX2VjEHoa") == true)
        #expect(tempCommand.force)
        #expect(tempCommand.verbose)
    }

    @Test("StoreProfileCommand validates profile name format")
    func testStoreProfileNameValidation() throws {
        // Test invalid profile names
        let invalidProfileNames = [
            "",  // empty
            "profile with spaces",
            "profile@with#symbols",
            "profile*with&special!chars",
            String(repeating: "a", count: 100),  // too long
        ]

        for invalidProfile in invalidProfileNames {
            #expect(throws: Error.self) {
                let command = try StoreProfileCommand.parse([
                    "--profile", invalidProfile,
                    "--access-key", "AKIAIOSFODNN7EXAMPLE",
                    "--secret-key", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
                ])
                try command.validate()
            }
        }

        // Test valid profile names
        let validProfileNames = [
            "production",
            "staging",
            "dev",
            "prod-account",
            "test_profile",
            "profile.with.dots",
            "profile123",
        ]

        for validProfile in validProfileNames {
            let command = try StoreProfileCommand.parse([
                "--profile", validProfile,
                "--access-key", "AKIAIOSFODNN7EXAMPLE",
                "--secret-key", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            ])

            // Should not throw
            try command.validate()
            #expect(command.profile == validProfile)
        }
    }

    @Test("StoreProfileCommand validates access key format")
    func testStoreAccessKeyValidation() throws {
        // Test invalid access keys
        let invalidAccessKeys = [
            "BKIAIOSFODNN7EXAMPLE",  // wrong prefix
            "AKIA",  // too short
            "AKIAIOSFODNN7EXAMPLETOOOLONGKEY",  // too long
            "akiaiosfodnn7example",  // lowercase
            "AKIA!@#$%^&*()123456",  // invalid characters
            "XKIAIOSFODNN7EXAMPLE",  // invalid prefix
        ]

        for invalidKey in invalidAccessKeys {
            #expect(throws: Error.self) {
                let command = try StoreProfileCommand.parse([
                    "--profile", "test",
                    "--access-key", invalidKey,
                    "--secret-key", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
                ])
                try command.validate()
            }
        }

        // Test valid access keys
        let validAccessKeys = [
            "AKIAIOSFODNN7EXAMPLE",  // permanent
            "ASIAIOSFODNN7EXAMPLE",  // temporary
            "AKIA1234567890ABCDEF",  // numeric
            "ASIA1234567890ABCDEF",  // temporary numeric
        ]

        for validKey in validAccessKeys {
            let command = try StoreProfileCommand.parse([
                "--profile", "test",
                "--access-key", validKey,
                "--secret-key", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            ])

            try command.validate()
            #expect(command.accessKey == validKey)
        }
    }

    @Test("StoreProfileCommand validates secret key format")
    func testStoreSecretKeyValidation() throws {
        // Test invalid secret keys
        let invalidSecretKeys = [
            "short",  // too short
            "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY1",  // too long (41 chars)
            "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLE",  // too short (39 chars)
            "wJalrXUtnFEMI/K7MDENG/bPxRfiCY@XAMPLE#",  // invalid characters
        ]

        for invalidSecret in invalidSecretKeys {
            #expect(throws: Error.self) {
                let command = try StoreProfileCommand.parse([
                    "--profile", "test",
                    "--access-key", "AKIAIOSFODNN7EXAMPLE",
                    "--secret-key", invalidSecret,
                ])
                try command.validate()
            }
        }

        // Test valid secret key
        let validSecretKey = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        let command = try StoreProfileCommand.parse([
            "--profile", "test",
            "--access-key", "AKIAIOSFODNN7EXAMPLE",
            "--secret-key", validSecretKey,
        ])

        try command.validate()
        #expect(command.secretKey == validSecretKey)
    }

    @Test("StoreProfileCommand validates session token length")
    func testStoreSessionTokenValidation() throws {
        // Test session token too short
        #expect(throws: Error.self) {
            let command = try StoreProfileCommand.parse([
                "--profile", "test",
                "--access-key", "ASIAIOSFODNN7EXAMPLE",
                "--secret-key", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
                "--session-token", "short",
            ])
            try command.validate()
        }

        // Test valid session token
        let validSessionToken = String(repeating: "a", count: 150)  // 150 characters
        let command = try StoreProfileCommand.parse([
            "--profile", "test",
            "--access-key", "ASIAIOSFODNN7EXAMPLE",
            "--secret-key", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            "--session-token", validSessionToken,
        ])

        try command.validate()
        #expect(command.sessionToken == validSessionToken)
    }

    @Test("StoreProfileCommand validates region format")
    func testStoreRegionValidation() throws {
        // Test invalid regions
        let invalidRegions = [
            "invalid-region",
            "us-east",
            "us-east-1-extra",
            "useast1",
            "US-EAST-1",
        ]

        for invalidRegion in invalidRegions {
            #expect(throws: Error.self) {
                let command = try StoreProfileCommand.parse([
                    "--profile", "test",
                    "--access-key", "AKIAIOSFODNN7EXAMPLE",
                    "--secret-key", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
                    "--region", invalidRegion,
                ])
                try command.validate()
            }
        }

        // Test valid regions
        let validRegions = [
            "us-east-1",
            "us-west-2",
            "eu-west-1",
            "ap-southeast-1",
            "ca-central-1",
        ]

        for validRegion in validRegions {
            let command = try StoreProfileCommand.parse([
                "--profile", "test",
                "--access-key", "AKIAIOSFODNN7EXAMPLE",
                "--secret-key", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
                "--region", validRegion,
            ])

            try command.validate()
            #expect(command.region == validRegion)
        }
    }

    @Test("ListProfilesCommand parses flags correctly")
    func testListProfilesCommandFlags() throws {
        // Test default flags
        let defaultCommand = try ListProfilesCommand.parse([])
        #expect(!defaultCommand.verbose)
        #expect(!defaultCommand.expiredOnly)
        #expect(!defaultCommand.temporaryOnly)

        // Test verbose flag
        let verboseCommand = try ListProfilesCommand.parse(["--verbose"])
        #expect(verboseCommand.verbose)

        // Test expired-only flag
        let expiredCommand = try ListProfilesCommand.parse(["--expired-only"])
        #expect(expiredCommand.expiredOnly)

        // Test temporary-only flag
        let temporaryCommand = try ListProfilesCommand.parse(["--temporary-only"])
        #expect(temporaryCommand.temporaryOnly)

        // Test combined flags
        let combinedCommand = try ListProfilesCommand.parse([
            "--verbose",
            "--expired-only",
        ])
        #expect(combinedCommand.verbose)
        #expect(combinedCommand.expiredOnly)
        #expect(!combinedCommand.temporaryOnly)
    }

    @Test("ShowProfileCommand requires profile argument")
    func testShowProfileCommandRequirements() throws {
        // Test missing profile argument
        #expect(throws: Error.self) {
            _ = try ShowProfileCommand.parse([])
        }

        // Test valid profile argument
        let command = try ShowProfileCommand.parse([
            "--profile", "production",
        ])
        #expect(command.profile == "production")
        #expect(!command.showCredentials)

        // Test with show-credentials flag
        let showCredsCommand = try ShowProfileCommand.parse([
            "--profile", "production",
            "--show-credentials",
        ])
        #expect(showCredsCommand.profile == "production")
        #expect(showCredsCommand.showCredentials)
    }

    @Test("RemoveProfileCommand parses arguments correctly")
    func testRemoveProfileCommandArguments() throws {
        // Test basic remove command
        let basicCommand = try RemoveProfileCommand.parse([
            "--profile", "test-profile",
        ])
        #expect(basicCommand.profile == "test-profile")
        #expect(!basicCommand.force)

        // Test remove with force flag
        let forceCommand = try RemoveProfileCommand.parse([
            "--profile", "test-profile",
            "--force",
        ])
        #expect(forceCommand.profile == "test-profile")
        #expect(forceCommand.force)
    }

    @Test("MigrateProfileCommand parses arguments correctly")
    func testMigrateProfileCommandArguments() throws {
        // Test basic migrate command
        let basicCommand = try MigrateProfileCommand.parse([
            "--profile", "legacy-profile",
        ])
        #expect(basicCommand.profile == "legacy-profile")
        #expect(!basicCommand.dryRun)

        // Test migrate with dry-run flag
        let dryRunCommand = try MigrateProfileCommand.parse([
            "--profile", "legacy-profile",
            "--dry-run",
        ])
        #expect(dryRunCommand.profile == "legacy-profile")
        #expect(dryRunCommand.dryRun)
    }

    @Test("ClearProfilesCommand parses force flag correctly")
    func testClearProfilesCommandFlags() throws {
        // Test default (no force)
        let defaultCommand = try ClearProfilesCommand.parse([])
        #expect(!defaultCommand.force)

        // Test with force flag
        let forceCommand = try ClearProfilesCommand.parse(["--force"])
        #expect(forceCommand.force)
    }

    @Test("ProfilesCommand subcommands have appropriate help text")
    func testProfilesCommandHelpText() throws {
        // Test store command help
        let storeConfig = StoreProfileCommand.configuration
        #expect(storeConfig.abstract.contains("Store AWS credentials"))
        #expect(storeConfig.discussion.contains("keychain encryption"))

        // Test list command help
        let listConfig = ListProfilesCommand.configuration
        #expect(listConfig.abstract.contains("List all secure profiles"))
        #expect(listConfig.discussion.contains("metadata"))

        // Test show command help
        let showConfig = ShowProfileCommand.configuration
        #expect(showConfig.abstract.contains("detailed information"))

        // Test remove command help
        let removeConfig = RemoveProfileCommand.configuration
        #expect(removeConfig.abstract.contains("Remove credentials"))
        #expect(removeConfig.discussion.contains("cannot be undone"))

        // Test migrate command help
        let migrateConfig = MigrateProfileCommand.configuration
        #expect(migrateConfig.abstract.contains("Migrate traditional credentials"))

        // Test clear command help
        let clearConfig = ClearProfilesCommand.configuration
        #expect(clearConfig.abstract.contains("Remove all Brochure data"))
        #expect(clearConfig.discussion.contains("cannot be undone"))
    }
}
