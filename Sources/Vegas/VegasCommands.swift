import ArgumentParser
import Foundation
import SotoCloudFormation
import SotoCore
import SotoEC2
import SotoECS

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

struct Infrastructure: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "infrastructure",
        abstract: "Create AWS infrastructure using CloudFormation"
    )

    func run() async throws {
        print("🏗️ Creating AWS infrastructure...")

        let primaryRegion = Region.uswest2
        let secondaryRegion = Region.useast2

        let accessKey = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"]!
        let secretKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"]!

        let luxeCloud = LuxeCloud(accessKey: accessKey, secretKey: secretKey)

        let luxePassword = ProcessInfo.processInfo.environment["LUXE_PASSWORD"]!

        do {
            // VPCs
            try await luxeCloud.upsertStack(
                stack: VPC(),
                region: primaryRegion,
                stackParameters: ["ClassB": "111"],
                name: "oregon-vpc"
            )

            // Ohio VPC in us-east-2 for GitHub Actions runners via Hyperenv
            try await luxeCloud.upsertStack(
                stack: OhioVPC(),
                region: secondaryRegion,
                stackParameters: ["ClassB": "222"],
                name: "ohio-vpc"
            )

            try await luxeCloud.upsertStack(
                stack: PublicS3Bucket(),
                region: primaryRegion,
                stackParameters: [
                    "BucketName": "sagebrush-public"
                ],
                name: "sagebrush-public-bucket"
            )

            // CloudFront distribution for static brochure sites (legacy - keeping for fallback)
            try await luxeCloud.upsertStack(
                stack: CloudFrontDistribution(),
                region: primaryRegion,
                stackParameters: [
                    "S3BucketName": "sagebrush-public",
                    "S3OriginPath": "/Brochure",
                ],
                name: "sagebrush-brochure-cloudfront"
            )

            // Step 1: Create ACM certificates in us-east-1 for CloudFront
            print("🔐 Creating ACM certificates in us-east-1 for CloudFront...")

            // NeonLaw ACM certificate
            try await luxeCloud.upsertStack(
                stack: ACMCertificateForCloudFront(),
                region: .useast1,
                stackParameters: [
                    "CustomDomainName": "www.neonlaw.com",
                    "SiteName": "NeonLaw",
                ],
                name: "neonlaw-cloudfront-certificate"
            )

            // HoshiHoshi ACM certificate
            try await luxeCloud.upsertStack(
                stack: ACMCertificateForCloudFront(),
                region: .useast1,
                stackParameters: [
                    "CustomDomainName": "www.hoshihoshi.app",
                    "SiteName": "HoshiHoshi",
                ],
                name: "hoshihoshi-cloudfront-certificate"
            )

            // TarotSwift ACM certificate
            try await luxeCloud.upsertStack(
                stack: ACMCertificateForCloudFront(),
                region: .useast1,
                stackParameters: [
                    "CustomDomainName": "www.tarotswift.me",
                    "SiteName": "TarotSwift",
                ],
                name: "tarotswift-cloudfront-certificate"
            )

            // NeonLaw.org ACM certificate
            try await luxeCloud.upsertStack(
                stack: ACMCertificateForCloudFront(),
                region: .useast1,
                stackParameters: [
                    "CustomDomainName": "www.neonlaw.org",
                    "SiteName": "NeonLawOrg",
                ],
                name: "neonlaworg-cloudfront-certificate"
            )

            // NVSciTech ACM certificate
            try await luxeCloud.upsertStack(
                stack: ACMCertificateForCloudFront(),
                region: .useast1,
                stackParameters: [
                    "CustomDomainName": "www.nvscitech.org",
                    "SiteName": "NVSciTech",
                ],
                name: "nvscitech-cloudfront-certificate"
            )

            // 1337lawyers ACM certificate
            try await luxeCloud.upsertStack(
                stack: ACMCertificateForCloudFront(),
                region: .useast1,
                stackParameters: [
                    "CustomDomainName": "www.1337lawyers.com",
                    "SiteName": "LeetLawyers",
                ],
                name: "leetlawyers-cloudfront-certificate"
            )

            print("🔄 Waiting for ACM certificates to be created...")

            // Wait for all certificate stacks to complete
            try await luxeCloud.waitForStackCompletion(
                stackName: "neonlaw-cloudfront-certificate",
                region: .useast1
            )
            try await luxeCloud.waitForStackCompletion(
                stackName: "hoshihoshi-cloudfront-certificate",
                region: .useast1
            )
            try await luxeCloud.waitForStackCompletion(
                stackName: "tarotswift-cloudfront-certificate",
                region: .useast1
            )
            try await luxeCloud.waitForStackCompletion(
                stackName: "neonlaworg-cloudfront-certificate",
                region: .useast1
            )
            try await luxeCloud.waitForStackCompletion(
                stackName: "nvscitech-cloudfront-certificate",
                region: .useast1
            )
            try await luxeCloud.waitForStackCompletion(
                stackName: "leetlawyers-cloudfront-certificate",
                region: .useast1
            )

            // Get certificate ARNs from the completed stacks
            let neonlawCertArn = try await luxeCloud.getStackOutput(
                stackName: "neonlaw-cloudfront-certificate",
                outputKey: "ACMCertificateArn",
                region: .useast1
            )
            let hoshihoshiCertArn = try await luxeCloud.getStackOutput(
                stackName: "hoshihoshi-cloudfront-certificate",
                outputKey: "ACMCertificateArn",
                region: .useast1
            )
            let tarotswiftCertArn = try await luxeCloud.getStackOutput(
                stackName: "tarotswift-cloudfront-certificate",
                outputKey: "ACMCertificateArn",
                region: .useast1
            )
            let neonlaworgCertArn = try await luxeCloud.getStackOutput(
                stackName: "neonlaworg-cloudfront-certificate",
                outputKey: "ACMCertificateArn",
                region: .useast1
            )
            let nvscitechCertArn = try await luxeCloud.getStackOutput(
                stackName: "nvscitech-cloudfront-certificate",
                outputKey: "ACMCertificateArn",
                region: .useast1
            )
            let leetlawyersCertArn = try await luxeCloud.getStackOutput(
                stackName: "leetlawyers-cloudfront-certificate",
                outputKey: "ACMCertificateArn",
                region: .useast1
            )

            // Step 2: Create CloudFront distributions with existing certificates
            print("☁️ Creating CloudFront distributions...")

            // NeonLaw website at www.neonlaw.com
            try await luxeCloud.upsertStack(
                stack: CloudFrontDistributionWithCustomDomain(),
                region: primaryRegion,
                stackParameters: [
                    "S3BucketName": "sagebrush-public",
                    "S3OriginPath": "/Brochure/NeonLaw",
                    "CustomDomainName": "www.neonlaw.com",
                    "SiteName": "NeonLaw",
                    "ACMCertificateArn": neonlawCertArn,
                ],
                name: "neonlaw-cloudfront"
            )

            // HoshiHoshi website at www.hoshihoshi.app
            try await luxeCloud.upsertStack(
                stack: CloudFrontDistributionWithCustomDomain(),
                region: primaryRegion,
                stackParameters: [
                    "S3BucketName": "sagebrush-public",
                    "S3OriginPath": "/Brochure/HoshiHoshi",
                    "CustomDomainName": "www.hoshihoshi.app",
                    "SiteName": "HoshiHoshi",
                    "ACMCertificateArn": hoshihoshiCertArn,
                ],
                name: "hoshihoshi-cloudfront"
            )

            // TarotSwift website at www.tarotswift.me
            try await luxeCloud.upsertStack(
                stack: CloudFrontDistributionWithCustomDomain(),
                region: primaryRegion,
                stackParameters: [
                    "S3BucketName": "sagebrush-public",
                    "S3OriginPath": "/Brochure/TarotSwift",
                    "CustomDomainName": "www.tarotswift.me",
                    "SiteName": "TarotSwift",
                    "ACMCertificateArn": tarotswiftCertArn,
                ],
                name: "tarotswift-cloudfront"
            )

            // NeonLaw.org website at www.neonlaw.org
            try await luxeCloud.upsertStack(
                stack: CloudFrontDistributionWithCustomDomain(),
                region: primaryRegion,
                stackParameters: [
                    "S3BucketName": "sagebrush-public",
                    "S3OriginPath": "/Brochure/NLF",
                    "CustomDomainName": "www.neonlaw.org",
                    "SiteName": "NLF",
                    "ACMCertificateArn": neonlaworgCertArn,
                ],
                name: "neonlaworg-cloudfront"
            )

            // NVSciTech website at www.nvscitech.org
            try await luxeCloud.upsertStack(
                stack: CloudFrontDistributionWithCustomDomain(),
                region: primaryRegion,
                stackParameters: [
                    "S3BucketName": "sagebrush-public",
                    "S3OriginPath": "/Brochure/NVSciTech",
                    "CustomDomainName": "www.nvscitech.org",
                    "SiteName": "NVSciTech",
                    "ACMCertificateArn": nvscitechCertArn,
                ],
                name: "nvscitech-cloudfront"
            )

            // 1337lawyers website at www.1337lawyers.com
            try await luxeCloud.upsertStack(
                stack: CloudFrontDistributionWithCustomDomain(),
                region: primaryRegion,
                stackParameters: [
                    "S3BucketName": "sagebrush-public",
                    "S3OriginPath": "/Brochure/1337lawyers",
                    "CustomDomainName": "www.1337lawyers.com",
                    "SiteName": "LeetLawyers",
                    "ACMCertificateArn": leetlawyersCertArn,
                ],
                name: "leetlawyers-cloudfront"
            )

            // Wait for all CloudFront distributions to be created before creating bucket policy
            print("⏳ Waiting for CloudFront distributions to complete...")

            try await luxeCloud.waitForStackCompletion(
                stackName: "neonlaw-cloudfront",
                region: primaryRegion
            )
            try await luxeCloud.waitForStackCompletion(
                stackName: "hoshihoshi-cloudfront",
                region: primaryRegion
            )
            try await luxeCloud.waitForStackCompletion(
                stackName: "tarotswift-cloudfront",
                region: primaryRegion
            )
            try await luxeCloud.waitForStackCompletion(
                stackName: "neonlaworg-cloudfront",
                region: primaryRegion
            )
            try await luxeCloud.waitForStackCompletion(
                stackName: "nvscitech-cloudfront",
                region: primaryRegion
            )
            try await luxeCloud.waitForStackCompletion(
                stackName: "leetlawyers-cloudfront",
                region: primaryRegion
            )

            // Get all CloudFront distribution IDs for the centralized bucket policy
            let neonlawDistributionId = try await luxeCloud.getStackOutput(
                stackName: "neonlaw-cloudfront",
                outputKey: "DistributionId",
                region: primaryRegion
            )
            let hoshihoshiDistributionId = try await luxeCloud.getStackOutput(
                stackName: "hoshihoshi-cloudfront",
                outputKey: "DistributionId",
                region: primaryRegion
            )
            let tarotswiftDistributionId = try await luxeCloud.getStackOutput(
                stackName: "tarotswift-cloudfront",
                outputKey: "DistributionId",
                region: primaryRegion
            )
            let neonlaworgDistributionId = try await luxeCloud.getStackOutput(
                stackName: "neonlaworg-cloudfront",
                outputKey: "DistributionId",
                region: primaryRegion
            )
            let nvscitechDistributionId = try await luxeCloud.getStackOutput(
                stackName: "nvscitech-cloudfront",
                outputKey: "DistributionId",
                region: primaryRegion
            )
            let leetlawyersDistributionId = try await luxeCloud.getStackOutput(
                stackName: "leetlawyers-cloudfront",
                outputKey: "DistributionId",
                region: primaryRegion
            )

            // Get legacy brochure distribution ID if it exists
            var legacyDistributionId = ""
            do {
                legacyDistributionId = try await luxeCloud.getStackOutput(
                    stackName: "sagebrush-brochure-cloudfront",
                    outputKey: "DistributionId",
                    region: primaryRegion
                )
            } catch {
                print("ℹ️ Legacy brochure CloudFront distribution not found (this is expected)")
            }

            // Step 3: Create centralized S3 bucket policy with all CloudFront distribution IDs
            print("🔐 Creating centralized S3 bucket policy for CloudFront access...")

            try await luxeCloud.upsertStack(
                stack: S3BucketPolicyForCloudFront(),
                region: primaryRegion,
                stackParameters: [
                    "S3BucketName": "sagebrush-public",
                    "NeonLawDistributionId": neonlawDistributionId,
                    "HoshiHoshiDistributionId": hoshihoshiDistributionId,
                    "TarotSwiftDistributionId": tarotswiftDistributionId,
                    "NeonLawOrgDistributionId": neonlaworgDistributionId,
                    "NVSciTechDistributionId": nvscitechDistributionId,
                    "LeetLawyersDistributionId": leetlawyersDistributionId,
                    "LegacyBrochureDistributionId": legacyDistributionId,
                ],
                name: "sagebrush-s3-bucket-policy"
            )

            // Private S3 bucket for secure uploads and assets (VPC-only access)
            try await luxeCloud.upsertStack(
                stack: PrivateS3Bucket(),
                region: primaryRegion,
                stackParameters: [
                    "VPCStackName": "oregon-vpc"
                ],
                name: "sagebrush-private-bucket"
            )

            // SQS queue for Bazaar job processing - temporarily commented out for cost optimization
            // try await luxeCloud.upsertStack(
            //     stack: SQSEmailQueue(),
            //     region: primaryRegion,
            //     stackParameters: [
            //         "S3BucketArn": "arn:aws:s3:::sagebrush-emails"
            //     ],
            //     name: "sagebrush-email-queue"
            // )

            // Private S3 bucket for incoming emails from SES (deployed second, references SQS queue)
            // try await luxeCloud.upsertStack(
            //     stack: PrivateEmailS3Bucket(),
            //     region: primaryRegion,
            //     stackParameters: [:],
            //     name: "sagebrush-email-bucket"
            // )

            // SES email processing rules for inbound emails
            // try await luxeCloud.upsertStack(
            //     stack: SESEmailProcessing(),
            //     region: primaryRegion,
            //     stackParameters: [
            //         "S3BucketName": "sagebrush-emails"
            //     ],
            //     name: "sagebrush-email-processing"
            // )

            // RDS Database
            try await luxeCloud.upsertStack(
                stack: RDS(),
                region: primaryRegion,
                stackParameters: [
                    "VPCStackName": "oregon-vpc",
                    "DBUsername": "postgres",
                    "DBPassword": luxePassword,
                    "DBInstanceClass": "db.t3.micro",
                ],
                name: "oregon-rds"
            )

            // ElastiCache Redis cluster for Vapor Queues
            try await luxeCloud.upsertStack(
                stack: ElastiCacheRedis(),
                region: primaryRegion,
                stackParameters: [
                    "VPCStackName": "oregon-vpc",
                    "RedisPassword": luxePassword,
                ],
                name: "oregon-redis"
            )

            // Secrets Manager for Database
            try await luxeCloud.upsertStack(
                stack: SecretsManager(),
                region: primaryRegion,
                stackParameters: [
                    "RDSStackName": "oregon-rds",
                    "ElasticacheStackName": "oregon-redis",
                ],
                name: "oregon-secrets"
            )

            // Note: GitHub system account no longer needed since we use public ghcr.io images

            // Note: Doppler system account no longer needed

            // Engineering System Account with Administrator Access and EC2 KeyPair
            try await luxeCloud.upsertStack(
                stack: EngineeringSystemAccount(),
                region: primaryRegion,
                stackParameters: [:],
                name: "engineering-system-account"
            )

            // Bastion Host for secure access to VPC resources
            try await luxeCloud.upsertStack(
                stack: BastionHost(),
                region: primaryRegion,
                stackParameters: [
                    "VPCStackName": "oregon-vpc",
                    "KeyPairName": "engineering-system-keypair",
                ],
                name: "oregon-bastion"
            )

            // SSL Certificate for www.sagebrush.services (EMAIL validation)
            try await luxeCloud.upsertStack(
                stack: ACMCertificate(),
                region: primaryRegion,
                stackParameters: [
                    "DomainName": "www.sagebrush.services",
                    "ValidationMethod": "EMAIL",
                ],
                name: "bazaar-certificate"
            )

            // SSL Certificate for www.destined.travel (EMAIL validation)
            try await luxeCloud.upsertStack(
                stack: ACMCertificate(),
                region: primaryRegion,
                stackParameters: [
                    "DomainName": "www.destined.travel",
                    "ValidationMethod": "EMAIL",
                ],
                name: "destined-certificate"
            )

            // SSL Certificate for www.destined.travel (EMAIL validation)
            try await luxeCloud.upsertStack(
                stack: ACMCertificate(),
                region: primaryRegion,
                stackParameters: [
                    "DomainName": "www.destined.travel",
                    "ValidationMethod": "EMAIL",
                ],
                name: "destined-travel-certificate"
            )

            // Note: Container images are now stored in GitHub Container Registry (ghcr.io)
            // ECR repository creation is no longer needed

            // Cognito User Pool for Authentication
            try await luxeCloud.upsertStack(
                stack: CognitoUserPool(),
                region: primaryRegion,
                stackParameters: [
                    "UserPoolName": "sagebrush-user-pool",
                    "DomainPrefix": "sagebrush-auth",
                ],
                name: "sagebrush-cognito"
            )

            // Shared Application Load Balancer with Authentication
            try await luxeCloud.upsertStack(
                stack: ApplicationLoadBalancerWithAuth(),
                region: primaryRegion,
                stackParameters: [
                    "VPCStackName": "oregon-vpc",
                    "CertificateStackNames": "bazaar-certificate,destined-certificate",
                    "CognitoStackName": "sagebrush-cognito",
                ],
                name: "sagebrush-alb"
            )

            // Bazaar ECS Fargate Service
            try await luxeCloud.upsertStack(
                stack: ECSFargateService(),
                region: primaryRegion,
                stackParameters: [
                    "VPCStackName": "oregon-vpc",
                    "ALBStackName": "sagebrush-alb",
                    "CertificateStackName": "bazaar-certificate",
                    "SecretsStackName": "oregon-secrets",
                    "RedisStackName": "oregon-redis",
                    "ServiceName": "bazaar",
                    "ContainerImage": "ghcr.io/neon-law-foundation/bazaar",
                    "ImageTag": "latest",
                    "ContainerPort": "8080",
                    "HostHeader": "www.sagebrush.services",
                    "ListenerRulePriority": "300",
                    "EnableDatabase": "true",
                ],
                name: "bazaar-service"
            )

            // Destined ECS Fargate Service
            try await luxeCloud.upsertStack(
                stack: ECSFargateService(),
                region: primaryRegion,
                stackParameters: [
                    "VPCStackName": "oregon-vpc",
                    "ALBStackName": "sagebrush-alb",
                    "CertificateStackName": "destined-certificate",
                    "SecretsStackName": "oregon-secrets",
                    "RedisStackName": "oregon-redis",
                    "ServiceName": "destined",
                    "ContainerImage": "ghcr.io/neon-law-foundation/destined",
                    "ImageTag": "latest",
                    "ContainerPort": "8080",
                    "HostHeader": "www.destined.travel",
                    "ListenerRulePriority": "400",
                    "EnableDatabase": "true",
                ],
                name: "destined-service"
            )

            try await luxeCloud.client.shutdown()
            print("✅ Infrastructure creation completed successfully!")
        } catch {
            print(error)
            try await luxeCloud.client.shutdown()
            throw error
        }
    }
}

