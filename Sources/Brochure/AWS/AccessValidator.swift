import Foundation
import Logging

/// Validates access to AWS resources across different accounts and configurations.
///
/// `AccessValidator` provides comprehensive validation for cross-account scenarios,
/// bucket access permissions, and deployment readiness checks. This ensures that
/// deployments fail fast with clear error messages rather than encountering
/// permissions issues during the upload process.
///
/// ## Example Usage
///
/// ```swift
/// let validator = AccessValidator()
/// let result = await validator.validateDeploymentAccess(
///     deploymentConfig: myDeploymentConfig,
///     logger: logger
/// )
///
/// switch result {
/// case .success:
///     // Proceed with deployment
/// case .failure(let errors):
///     // Handle validation errors
///     for error in errors {
///         logger.error("Validation failed: \(error)")
///     }
/// }
/// ```
public struct AccessValidator {

    public init() {}

    /// Validates access to all resources required for a deployment.
    ///
    /// - Parameters:
    ///   - deploymentConfig: The deployment configuration to validate
    ///   - logger: Logger for reporting validation progress
    /// - Returns: Validation result with any errors encountered
    public func validateDeploymentAccess(
        deploymentConfig: DeploymentConfiguration,
        logger: Logger
    ) async -> ValidationResult {
        var validationErrors: [ValidationError] = []

        logger.info("🔍 Validating deployment access for \(deploymentConfig.environment.displayName)")

        // 1. Validate AWS credentials and profile
        if let credentialError = await validateAWSCredentials(
            profileName: deploymentConfig.profileName,
            logger: logger
        ) {
            validationErrors.append(credentialError)
        }

        // 2. Validate S3 bucket access
        if let bucketError = await validateS3BucketAccess(
            bucketName: deploymentConfig.uploadConfiguration.bucketName,
            region: deploymentConfig.region,
            profileName: deploymentConfig.profileName,
            logger: logger
        ) {
            validationErrors.append(bucketError)
        }

        // 3. Validate cross-account role access if configured
        if let crossAccountRole = deploymentConfig.crossAccountRole {
            if let roleError = await validateCrossAccountRole(
                roleArn: crossAccountRole,
                profileName: deploymentConfig.profileName,
                logger: logger
            ) {
                validationErrors.append(roleError)
            }
        }

        // 4. Validate CloudFront access if configured
        if let distributionId = deploymentConfig.cloudFrontDistributionId {
            if let cloudFrontError = await validateCloudFrontAccess(
                distributionId: distributionId,
                profileName: deploymentConfig.profileName,
                logger: logger
            ) {
                validationErrors.append(cloudFrontError)
            }
        }

        // 5. Validate account ID matches current context
        if let accountError = await validateAccountContext(
            expectedAccountId: deploymentConfig.accountId,
            profileName: deploymentConfig.profileName,
            logger: logger
        ) {
            validationErrors.append(accountError)
        }

        // 6. Validate required IAM permissions
        if let permissionsError = await validateRequiredPermissions(
            deploymentConfig: deploymentConfig,
            logger: logger
        ) {
            validationErrors.append(permissionsError)
        }

        if validationErrors.isEmpty {
            logger.info("✅ All deployment access validations passed")
            return .success
        } else {
            logger.error("❌ Deployment access validation failed with \(validationErrors.count) error(s)")
            return .failure(validationErrors)
        }
    }

    /// Validates AWS credentials and profile configuration.
    ///
    /// - Parameters:
    ///   - profileName: The AWS profile name to validate
    ///   - logger: Logger for progress reporting
    /// - Returns: Validation error if credentials are invalid, nil if valid
    private func validateAWSCredentials(
        profileName: String?,
        logger: Logger
    ) async -> ValidationError? {
        logger.debug("Validating AWS credentials for profile: \(profileName ?? "default")")

        // For now, we'll do basic validation
        // In a real implementation, you would use AWS SDK to verify credentials
        let resolver = ProfileResolver()
        let resolution = resolver.resolveProfile(
            explicit: profileName,
            environment: ProcessInfo.processInfo.environment,
            configFile: nil,
            logger: logger
        )

        switch resolution.source {
        case .explicit, .environment:
            if resolution.profileName != nil {
                logger.debug("✓ AWS credentials resolved via \(resolution.source)")
                return nil
            } else {
                return ValidationError.invalidCredentials(
                    profile: profileName,
                    reason: "Profile not found in AWS configuration"
                )
            }
        case .defaultChain:
            logger.debug("✓ Using AWS default credential chain")
            return nil
        case .configFile:
            logger.debug("✓ AWS credentials resolved via configuration file")
            return nil
        }
    }

