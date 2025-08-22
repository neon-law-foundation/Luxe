import Foundation

/// Validates AWS profile configurations and provides helpful error messages.
struct ProfileValidator {
    /// Validates that a profile exists and is accessible.
    ///
    /// - Parameter profileName: The profile name to validate
    /// - Throws: ProfileError if the profile is invalid or not found
    func validate(profileName: String) throws {
        let availableProfiles = try listAvailableProfiles()

        guard availableProfiles.contains(profileName) else {
            throw ProfileError.profileNotFound(
                profile: profileName,
                available: availableProfiles
            )
        }
    }

    /// Lists all available AWS profiles from credentials and config files.
    ///
    /// - Returns: Array of profile names sorted alphabetically
    /// - Throws: ProfileError if AWS configuration files cannot be read
    func listAvailableProfiles() throws -> [String] {
        var profiles = Set<String>()

        // Parse credentials file
        if let credentialsProfiles = try parseCredentialsFile() {
            profiles.formUnion(credentialsProfiles)
        }

        // Parse config file
        if let configProfiles = try parseConfigFile() {
            profiles.formUnion(configProfiles)
        }

        // If no profiles found, AWS config might not be set up
        if profiles.isEmpty {
            throw ProfileError.awsConfigNotFound
        }

        return Array(profiles).sorted()
    }

    private func parseCredentialsFile() throws -> [String]? {
        let path = expandPath("~/.aws/credentials")
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }

        let content = try String(contentsOfFile: path, encoding: .utf8)
        return parseINIProfiles(from: content)
    }

    private func parseConfigFile() throws -> [String]? {
        let path = expandPath("~/.aws/config")
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }

        let content = try String(contentsOfFile: path, encoding: .utf8)
        return parseINIProfiles(from: content, stripProfilePrefix: true)
    }

    private func parseINIProfiles(from content: String, stripProfilePrefix: Bool = false) -> [String] {
        var profiles: [String] = []

        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Look for section headers like [profile name] or [name]
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                let sectionName = String(trimmed.dropFirst().dropLast())

                if stripProfilePrefix && sectionName.hasPrefix("profile ") {
                    // Config file format: [profile production] -> "production"
                    let profileName = String(sectionName.dropFirst("profile ".count))
                    profiles.append(profileName)
                } else if !stripProfilePrefix {
                    // Credentials file format: [production] -> "production"
                    profiles.append(sectionName)
                }
            }
        }

        return profiles
    }

    private func expandPath(_ path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }
}