struct Deploy: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "deploy",
        abstract: "Deploy specific service versions to ECS",
        discussion: """
            Deploy a specific version/tag of a service to ECS.

            Examples:
              swift run Vegas deploy --service bazaar --version abc1234
              swift run Vegas deploy --service bazaar --version v1.2.3
              swift run Vegas deploy --service destined --version latest
            """
    )

    @Option(name: .long, help: "Service name to deploy (bazaar, destined)")
    var service: String

    @Option(name: .long, help: "Docker image tag/version to deploy")
    var version: String

    func run() async throws {
        print("🚀 Deploying \(service) version \(version)...")

        let accessKey = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"]!
        let secretKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"]!
        let luxeCloud = LuxeCloud(accessKey: accessKey, secretKey: secretKey)
        let primaryRegion = Region.uswest2

        do {
            switch service.lowercased() {
            case "bazaar":
                try await luxeCloud.upsertStack(
                    stack: ECSFargateService(),
                    region: primaryRegion,
                    stackParameters: [
                        "VPCStackName": "oregon-vpc",
                        "ALBStackName": "sagebrush-alb",
                        "CertificateStackName": "bazaar-certificate",
                        "SecretsStackName": "oregon-secrets",
                        "RedisStackName": "oregon-redis",
                        "ServiceName": "bazaar",
                        "ContainerImage": "ghcr.io/neon-law-foundation/bazaar",
                        "ImageTag": version,
                        "ContainerPort": "8080",
                        "HostHeader": "www.sagebrush.services",
                        "ListenerRulePriority": "300",
                        "EnableDatabase": "true",
                    ],
                    name: "bazaar-service"
                )
                print("✅ Bazaar deployed with version \(version)")

            case "destined":
                try await luxeCloud.upsertStack(
                    stack: ECSFargateService(),
                    region: primaryRegion,
                    stackParameters: [
                        "VPCStackName": "oregon-vpc",
                        "ALBStackName": "sagebrush-alb",
                        "CertificateStackName": "destined-certificate",
                        "SecretsStackName": "oregon-secrets",
                        "ServiceName": "destined",
                        "ContainerImage": "ghcr.io/neon-law-foundation/destined",
                        "ImageTag": version,
                        "ContainerPort": "8080",
                        "HostHeader": "www.destined.travel",
                        "ListenerRulePriority": "200",
                        "EnableDatabase": "false",
                    ],
                    name: "destined-service"
                )
                print("✅ Destined deployed with version \(version)")

            default:
                print("❌ Unknown service: \(service). Supported services: bazaar, destined")
                throw ExitCode.failure
            }

            try await luxeCloud.client.shutdown()

        } catch {
            print("❌ Deployment failed: \(error)")
            try await luxeCloud.client.shutdown()
            throw error
        }
    }
}