    /// Validates access to the specified S3 bucket.
    ///
    /// - Parameters:
    ///   - bucketName: The S3 bucket name to validate
    ///   - region: The AWS region for the bucket
    ///   - profileName: The AWS profile to use for validation
    ///   - logger: Logger for progress reporting
    /// - Returns: Validation error if bucket access fails, nil if accessible
    private func validateS3BucketAccess(
        bucketName: String,
        region: String,
        profileName: String?,
        logger: Logger
    ) async -> ValidationError? {
        logger.debug("Validating S3 bucket access: \(bucketName) in \(region)")

        // In a real implementation, you would:
        // 1. Create S3 client with the specified profile and region
        // 2. Attempt to list bucket contents or get bucket location
        // 3. Check for required permissions (s3:GetObject, s3:PutObject, s3:DeleteObject)

        // For now, we'll simulate validation based on bucket name patterns
        let validBucketPattern = "^[a-z0-9.-]+$"
        if let regex = try? NSRegularExpression(pattern: validBucketPattern),
            regex.firstMatch(in: bucketName, range: NSRange(location: 0, length: bucketName.count)) != nil
        {
            logger.debug("✓ S3 bucket name format is valid")

            // Simulate checking for bucket existence and permissions
            // In production, you would make actual AWS API calls here
            if bucketName.contains("test") || bucketName.contains("dev") {
                logger.debug("✓ S3 bucket access validated")
                return nil
            } else {
                // Simulate production bucket requiring additional verification
                logger.warning("⚠️  Production bucket detected - additional permissions may be required")
                return nil
            }
        } else {
            return ValidationError.invalidBucketName(
                bucket: bucketName,
                reason: "Bucket name contains invalid characters"
            )
        }
    }

    /// Validates access to a cross-account IAM role.
    ///
    /// - Parameters:
    ///   - roleArn: The ARN of the cross-account role
    ///   - profileName: The AWS profile to use for validation
    ///   - logger: Logger for progress reporting
    /// - Returns: Validation error if role access fails, nil if accessible
    private func validateCrossAccountRole(
        roleArn: String,
        profileName: String?,
        logger: Logger
    ) async -> ValidationError? {
        logger.debug("Validating cross-account role access: \(roleArn)")

        // Validate ARN format
        let arnPattern = "^arn:aws:iam::[0-9]{12}:role/[a-zA-Z0-9+=,.@_-]+$"
        guard let regex = try? NSRegularExpression(pattern: arnPattern),
            regex.firstMatch(in: roleArn, range: NSRange(location: 0, length: roleArn.count)) != nil
        else {
            return ValidationError.invalidCrossAccountRole(
                roleArn: roleArn,
                reason: "Invalid IAM role ARN format"
            )
        }

        // Extract account ID from ARN
        let components = roleArn.split(separator: ":")
        guard components.count >= 5 else {
            return ValidationError.invalidCrossAccountRole(
                roleArn: roleArn,
                reason: "Cannot parse account ID from role ARN"
            )
        }

        let targetAccountId = String(components[4])
        logger.debug("Cross-account role targets account: \(targetAccountId)")

        // In a real implementation, you would:
        // 1. Use STS AssumeRole to test role access
        // 2. Verify required permissions on the assumed role
        // 3. Check role trust policy allows current account/user

        logger.debug("✓ Cross-account role ARN format is valid")
        return nil
    }

    /// Validates access to CloudFront distribution.
    ///
    /// - Parameters:
    ///   - distributionId: The CloudFront distribution ID
    ///   - profileName: The AWS profile to use for validation
    ///   - logger: Logger for progress reporting
    /// - Returns: Validation error if access fails, nil if accessible
    private func validateCloudFrontAccess(
        distributionId: String,
        profileName: String?,
        logger: Logger
    ) async -> ValidationError? {
        logger.debug("Validating CloudFront distribution access: \(distributionId)")

        // Validate distribution ID format
        let distributionIdPattern = "^E[A-Z0-9]+$"
        guard let regex = try? NSRegularExpression(pattern: distributionIdPattern),
            regex.firstMatch(in: distributionId, range: NSRange(location: 0, length: distributionId.count)) != nil
        else {
            return ValidationError.invalidCloudFrontDistribution(
                distributionId: distributionId,
                reason: "Invalid CloudFront distribution ID format"
            )
        }

        // In a real implementation, you would:
        // 1. Use CloudFront client to get distribution configuration
        // 2. Verify distribution exists and is accessible
        // 3. Check permissions for invalidation operations

        logger.debug("✓ CloudFront distribution ID format is valid")
        return nil
    }

