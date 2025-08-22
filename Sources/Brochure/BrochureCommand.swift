import ArgumentParser
import Foundation
import Logging

@main
struct BrochureCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "Brochure",
        abstract: "High-performance CLI tool for deploying static websites to AWS S3 with CloudFront optimization",
        discussion: """
            Brochure provides efficient static website deployment to Amazon S3 with features optimized for CloudFront distribution:

            • Intelligent change detection using MD5 hashing to skip unchanged files
            • Multipart uploads for large files with configurable chunk sizes
            • Exponential backoff retry logic for handling transient AWS failures
            • Real-time progress tracking with detailed upload statistics
            • Automatic content type detection and optimized cache headers
            • File exclusion support using glob patterns
            • Dry run mode for previewing operations without uploading
            • Secure credential management using macOS keychain integration
            • Parallel processing support for multi-site deployments

            EXAMPLES:
              # Upload NeonLaw website
              swift run Brochure upload NeonLaw

              # Upload with specific AWS profile
              swift run Brochure upload NeonLaw --profile production

              # Preview HoshiHoshi upload without actually uploading
              swift run Brochure upload HoshiHoshi --dry-run

              # Upload all sites in parallel
              swift run Brochure upload-all --all

              # Upload specific sites concurrently
              swift run Brochure upload-all --sites "NeonLaw,HoshiHoshi,TarotSwift"

              # Verify binary integrity
              swift run Brochure verify --self

              # Check version information
              swift run Brochure version --detailed

              # Upload with file exclusions and verbose output
              swift run Brochure upload HoshiHoshi --exclude "*.log,temp/**" --verbose

              # Secure credential management
              swift run Brochure profiles store --profile production --access-key AKIA... --secret-key abc...
              swift run Brochure profiles list
              swift run Brochure profiles show --profile production

            SUPPORTED SITES:
              • NeonLaw - Law firm website
              • HoshiHoshi - Application website
              • TarotSwift - Astrology reading service
              • NLF - Neon Law Foundation website
              • NVSciTech - Nevada Science & Technology Law Section
              • 1337lawyers - Elite software law firm

            OUTPUT STRUCTURE:
              Files are uploaded to: s3://sagebrush-public/Brochure/{SiteName}/
              Accessible via CloudFront at optimized URLs with automatic caching
            """,
        subcommands: [
            UploadCommand.self, UploadAllCommand.self, ProfilesCommand.self, VersionCommand.self, VerifyCommand.self,
            BootstrapCommand.self,
        ]
    )
}