struct Versions: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "versions",
        abstract: "Query deployed service versions across all environments",
        discussion: """
            Check the currently deployed versions of all services.
            Shows version information from CloudFormation stack outputs.
            """
    )

    func run() async throws {
        print("📊 Checking deployed service versions...")

        let accessKey = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"]!
        let secretKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"]!
        let luxeCloud = LuxeCloud(accessKey: accessKey, secretKey: secretKey)
        let primaryRegion = Region.uswest2

        do {
            let cloudFormation = CloudFormation(client: luxeCloud.client, region: primaryRegion)

            // Define the services and their corresponding stack names
            let services = [
                ("Bazaar", "bazaar-service"),
                ("Destined", "destined-service"),
            ]

            print("\n🔍 Service Version Report")
            print(String(repeating: "=", count: 50))

            for (serviceName, stackName) in services {
                do {
                    let request = CloudFormation.DescribeStacksInput(stackName: stackName)
                    let response = try await cloudFormation.describeStacks(request)

                    if let stack = response.stacks?.first {
                        var deployedTag = "Unknown"
                        var deployedImage = "Unknown"
                        var serviceURL = "Unknown"

                        // Extract version information from stack outputs
                        if let outputs = stack.outputs {
                            for output in outputs {
                                switch output.outputKey {
                                case "DeployedImageTag":
                                    deployedTag = output.outputValue ?? "Unknown"
                                case "DeployedImage":
                                    deployedImage = output.outputValue ?? "Unknown"
                                case "ServiceURL":
                                    serviceURL = output.outputValue ?? "Unknown"
                                default:
                                    break
                                }
                            }
                        }

                        print("\n📦 \(serviceName)")
                        print("  Status: \(stack.stackStatus?.rawValue ?? "Unknown")")
                        print("  Version: \(deployedTag)")
                        print("  Image: \(deployedImage)")
                        print("  URL: \(serviceURL)")
                        print("  Last Updated: \(stack.lastUpdatedTime?.description ?? "Unknown")")

                    } else {
                        print("\n📦 \(serviceName)")
                        print("  Status: Stack not found")
                    }

                } catch {
                    print("\n📦 \(serviceName)")
                    print("  Status: Error - \(error)")
                }
            }

            print("\n" + String(repeating: "=", count: 50))
            try await luxeCloud.client.shutdown()

        } catch {
            print("❌ Failed to query versions: \(error)")
            try await luxeCloud.client.shutdown()
            throw error
        }
    }
}