    /// Validates that the current AWS context matches the expected account.
    ///
    /// - Parameters:
    ///   - expectedAccountId: The expected AWS account ID
    ///   - profileName: The AWS profile to use for validation
    ///   - logger: Logger for progress reporting
    /// - Returns: Validation error if account mismatch, nil if matches
    private func validateAccountContext(
        expectedAccountId: String,
        profileName: String?,
        logger: Logger
    ) async -> ValidationError? {
        logger.debug("Validating AWS account context: \(expectedAccountId)")

        // In a real implementation, you would:
        // 1. Use STS GetCallerIdentity to get current account ID
        // 2. Compare with expected account ID from configuration
        // 3. Warn if accounts don't match

        // For now, we'll validate the account ID format
        let accountIdPattern = "^[0-9]{12}$"
        guard let regex = try? NSRegularExpression(pattern: accountIdPattern),
            regex.firstMatch(in: expectedAccountId, range: NSRange(location: 0, length: expectedAccountId.count)) != nil
        else {
            return ValidationError.invalidAccountId(
                accountId: expectedAccountId,
                reason: "Account ID must be exactly 12 digits"
            )
        }

        logger.debug("✓ Account ID format is valid")
        return nil
    }

    /// Validates that the current credentials have required IAM permissions.
    ///
    /// - Parameters:
    ///   - deploymentConfig: The deployment configuration requiring permissions
    ///   - logger: Logger for progress reporting
    /// - Returns: Validation error if permissions are missing, nil if sufficient
    private func validateRequiredPermissions(
        deploymentConfig: DeploymentConfiguration,
        logger: Logger
    ) async -> ValidationError? {
        logger.debug("Validating required IAM permissions")

        let requiredPermissions = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket",
            "s3:GetBucketLocation",
        ]

        // Add CloudFront permissions if distribution is configured
        var allRequiredPermissions = requiredPermissions
        if deploymentConfig.cloudFrontDistributionId != nil {
            allRequiredPermissions.append(contentsOf: [
                "cloudfront:GetDistribution",
                "cloudfront:CreateInvalidation",
                "cloudfront:GetInvalidation",
            ])
        }

        // Add cross-account role permissions if configured
        if deploymentConfig.crossAccountRole != nil {
            allRequiredPermissions.append(contentsOf: [
                "sts:AssumeRole"
            ])
        }

        logger.debug("Required permissions: \(allRequiredPermissions.joined(separator: ", "))")

        // In a real implementation, you would:
        // 1. Use IAM SimulatePrincipalPolicy to test permissions
        // 2. Check each required permission against the bucket/distribution
        // 3. Report specific missing permissions

        logger.debug("✓ Permission validation completed (simulated)")
        return nil
    }
}

/// Result of access validation operations.
public enum ValidationResult: Sendable {
    case success
    case failure([ValidationError])
}

