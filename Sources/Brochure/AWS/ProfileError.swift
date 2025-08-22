import Foundation

/// Errors related to AWS profile configuration and validation.
enum ProfileError: LocalizedError {
    case profileNotFound(profile: String, available: [String])
    case missingProfileName
    case awsConfigNotFound
    case invalidCredentials(profile: String)
    case assumeRoleFailed(role: String)
    case regionNotSpecified
    case bucketAccessDenied(bucket: String, profile: String)

    var errorDescription: String? {
        switch self {
        case .profileNotFound(let profile, let available):
            let availableList =
                available.isEmpty
                ? "No profiles configured"
                : available.map { "  - \($0)" }.joined(separator: "\n")

            return """
                Profile '\(profile)' not found.

                Available profiles:
                \(availableList)

                To configure a new profile, run:
                  aws configure --profile \(profile)
                """

        case .missingProfileName:
            return "Profile name is required but was not provided"

        case .awsConfigNotFound:
            return """
                AWS configuration files not found.

                Please run 'aws configure' to set up your credentials.

                For more information:
                https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html
                """

        case .invalidCredentials(let profile):
            return """
                Invalid or expired credentials for profile '\(profile)'.

                Please verify your credentials:
                  aws sts get-caller-identity --profile \(profile)
                """

        case .assumeRoleFailed(let role):
            return "Failed to assume role: \(role)"

        case .regionNotSpecified:
            return """
                AWS region not specified.

                Specify region using one of:
                  --region flag (future enhancement)
                  AWS_REGION environment variable
                  Profile configuration in ~/.aws/config
                """

        case .bucketAccessDenied(let bucket, let profile):
            return """
                Access denied to bucket '\(bucket)' using profile '\(profile)'.

                Please verify:
                  1. The bucket exists
                  2. Your profile has s3:PutObject permissions
                  3. The bucket policy allows your account
                """
        }
    }
}