struct Elephants: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "elephants",
        abstract: "Connect to production RDS PostgreSQL database through bastion host SSH tunnel",
        discussion: """
            Execute SQL queries on the production database.

            By default, lists all records in the directory.people table.

            You can pipe SQL queries to this command:
              echo "SELECT * FROM auth.users LIMIT 5" | swift run Vegas elephants
              cat query.sql | swift run Vegas elephants

            Or use the --direct-url flag to get connection details for manual psql access.
            """
    )

    @Flag(name: .long, help: "Show direct RDS connection URL for manual psql access")
    var directUrl: Bool = false

    func run() async throws {
        print("🐘 Connecting to production database...")

        // Get the connection details from environment variables
        guard let accessKey = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"] else {
            print("❌ AWS_ACCESS_KEY_ID environment variable not set")
            throw ExitCode.failure
        }

        guard let secretKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] else {
            print("❌ AWS_SECRET_ACCESS_KEY environment variable not set")
            throw ExitCode.failure
        }

        // Connect to us-west-2 region where the RDS database is running
        let primaryRegion = Region.uswest2
        let luxeCloud = LuxeCloud(accessKey: accessKey, secretKey: secretKey)

        do {
            let cloudFormation = CloudFormation(client: luxeCloud.client, region: primaryRegion)

            // Get the RDS connection details from CloudFormation stack outputs
            let rdsStackRequest = CloudFormation.DescribeStacksInput(stackName: "oregon-rds")
            let rdsResponse = try await cloudFormation.describeStacks(rdsStackRequest)

            guard let rdsStack = rdsResponse.stacks?.first,
                let rdsOutputs = rdsStack.outputs,
                let endpointOutput = rdsOutputs.first(where: { $0.outputKey == "DatabaseEndpoint" }),
                let rdsEndpoint = endpointOutput.outputValue,
                let passwordOutput = rdsOutputs.first(where: { $0.outputKey == "DBPassword" }),
                let dbPassword = passwordOutput.outputValue,
                let databaseOutput = rdsOutputs.first(where: { $0.outputKey == "DatabaseName" }),
                let databaseName = databaseOutput.outputValue
            else {
                print(
                    "❌ Could not find oregon-rds stack or required outputs (DatabaseEndpoint, DBPassword, DatabaseName)"
                )
                print("💡 Make sure the RDS infrastructure exists in us-west-2")
                throw ExitCode.failure
            }

            // If user wants direct URL, show it and exit
            if directUrl {
                try await showDirectRDSUrl(cloudFormation: cloudFormation, dbPassword: dbPassword)
                try await luxeCloud.client.shutdown()
                return
            }

            // Get the bastion host instance ID and public IP from AWS
            let bastionStackRequest = CloudFormation.DescribeStacksInput(stackName: "oregon-bastion")
            let bastionResponse = try await cloudFormation.describeStacks(bastionStackRequest)

            guard let bastionStack = bastionResponse.stacks?.first,
                let bastionOutputs = bastionStack.outputs,
                let instanceOutput = bastionOutputs.first(where: { $0.outputKey == "BastionInstanceId" }),
                let bastionInstanceId = instanceOutput.outputValue
            else {
                print("❌ Could not find oregon-bastion stack or BastionInstanceId output")
                print("💡 Make sure the bastion host infrastructure exists in us-west-2")
                throw ExitCode.failure
            }

            // Get bastion public IP
            let ec2 = EC2(client: luxeCloud.client, region: primaryRegion)
            let describeRequest = EC2.DescribeInstancesRequest(
                instanceIds: [bastionInstanceId]
            )
            let instanceResponse = try await ec2.describeInstances(describeRequest)

            guard let reservation = instanceResponse.reservations?.first,
                let instance = reservation.instances?.first,
                let publicIp = instance.publicIpAddress
            else {
                print("❌ Could not find bastion host public IP")
                throw ExitCode.failure
            }

            print("📍 Connecting to database: \(databaseName)")
            print("")

            // Use Session Manager tunnel for secure access
            let localPort = 15432  // Use a different port to avoid conflicts with local PostgreSQL

            // Establish tunnel for queries
            let sshTunnelProcess = try await establishSSHTunnel(
                bastionPublicIp: publicIp,
                bastionInstanceId: bastionInstanceId,
                rdsEndpoint: rdsEndpoint,
                localPort: localPort,
                remotePort: 5432
            )

            defer {
                sshTunnelProcess.terminate()
                sshTunnelProcess.waitUntilExit()
            }

            // Wait for tunnel to establish
            try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

            do {
                print("✅ Connected to production database")

                // Check if there's input from stdin (piped SQL)
                let sqlQuery: String
                let isInputPiped = isatty(STDIN_FILENO) == 0

                if isInputPiped {
                    // Read all available data from stdin
                    let stdinData = FileHandle.standardInput.readDataToEndOfFile()
                    if let pipedSQL = String(data: stdinData, encoding: .utf8)?.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ), !pipedSQL.isEmpty {
                        sqlQuery = pipedSQL
                        print("\n📝 Executing piped SQL query...")
                    } else {
                        sqlQuery = "SELECT * FROM directory.people ORDER BY name;"
                        print("\n📋 Listing all records in directory.people...")
                    }
                } else {
                    // Default query: list all directory.people records
                    sqlQuery = "SELECT * FROM directory.people ORDER BY name;"
                    print("\n📋 Listing all records in directory.people...")
                }

                // Execute the SQL query
                let psqlProcess = Process()
                psqlProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                psqlProcess.arguments = [
                    "psql",
                    "-h", "127.0.0.1",
                    "-p", String(localPort),
                    "-U", "postgres",
                    "-d", databaseName,
                    "-c", sqlQuery,
                ]

                // Set the password through environment variable
                var environment = ProcessInfo.processInfo.environment
                environment["PGPASSWORD"] = dbPassword
                psqlProcess.environment = environment

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                psqlProcess.standardOutput = outputPipe
                psqlProcess.standardError = errorPipe

                try psqlProcess.run()
                psqlProcess.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                if let output = String(data: outputData, encoding: .utf8), !output.isEmpty {
                    print(output)
                }

                if let error = String(data: errorData, encoding: .utf8), !error.isEmpty {
                    print("\n⚠️ Errors/warnings:")
                    print(error)
                }

                // If query failed, show exit code
                if psqlProcess.terminationStatus != 0 {
                    print("\n❌ Query failed with exit code: \(psqlProcess.terminationStatus)")
                }
            } catch {
                print("❌ Failed to connect to PostgreSQL: \(error)")
                print("💡 Make sure:")
                print("   - SSH tunnel is established")
                print("   - RDS instance is running")
                print("   - Security groups allow connection from bastion to RDS")
                print("   - Database credentials are correct")
            }

            try await luxeCloud.client.shutdown()

        } catch {
            print("❌ Error: \(error)")
            try await luxeCloud.client.shutdown()
            throw error
        }
    }

    /// Establishes a tunnel to the RDS instance through the bastion host using AWS Session Manager
    private func establishSSHTunnel(
        bastionPublicIp: String,
        bastionInstanceId: String,
        rdsEndpoint: String,
        localPort: Int,
        remotePort: Int
    ) async throws -> Process {
        print("🔒 Establishing secure tunnel...")

        // Use AWS Session Manager for port forwarding
        let ssmProcess = Process()
        ssmProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        ssmProcess.arguments = [
            "aws", "ssm", "start-session",
            "--target", bastionInstanceId,
            "--document-name", "AWS-StartPortForwardingSessionToRemoteHost",
            "--parameters", "host=\"\(rdsEndpoint)\",portNumber=\"\(remotePort)\",localPortNumber=\"\(localPort)\"",
            "--region", "us-west-2",
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        ssmProcess.standardOutput = outputPipe
        ssmProcess.standardError = errorPipe

        do {
            try ssmProcess.run()

            // Wait for tunnel to establish
            try await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds

            if ssmProcess.isRunning {
                return ssmProcess
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                print("❌ Session Manager tunnel failed: \(errorString)")
                print("💡 Make sure:")
                print("   - AWS CLI is installed and configured")
                print("   - Session Manager plugin is installed")
                print("   - Your AWS credentials have SSM permissions")
                print("   - The bastion instance has SSM agent running")
                throw ExitCode.failure
            }
        } catch {
            print("❌ Failed to establish tunnel: \(error)")
            throw error
        }
    }

    /// Shows the direct RDS connection URL for use with psql or other clients
    private func showDirectRDSUrl(cloudFormation: CloudFormation, dbPassword: String) async throws {
        print("🔍 Fetching RDS connection details from CloudFormation...")

        // Get the RDS endpoint from CloudFormation stack outputs
        let rdsStackRequest = CloudFormation.DescribeStacksInput(stackName: "oregon-rds")
        let rdsResponse = try await cloudFormation.describeStacks(rdsStackRequest)

        guard let rdsStack = rdsResponse.stacks?.first,
            let rdsOutputs = rdsStack.outputs,
            let endpointOutput = rdsOutputs.first(where: { $0.outputKey == "DatabaseEndpoint" }),
            let rdsEndpoint = endpointOutput.outputValue
        else {
            print("❌ Could not find oregon-rds stack or DatabaseEndpoint output")
            throw ExitCode.failure
        }

        print("\n📍 RDS Database Details:")
        print("🌐 Endpoint: \(rdsEndpoint)")
        print("🔢 Port: 5432")
        print("🗃️ Database: luxe")
        print("👤 Username: postgres")
        print("")

        print("🔗 Direct PostgreSQL URL:")
        print("postgresql://postgres:****@\(rdsEndpoint):5432/luxe?sslmode=require")
        print("")

        print("💡 To connect with psql (requires VPC access or VPN):")
        print("psql 'postgresql://postgres:\(dbPassword)@\(rdsEndpoint):5432/luxe?sslmode=require'")
        print("")

        print("🔧 To see table structure with psql:")
        print("psql 'postgresql://postgres:\(dbPassword)@\(rdsEndpoint):5432/luxe?sslmode=require' -c '\\dt+ *.*'")
        print("")

        print("⚠️  Note: Direct connection requires network access to the VPC where RDS is running.")
        print("   If you can't connect directly, use the tunnel mode without --direct-url flag.")
    }
}

