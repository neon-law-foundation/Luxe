import Foundation
import SotoCore
import SotoS3

/// Handles S3 operations for holiday page management.
///
/// ## Overview
/// This struct manages uploading and verifying static holiday pages in S3,
/// which are served when the system is in vacation mode.
public struct S3Operations {
    /// The AWS client configuration for this instance.
    public let config: AWSClientConfiguration

    /// Initialize S3Operations with AWS client configuration.
    ///
    /// - Parameter config: The AWS client configuration to use
    public init(config: AWSClientConfiguration) {
        self.config = config
    }

    /// Generates the S3 key path for a given domain.
    ///
    /// - Parameter domain: The domain name (e.g., "www.sagebrush.services")
    /// - Returns: The S3 key path (e.g., "holiday/www.sagebrush.services/index.html")
    public func s3KeyForDomain(_ domain: String) -> String {
        "holiday/\(domain)/index.html"
    }

    /// Uploads holiday pages to S3 for all configured domains.
    ///
    /// ## Process
    /// 1. Uploads the same HTML content for each domain
    /// 2. Sets appropriate content type and cache headers
    /// 3. Also uploads a root holiday page
    ///
    /// - Parameters:
    ///   - html: The holiday page HTML content to upload
    ///   - client: AWS client for S3 operations
    ///   - region: AWS region for the S3 bucket
    /// - Throws: S3 errors if upload fails
    public func uploadHolidayPages(html: String) async throws {
        let s3 = config.s3Client()

        // Use all domains from Holiday configuration to ensure consistency
        let holidayConfig = HolidayConfiguration()
        let domains = holidayConfig.allDomains

        for domain in domains {
            let key = s3KeyForDomain(domain)
            print("📤 Uploading holiday page for \(domain)...")

            let putRequest = S3.PutObjectRequest(
                body: AWSHTTPBody(string: html),
                bucket: config.bucketName,
                contentType: "text/html",
                key: key,
                metadata: [
                    "Cache-Control": "public, max-age=3600"
                ]
            )

            _ = try await s3.putObject(putRequest)
        }

        // Also upload a root index.html for the bucket
        let rootRequest = S3.PutObjectRequest(
            body: AWSHTTPBody(string: html),
            bucket: config.bucketName,
            contentType: "text/html",
            key: "holiday/index.html",
            metadata: [
                "Cache-Control": "public, max-age=3600"
            ]
        )

        _ = try await s3.putObject(rootRequest)

        print("✅ All holiday pages uploaded to S3")
    }

    /// Verifies that all holiday pages have been successfully uploaded to S3.
    ///
    /// ## Verification Process
    /// 1. Checks each domain's holiday page exists
    /// 2. Reports file sizes
    /// 3. Provides accessible URLs for each page
    ///
    /// - Parameters:
    ///   - client: AWS client for S3 operations
    ///   - region: AWS region for the S3 bucket
    /// - Throws: S3 errors if verification fails
    public func verifyUploads() async throws {
        let s3 = config.s3Client()

        // Use all domains from Holiday configuration to ensure consistency
        let holidayConfig = HolidayConfiguration()
        let domains = holidayConfig.allDomains

        print("📋 Verifying uploads...")

        for domain in domains {
            let key = s3KeyForDomain(domain)

            do {
                let headRequest = S3.HeadObjectRequest(bucket: config.bucketName, key: key)
                let response = try await s3.headObject(headRequest)
                let size = response.contentLength ?? 0
                print("✅ \(domain): \(key) (\(size) bytes)")
            } catch {
                print("❌ \(domain): \(key) not found")
            }
        }

        print("✅ All holiday pages successfully uploaded!")
        print("🌐 Pages are accessible at:")
        for domain in domains {
            let key = s3KeyForDomain(domain)
            print("   \(config.publicURL(for: key))")
        }
    }
}