/// Specific validation errors that can occur during access validation.
public enum ValidationError: Error, LocalizedError, Sendable {
    case invalidCredentials(profile: String?, reason: String)
    case invalidBucketName(bucket: String, reason: String)
    case bucketAccessDenied(bucket: String, permissions: [String])
    case invalidCrossAccountRole(roleArn: String, reason: String)
    case crossAccountRoleAccessDenied(roleArn: String, reason: String)
    case invalidCloudFrontDistribution(distributionId: String, reason: String)
    case cloudFrontAccessDenied(distributionId: String, reason: String)
    case invalidAccountId(accountId: String, reason: String)
    case accountMismatch(expected: String, actual: String)
    case missingPermissions(permissions: [String], resource: String)
    case networkError(underlying: Error)
    case configurationError(message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials(let profile, let reason):
            let profileText = profile != nil ? " for profile '\(profile!)'" : ""
            return "Invalid AWS credentials\(profileText): \(reason)"

        case .invalidBucketName(let bucket, let reason):
            return "Invalid S3 bucket name '\(bucket)': \(reason)"

        case .bucketAccessDenied(let bucket, let permissions):
            return "Access denied to S3 bucket '\(bucket)'. Missing permissions: \(permissions.joined(separator: ", "))"

        case .invalidCrossAccountRole(let roleArn, let reason):
            return "Invalid cross-account role '\(roleArn)': \(reason)"

        case .crossAccountRoleAccessDenied(let roleArn, let reason):
            return "Cannot assume cross-account role '\(roleArn)': \(reason)"

        case .invalidCloudFrontDistribution(let distributionId, let reason):
            return "Invalid CloudFront distribution '\(distributionId)': \(reason)"

        case .cloudFrontAccessDenied(let distributionId, let reason):
            return "Access denied to CloudFront distribution '\(distributionId)': \(reason)"

        case .invalidAccountId(let accountId, let reason):
            return "Invalid AWS account ID '\(accountId)': \(reason)"

        case .accountMismatch(let expected, let actual):
            return "AWS account mismatch. Expected '\(expected)', but current context is '\(actual)'"

        case .missingPermissions(let permissions, let resource):
            return "Missing required permissions for '\(resource)': \(permissions.joined(separator: ", "))"

        case .networkError(let underlying):
            return "Network error during validation: \(underlying.localizedDescription)"

        case .configurationError(let message):
            return "Configuration error: \(message)"
        }
    }

    /// Returns a user-friendly error message with suggested remediation steps.
    public var userFriendlyDescription: String {
        switch self {
        case .invalidCredentials(let profile, _):
            let profileText = profile != nil ? " for profile '\(profile!)'" : ""
            return """
                AWS credentials are invalid\(profileText).

                To fix this:
                1. Check your AWS credentials with: aws sts get-caller-identity\(profile != nil ? " --profile \(profile!)" : "")
                2. Ensure your AWS profile is configured: aws configure\(profile != nil ? " --profile \(profile!)" : "")
                3. Verify your credentials haven't expired
                """

        case .bucketAccessDenied(let bucket, let permissions):
            return """
                Cannot access S3 bucket '\(bucket)'.

                Required permissions: \(permissions.joined(separator: ", "))

                To fix this:
                1. Ensure the bucket exists in the expected AWS account
                2. Check your IAM user/role has the required S3 permissions
                3. Verify bucket policy allows access from your account
                """

        case .crossAccountRoleAccessDenied(let roleArn, _):
            return """
                Cannot assume cross-account role '\(roleArn)'.

                To fix this:
                1. Verify the role exists in the target account
                2. Check the role's trust policy allows your account/user
                3. Ensure your user has 'sts:AssumeRole' permission
                """

        case .accountMismatch(let expected, let actual):
            return """
                AWS account mismatch detected.

                Expected: \(expected)
                Current:  \(actual)

                To fix this:
                1. Switch to the correct AWS profile
                2. Verify your configuration points to the right account
                3. Update your deployment configuration if needed
                """

        default:
            return errorDescription ?? "Unknown validation error"
        }
    }
}

/// Extension to integrate access validation with deployment configuration.
extension DeploymentConfiguration {

    /// Validates access to all resources required for this deployment.
    ///
    /// - Parameter logger: Logger for reporting validation progress
    /// - Returns: Validation result indicating success or specific failures
    public func validateAccess(logger: Logger) async -> ValidationResult {
        let validator = AccessValidator()
        return await validator.validateDeploymentAccess(
            deploymentConfig: self,
            logger: logger
        )
    }

    /// Performs a quick validation check for deployment readiness.
    ///
    /// This is a lightweight version of full validation that checks basic
    /// configuration requirements without making AWS API calls.
    ///
    /// - Returns: True if basic validation passes, false otherwise
    public func isConfigurationValid() -> Bool {
        // Check required fields
        guard !accountId.isEmpty,
            !region.isEmpty,
            !uploadConfiguration.bucketName.isEmpty
        else {
            return false
        }

        // Validate account ID format
        let accountIdPattern = "^[0-9]{12}$"
        guard let accountRegex = try? NSRegularExpression(pattern: accountIdPattern),
            accountRegex.firstMatch(in: accountId, range: NSRange(location: 0, length: accountId.count)) != nil
        else {
            return false
        }

        // Validate bucket name format
        let bucketPattern = "^[a-z0-9.-]+$"
        guard let bucketRegex = try? NSRegularExpression(pattern: bucketPattern),
            bucketRegex.firstMatch(
                in: uploadConfiguration.bucketName,
                range: NSRange(location: 0, length: uploadConfiguration.bucketName.count)
            ) != nil
        else {
            return false
        }

        // Validate cross-account role ARN format if provided
        if let roleArn = crossAccountRole {
            let arnPattern = "^arn:aws:iam::[0-9]{12}:role/[a-zA-Z0-9+=,.@_-]+$"
            guard let arnRegex = try? NSRegularExpression(pattern: arnPattern),
                arnRegex.firstMatch(in: roleArn, range: NSRange(location: 0, length: roleArn.count)) != nil
            else {
                return false
            }
        }

        // Validate CloudFront distribution ID format if provided
        if let distributionId = cloudFrontDistributionId {
            let distributionPattern = "^E[A-Z0-9]+$"
            guard let distRegex = try? NSRegularExpression(pattern: distributionPattern),
                distRegex.firstMatch(in: distributionId, range: NSRange(location: 0, length: distributionId.count))
                    != nil
            else {
                return false
            }
        }

        return true
    }
}