struct CheckUser: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check-user",
        abstract: "Check if a user exists in the auth.users table"
    )

    @Argument(help: "The email address or user ID to check")
    var userIdentifier: String

    func run() async throws {
        print("🔍 Checking for user: \(userIdentifier)")
        print("📍 Region: us-west-2 (Oregon)")

        // Get the connection details from environment variables
        guard let accessKey = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"] else {
            print("❌ AWS_ACCESS_KEY_ID environment variable not set")
            throw ExitCode.failure
        }

        guard let secretKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] else {
            print("❌ AWS_SECRET_ACCESS_KEY environment variable not set")
            throw ExitCode.failure
        }

        guard let luxePassword = ProcessInfo.processInfo.environment["LUXE_PASSWORD"] else {
            print("❌ LUXE_PASSWORD environment variable not set")
            throw ExitCode.failure
        }

        // Connect to us-west-2 region where the RDS database is running
        let primaryRegion = Region.uswest2
        let luxeCloud = LuxeCloud(accessKey: accessKey, secretKey: secretKey)

        do {
            let cloudFormation = CloudFormation(client: luxeCloud.client, region: primaryRegion)

            // Get the RDS endpoint from CloudFormation stack outputs
            let rdsStackRequest = CloudFormation.DescribeStacksInput(stackName: "oregon-rds")
            let rdsResponse = try await cloudFormation.describeStacks(rdsStackRequest)

            guard let rdsStack = rdsResponse.stacks?.first,
                let rdsOutputs = rdsStack.outputs,
                let endpointOutput = rdsOutputs.first(where: { $0.outputKey == "DatabaseEndpoint" }),
                let rdsEndpoint = endpointOutput.outputValue
            else {
                print("❌ Could not find oregon-rds stack or DatabaseEndpoint output")
                print("💡 Make sure the RDS infrastructure exists in us-west-2")
                throw ExitCode.failure
            }

            // Get the bastion host instance ID from CloudFormation stack outputs
            let bastionStackRequest = CloudFormation.DescribeStacksInput(stackName: "oregon-bastion")
            let bastionResponse = try await cloudFormation.describeStacks(bastionStackRequest)

            guard let bastionStack = bastionResponse.stacks?.first,
                let bastionOutputs = bastionStack.outputs,
                let instanceOutput = bastionOutputs.first(where: { $0.outputKey == "BastionInstanceId" }),
                let bastionInstanceId = instanceOutput.outputValue
            else {
                print("❌ Could not find oregon-bastion stack or BastionInstanceId output")
                print("💡 Make sure the bastion host infrastructure exists in us-west-2")
                throw ExitCode.failure
            }

            print("📍 RDS Endpoint: \(rdsEndpoint)")
            print("🖥️ Bastion Instance: \(bastionInstanceId)")
            print("")

            // Create tunnel configuration
            let localPort = 15432
            let tunnelConfig = TunnelConfiguration(
                bastionInstanceId: bastionInstanceId,
                rdsEndpoint: rdsEndpoint,
                localPort: localPort,
                remotePort: 5432
            )

            // Create connection manager
            let connectionManager = PostgresConnectionManager(
                tunnelConfiguration: tunnelConfig,
                username: "postgres",
                password: luxePassword,
                database: "luxe"
            )

            // Establish connection
            do {
                try await connectionManager.connect()
                print("✅ Successfully connected to PostgreSQL through tunnel!")

                // Test the connection
                let isHealthy = try await connectionManager.testConnection()
                print("🔍 Connection test: \(isHealthy ? "✅ Healthy" : "❌ Failed")")

                if isHealthy {
                    print("\n📊 Checking auth.users table for user...")

                    // First check if user exists by email
                    let userExistsQuery: String
                    if userIdentifier.contains("@") {
                        // It's an email address
                        userExistsQuery = "SELECT COUNT(*) FROM auth.users WHERE email = '\(userIdentifier)'"
                    } else {
                        // It might be a user ID
                        userExistsQuery =
                            "SELECT COUNT(*) FROM auth.users WHERE id::text = '\(userIdentifier)' OR email = '\(userIdentifier)'"
                    }

                    let userExistsResult = try await connectionManager.executeQuery(userExistsQuery)
                    print("\n🔍 User exists check:")
                    print(userExistsResult)

                    // If user exists, get their email
                    let emailQuery: String
                    if userIdentifier.contains("@") {
                        emailQuery = "SELECT email FROM auth.users WHERE email = '\(userIdentifier)'"
                    } else {
                        emailQuery =
                            "SELECT email FROM auth.users WHERE id::text = '\(userIdentifier)' OR email = '\(userIdentifier)'"
                    }

                    let emailResult = try await connectionManager.executeQuery(emailQuery)
                    print("\n📧 User email:")
                    print(emailResult)

                    // Check email confirmation status
                    let confirmationQuery: String
                    if userIdentifier.contains("@") {
                        confirmationQuery = """
                            SELECT
                                CASE
                                    WHEN email_confirmed_at IS NOT NULL THEN 'confirmed'
                                    ELSE 'unconfirmed'
                                END
                            FROM auth.users WHERE email = '\(userIdentifier)'
                            """
                    } else {
                        confirmationQuery = """
                            SELECT
                                CASE
                                    WHEN email_confirmed_at IS NOT NULL THEN 'confirmed'
                                    ELSE 'unconfirmed'
                                END
                            FROM auth.users WHERE id::text = '\(userIdentifier)' OR email = '\(userIdentifier)'
                            """
                    }

                    let confirmationResult = try await connectionManager.executeQuery(confirmationQuery)
                    print("\n✅ Email confirmation status:")
                    print(confirmationResult)

                    // Get user ID
                    let idQuery: String
                    if userIdentifier.contains("@") {
                        idQuery = "SELECT id FROM auth.users WHERE email = '\(userIdentifier)'"
                    } else {
                        idQuery =
                            "SELECT id FROM auth.users WHERE id::text = '\(userIdentifier)' OR email = '\(userIdentifier)'"
                    }

                    let idResult = try await connectionManager.executeQuery(idQuery)
                    print("\n🆔 User ID:")
                    print(idResult)

                    // Also check overall table statistics
                    let totalUsersResult = try await connectionManager.executeQuery("SELECT COUNT(*) FROM auth.users")
                    print("\n📊 Total users in auth.users table:")
                    print(totalUsersResult)

                    // Check confirmed users
                    let confirmedUsersResult = try await connectionManager.executeQuery(
                        "SELECT COUNT(*) FROM auth.users WHERE email_confirmed_at IS NOT NULL"
                    )
                    print("\n✅ Confirmed users:")
                    print(confirmedUsersResult)

                    // Check for identity providers
                    let identitiesCountQuery: String
                    if userIdentifier.contains("@") {
                        identitiesCountQuery = """
                            SELECT COUNT(*) FROM auth.identities
                            WHERE user_id IN (SELECT id FROM auth.users WHERE email = '\(userIdentifier)')
                            """
                    } else {
                        identitiesCountQuery = """
                            SELECT COUNT(*) FROM auth.identities
                            WHERE user_id IN (SELECT id FROM auth.users WHERE id::text = '\(userIdentifier)' OR email = '\(userIdentifier)')
                            """
                    }

                    let identitiesCountResult = try await connectionManager.executeQuery(identitiesCountQuery)
                    print("\n🔗 Identity providers count for user:")
                    print(identitiesCountResult)
                }

                // Clean up
                await connectionManager.disconnect()

            } catch TunnelError.tunnelEstablishmentFailed(let message) {
                print("❌ Failed to establish tunnel: \(message)")
                print("💡 Make sure:")
                print("   - AWS CLI is installed and configured")
                print("   - Session Manager plugin is installed")
                print("   - Your AWS credentials have SSM permissions")
                print("   - The bastion instance is running and has SSM agent")
            } catch TunnelError.connectionFailed(let message) {
                print("❌ Failed to connect to PostgreSQL: \(message)")
                print("💡 Make sure:")
                print("   - RDS instance is running")
                print("   - Security groups allow connection from bastion to RDS")
                print("   - Database credentials are correct")
            } catch {
                print("❌ Unexpected error: \(error)")
            }

            try await luxeCloud.client.shutdown()

        } catch {
            print("❌ Error: \(error)")
            try await luxeCloud.client.shutdown()
            throw error
        }
    }
}

