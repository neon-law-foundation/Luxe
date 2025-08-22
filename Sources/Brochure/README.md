# Brochure

A Swift CLI tool for uploading static websites to S3 for CloudFront distribution.

## Quick Installation

```bash
curl -fsSL https://cli.neonlaw.com/brochure/install.sh | bash
```

For detailed installation options, see [Installation Guide](../../Documentation/BrochureCLI/INSTALLATION.md) or [Quick Start](../../Documentation/BrochureCLI/QUICKSTART.md).

## Overview

Brochure is a command-line utility that efficiently uploads static website files to AWS S3 with proper content types
and cache control headers optimized for CloudFront CDN distribution. It supports multiple static sites with
folder-based organization and includes features like MD5 hash comparison to skip unchanged files, multipart uploads
for large files, and dry-run mode for previewing operations.

## Features

- **Multi-site Support**: Upload different static sites (NeonLaw, HoshiHoshi, TarotSwift, NLF, NVSciTech, 1337lawyers)
- **Efficient Uploads**: MD5 hash comparison skips unchanged files automatically
- **Large File Handling**: Multipart uploads for files over 5MB with retry logic
- **Content Optimization**: Automatic content-type detection and cache control headers
- **Dry Run Mode**: Preview operations without actually uploading files
- **Progress Reporting**: Clear logging of upload progress and results
- **Error Handling**: Robust retry logic with exponential backoff for network issues

## Usage

### Basic Upload

```bash
# Upload a specific static site
swift run Brochure upload NeonLaw
swift run Brochure upload HoshiHoshi
swift run Brochure upload TarotSwift
swift run Brochure upload NLF
swift run Brochure upload NVSciTech
swift run Brochure upload 1337lawyers
```

### Dry Run

```bash
# Preview what would be uploaded without making changes
swift run Brochure upload NeonLaw --dry-run
```

## S3 Organization

Files are uploaded to the `sagebrush-public` S3 bucket with the following structure:

```text
s3://sagebrush-public/brochure/
├── NeonLaw/
├── HoshiHoshi/
├── TarotSwift/
├── NLF/
├── NVSciTech/
└── 1337lawyers/
```

## Cache Control Strategy

- **HTML files**: `no-cache, must-revalidate` - Always fetch fresh content

- **CSS/JS/Images**: `public, max-age=31536000, immutable` - Cache for 1 year

## AWS Configuration

Brochure uses the AWS SDK's default credential provider chain. Ensure you have AWS credentials configured through one
of the following methods:

- AWS credentials file (`~/.aws/credentials`)

- Environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)

- IAM roles (when running on EC2)

- AWS SSO

### Required Permissions

Your AWS credentials must have the following S3 permissions for the `sagebrush-public` bucket:

- `s3:PutObject`

- `s3:GetObject`

- `s3:HeadObject`

## Implementation Details

### Content Type Detection

Brochure automatically detects content types based on file extensions:

- HTML: `text/html`

- CSS: `text/css`

- JavaScript: `application/javascript`

- Images: `image/jpeg`, `image/png`, `image/gif`, `image/svg+xml`

- Fonts: `font/woff`, `font/woff2`, `font/ttf`

### MD5 Hash Comparison

Before uploading, Brochure calculates the MD5 hash of local files and compares them with the ETag of existing S3
objects. Files with matching hashes are skipped to avoid unnecessary uploads.

### Multipart Upload

Files larger than 5MB automatically use S3's multipart upload feature for improved reliability and performance. The
upload is split into 5MB chunks with individual retry logic for each part.

### Error Handling

All S3 operations include retry logic with exponential backoff:

- Maximum 3 retry attempts

- Base delay of 1 second

- Exponential backoff (1s, 2s, 4s)

## Development

To modify or extend Brochure:

1. Add new static sites by creating directories in `Sources/Brochure/Public/`
2. Update the site validation logic in `UploadCommand.swift`
3. Modify content type detection in `ContentTypeDetector.swift`
4. Adjust S3 upload logic in `S3Uploader.swift`

## Testing

Run tests to ensure functionality:

```bash
swift test --filter BrochureTests
```

Test with dry-run mode before making changes:

```bash
swift run Brochure upload [SiteName] --dry-run
```