struct Refresh: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "refresh",
        abstract: "Update all ECS services with the latest Docker images"
    )

    func run() async throws {
        print("🔄 Refreshing ECS services with latest Docker images...")

        let primaryRegion = Region.uswest2

        guard let accessKey = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"] else {
            print("❌ AWS_ACCESS_KEY_ID environment variable not set")
            throw ExitCode.failure
        }

        guard let secretKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"] else {
            print("❌ AWS_SECRET_ACCESS_KEY environment variable not set")
            throw ExitCode.failure
        }

        let luxeCloud = LuxeCloud(accessKey: accessKey, secretKey: secretKey)

        do {
            let ecs = ECS(client: luxeCloud.client, region: primaryRegion)

            // Services to refresh - based on existing infrastructure
            let servicesToRefresh = [
                ServiceConfig(
                    name: "bazaar",
                    clusterName: "bazaar-cluster",
                    imageRepository: "ghcr.io/neon-law-foundation/bazaar"
                ),
                ServiceConfig(
                    name: "destined",
                    clusterName: "destined-cluster",
                    imageRepository: "ghcr.io/neon-law-foundation/destined"
                ),
            ]

            print("📋 Services to refresh: \(servicesToRefresh.map { $0.name }.joined(separator: ", "))")

            for serviceConfig in servicesToRefresh {
                print("\n🔄 Refreshing service: \(serviceConfig.name)")

                // Step 1: Get the current task definition
                let describeServicesRequest = ECS.DescribeServicesRequest(
                    cluster: serviceConfig.clusterName,
                    services: [serviceConfig.name]
                )

                let describeResponse = try await ecs.describeServices(describeServicesRequest)

                guard let service = describeResponse.services?.first else {
                    print("⚠️ Service \(serviceConfig.name) not found in cluster \(serviceConfig.clusterName)")
                    continue
                }

                guard let taskDefinitionArn = service.taskDefinition else {
                    print("⚠️ No task definition found for service \(serviceConfig.name)")
                    continue
                }

                print("📋 Current task definition: \(taskDefinitionArn)")

                // Step 2: Get the task definition details
                let describeTaskDefRequest = ECS.DescribeTaskDefinitionRequest(
                    taskDefinition: taskDefinitionArn
                )

                let taskDefResponse = try await ecs.describeTaskDefinition(describeTaskDefRequest)

                guard let taskDefinition = taskDefResponse.taskDefinition else {
                    print("⚠️ Could not retrieve task definition details for \(serviceConfig.name)")
                    continue
                }

                guard let containerDefinitions = taskDefinition.containerDefinitions else {
                    print("⚠️ No container definitions found in task definition for \(serviceConfig.name)")
                    continue
                }

                // Step 3: Update container definitions with latest images
                let updatedContainerDefinitions = containerDefinitions.map { containerDef in
                    if let currentImage = containerDef.image,
                        currentImage.contains(serviceConfig.imageRepository)
                    {
                        // Update to latest tag
                        let newImage = "\(serviceConfig.imageRepository):latest"
                        print("📦 Updating container image from \(currentImage) to \(newImage)")

                        // Create new container definition with updated image
                        return ECS.ContainerDefinition(
                            cpu: containerDef.cpu,
                            environment: containerDef.environment,
                            essential: containerDef.essential,
                            healthCheck: containerDef.healthCheck,
                            image: newImage,
                            logConfiguration: containerDef.logConfiguration,
                            memory: containerDef.memory,
                            memoryReservation: containerDef.memoryReservation,
                            name: containerDef.name,
                            portMappings: containerDef.portMappings,
                            secrets: containerDef.secrets
                        )
                    }
                    return containerDef
                }

                // Step 4: Register new task definition
                let registerRequest = ECS.RegisterTaskDefinitionRequest(
                    containerDefinitions: updatedContainerDefinitions,
                    cpu: taskDefinition.cpu,
                    executionRoleArn: taskDefinition.executionRoleArn,
                    family: taskDefinition.family ?? "unknown",
                    memory: taskDefinition.memory,
                    networkMode: taskDefinition.networkMode,
                    requiresCompatibilities: taskDefinition.requiresCompatibilities,
                    taskRoleArn: taskDefinition.taskRoleArn
                )

                let registerResponse = try await ecs.registerTaskDefinition(registerRequest)

                guard let newTaskDefinitionArn = registerResponse.taskDefinition?.taskDefinitionArn else {
                    print("⚠️ Failed to register new task definition for \(serviceConfig.name)")
                    continue
                }

                print("✅ New task definition registered: \(newTaskDefinitionArn)")

                // Step 5: Update the service to use the new task definition
                let updateServiceRequest = ECS.UpdateServiceRequest(
                    cluster: serviceConfig.clusterName,
                    service: serviceConfig.name,
                    taskDefinition: newTaskDefinitionArn
                )

                let updateResponse = try await ecs.updateService(updateServiceRequest)

                if let updatedService = updateResponse.service {
                    print("✅ Service \(serviceConfig.name) updated successfully")
                    print("📋 New task definition: \(updatedService.taskDefinition ?? "unknown")")
                } else {
                    print("⚠️ Service update response did not contain service details")
                }

                // Step 6: Wait for deployment to complete
                print("⏳ Waiting for service deployment to complete...")
                try await waitForServiceDeployment(
                    serviceName: serviceConfig.name,
                    clusterName: serviceConfig.clusterName,
                    ecs: ecs,
                    timeout: 300  // 5 minutes
                )
            }

            try await luxeCloud.client.shutdown()
            print("\n🎉 All ECS services refreshed successfully!")

        } catch {
            print("❌ Error refreshing ECS services: \(error)")
            try await luxeCloud.client.shutdown()
            throw error
        }
    }

    private func waitForServiceDeployment(
        serviceName: String,
        clusterName: String,
        ecs: ECS,
        timeout: TimeInterval
    ) async throws {
        let startTime = Date()
        let checkInterval: TimeInterval = 10  // Check every 10 seconds

        while Date().timeIntervalSince(startTime) < timeout {
            let describeRequest = ECS.DescribeServicesRequest(
                cluster: clusterName,
                services: [serviceName]
            )

            let response = try await ecs.describeServices(describeRequest)

            guard let service = response.services?.first else {
                throw VegasError.serviceNotFound(serviceName)
            }

            let deployments = service.deployments ?? []
            let runningDeployments = deployments.filter { $0.status == "RUNNING" }

            if runningDeployments.count <= 1 {
                // Only one deployment running means update is complete
                if let deployment = runningDeployments.first {
                    let runningCount = deployment.runningCount ?? 0
                    let desiredCount = deployment.desiredCount ?? 0

                    if runningCount == desiredCount && desiredCount > 0 {
                        print("✅ Service \(serviceName) deployment completed successfully")
                        return
                    }
                }
            }

            print("⏳ Deployment in progress for \(serviceName)...")
            try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
        }

        print("⚠️ Timeout: Service \(serviceName) deployment did not complete within \(Int(timeout)) seconds")
        print("💡 The deployment may still be in progress. Check AWS console for details.")
    }
}

private struct ServiceConfig {
    let name: String
    let clusterName: String
    let imageRepository: String
}

struct SESSetup: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ses-setup",
        abstract: "Set up AWS SES for newsletter sending and display required DNS records"
    )

    func run() async throws {
        print("📧 Setting up AWS SES for newsletter sending...")

        let primaryRegion = Region.uswest2
        let accessKey = ProcessInfo.processInfo.environment["AWS_ACCESS_KEY_ID"]!
        let secretKey = ProcessInfo.processInfo.environment["AWS_SECRET_ACCESS_KEY"]!

        let luxeCloud = LuxeCloud(accessKey: accessKey, secretKey: secretKey)

        do {
            // Deploy SES newsletter sending stack
            print("🚀 Deploying SES Newsletter Sending stack...")
            try await luxeCloud.upsertStack(
                stack: SESNewsletterSending(),
                region: primaryRegion,
                stackParameters: [:],
                name: "ses-newsletter-sending"
            )

            print("✅ SES Newsletter Sending stack deployed successfully!")

            // Wait for stack deployment to complete
            try await luxeCloud.waitForStackCompletion(
                stackName: "ses-newsletter-sending",
                region: primaryRegion
            )

            // Get DNS records that need to be set in Cloudflare
            print("\n📋 Getting DNS records for Cloudflare configuration...")

            let cloudFormation = CloudFormation(client: luxeCloud.client, region: primaryRegion)

            let describeRequest = CloudFormation.DescribeStacksInput(stackName: "ses-newsletter-sending")
            let response = try await cloudFormation.describeStacks(describeRequest)

            guard let stack = response.stacks?.first,
                let outputs = stack.outputs
            else {
                throw VegasError.stackOutputsNotFound("ses-newsletter-sending")
            }

            print("\n🔧 DNS Records to Add in Cloudflare:")
            print(String(repeating: "=", count: 60))

            var sagebrushNames: [String] = []
            var sagebrushValues: [String] = []
            var nvsciNames: [String] = []
            var nvsciValues: [String] = []
            var neonlawNames: [String] = []
            var neonlawValues: [String] = []

            for output in outputs {
                guard let key = output.outputKey, let value = output.outputValue else { continue }

                switch key {
                case "SagebrushDKIMTokenNames":
                    sagebrushNames = value.components(separatedBy: ",")
                case "SagebrushDKIMTokens":
                    sagebrushValues = value.components(separatedBy: ",")
                case "NVSciTechDKIMTokenNames":
                    nvsciNames = value.components(separatedBy: ",")
                case "NVSciTechDKIMTokens":
                    nvsciValues = value.components(separatedBy: ",")
                case "NeonLawDKIMTokenNames":
                    neonlawNames = value.components(separatedBy: ",")
                case "NeonLawDKIMTokens":
                    neonlawValues = value.components(separatedBy: ",")
                default:
                    continue
                }
            }

            // Display DKIM records for each domain
            if !sagebrushNames.isEmpty && !sagebrushValues.isEmpty {
                print("\nFor domain: sagebrush.services")
                print("DKIM CNAME Records:")
                for i in 0..<min(sagebrushNames.count, sagebrushValues.count) {
                    print("  Name: \(sagebrushNames[i])")
                    print("  Value: \(sagebrushValues[i])")
                    print("  Type: CNAME")
                    print("")
                }
            }

            if !nvsciNames.isEmpty && !nvsciValues.isEmpty {
                print("For domain: nvscitech.org")
                print("DKIM CNAME Records:")
                for i in 0..<min(nvsciNames.count, nvsciValues.count) {
                    print("  Name: \(nvsciNames[i])")
                    print("  Value: \(nvsciValues[i])")
                    print("  Type: CNAME")
                    print("")
                }
            }

            if !neonlawNames.isEmpty && !neonlawValues.isEmpty {
                print("For domain: neonlaw.com")
                print("DKIM CNAME Records:")
                for i in 0..<min(neonlawNames.count, neonlawValues.count) {
                    print("  Name: \(neonlawNames[i])")
                    print("  Value: \(neonlawValues[i])")
                    print("  Type: CNAME")
                    print("")
                }
            }

            print("\n📝 Additional DNS Records (add these for all domains):")
            print("SPF Record (TXT):")
            print("  Name: @ (root domain)")
            print("  Value: v=spf1 include:amazonses.com ~all")
            print("  Type: TXT")
            print("")

            print("DMARC Record (TXT) - Optional but recommended:")
            print("  Name: _dmarc")
            print("  Value: v=DMARC1; p=quarantine; rua=mailto:admin@neonlaw.com")
            print("  Type: TXT")
            print("")

            print("🎯 Next Steps:")
            print("1. Add the DKIM CNAME records above to Cloudflare DNS")
            print("2. Add the SPF TXT record to each domain")
            print("3. Optionally add the DMARC record for better deliverability")
            print("4. Wait 24-48 hours for DNS propagation")
            print("5. Verify domain identities in AWS SES console")
            print("6. Request production sending limits in AWS SES")

            // Also show AWS CLI commands for verification
            print("\n🔍 AWS CLI Commands to verify setup:")
            print(
                "aws ses get-identity-verification-attributes --region us-west-2 --identities sagebrush.services nvscitech.org neonlaw.com"
            )
            print(
                "aws ses get-identity-dkim-attributes --region us-west-2 --identities sagebrush.services nvscitech.org neonlaw.com"
            )
            print("aws ses describe-active-receipt-rule-set --region us-west-2")

        } catch {
            print("❌ Error setting up SES: \(error)")
            try await luxeCloud.client.shutdown()
            throw error
        }

        try await luxeCloud.client.shutdown()
    }
}

private enum VegasError: Error {
    case serviceNotFound(String)
    case stackOutputsNotFound(String)
}
