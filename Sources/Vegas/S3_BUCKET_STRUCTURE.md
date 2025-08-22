# S3 Bucket Structure and Naming Conventions

## Overview

The Brochure CLI tool uses a structured approach to organize static websites in Amazon S3, optimized for CloudFront
distribution and efficient content delivery.

## Bucket Configuration

### Primary Bucket

- **Name**: `sagebrush-public`

- **Region**: `us-west-2` (Oregon)

- **Purpose**: Public hosting of static websites

- **Access**: Public read access via CloudFront Origin Access Control (OAC)

### Bucket Structure

```text
s3://sagebrush-public/
├── brochure/                              # Brochure CLI managed content
│   ├── NeonLaw/                          # Law firm website
│   │   ├── index.html
│   │   ├── css/
│   │   │   ├── styles.css
│   │   │   └── bootstrap.min.css
│   │   ├── js/
│   │   │   ├── app.js
│   │   │   └── jquery.min.js
│   │   ├── images/
│   │   │   ├── logo.png
│   │   │   └── banner.jpg
│   │   └── fonts/
│   │       ├── roboto.woff2
│   │       └── opensans.woff
│   └── HoshiHoshi/                       # Application website
│       ├── index.html
│       ├── app/
│       ├── docs/
│       └── ...
└── other-content/                         # Non-Brochure managed content
    └── ...
```

## Naming Conventions

### File Path Structure

All files uploaded by Brochure follow this pattern:

```text
s3://sagebrush-public/brochure/{SiteName}/{RelativePath}
```

#### Components

- **Bucket**: `sagebrush-public` (configurable via UploadConfiguration)
- **Key Prefix**: `brochure` (configurable via UploadConfiguration)
- **Site Name**: One of `NeonLaw`, `HoshiHoshi`
- **Relative Path**: Preserves the original directory structure from source

### Site Name Requirements

- **Format**: PascalCase (e.g., `NeonLaw`)
- **Validation**: Must match exactly one of the predefined site names
- **Case Sensitivity**: Exact case matching required
- **No Spaces**: Use PascalCase instead of spaces or hyphens

### File Name Conventions

- **Preserve Original**: File names are kept exactly as they appear in source
- **Case Sensitive**: S3 object keys are case-sensitive
- **Special Characters**: URL-encoded automatically by AWS SDK
- **No Restrictions**: Supports any valid file system characters

## Content Type Mapping

### HTML Files

- **Extensions**: `.html`, `.htm`
- **Content-Type**: `text/html`
- **Cache-Control**: `no-cache, must-revalidate`
- **Purpose**: Ensures fresh content for dynamic updates

### Stylesheets

- **Extensions**: `.css`, `.scss`, `.sass`, `.less`
- **Content-Type**: `text/css`
- **Cache-Control**: `public, max-age=31536000, immutable`
- **Purpose**: Long-term caching for static assets

### JavaScript

- **Extensions**: `.js`, `.mjs`, `.ts`, `.jsx`, `.tsx`
- **Content-Type**: `application/javascript`
- **Cache-Control**: `public, max-age=31536000, immutable`
- **Purpose**: Long-term caching for code files

### Images

- **Extensions**: `.png`, `.jpg`, `.jpeg`, `.gif`, `.svg`, `.webp`, `.ico`

- **Content-Type**: Appropriate MIME type per extension

- **Cache-Control**: `public, max-age=31536000, immutable`

- **Purpose**: Long-term caching for static media

### Fonts

- **Extensions**: `.woff`, `.woff2`, `.ttf`, `.otf`, `.eot`

- **Content-Type**: Appropriate font MIME type

- **Cache-Control**: `public, max-age=31536000, immutable`

- **Purpose**: Long-term caching for typography

### Documents

- **Extensions**: `.pdf`, `.txt`, `.md`

- **Content-Type**: Appropriate document MIME type

- **Cache-Control**: `public, max-age=86400` (1 day for PDF), `public, max-age=3600` (1 hour for others)

- **Purpose**: Moderate caching for document content

### Configuration Files

- **Extensions**: `.json`, `.webmanifest`, `.manifest`

- **Content-Type**: `application/json` or `application/manifest+json`

- **Cache-Control**: `public, max-age=3600`

- **Purpose**: Short-term caching for config updates

## Cache Strategy

### Three-Tier Caching Approach

#### Tier 1: No Cache (HTML)

- **Files**: HTML pages, dynamic content

- **Header**: `no-cache, must-revalidate`

- **Rationale**: Ensures users get latest content updates immediately

- **TTL**: 0 seconds

#### Tier 2: Long-term Cache (Static Assets)

- **Files**: CSS, JS, Images, Fonts

- **Header**: `public, max-age=31536000, immutable`

- **Rationale**: These files rarely change and benefit from aggressive caching

- **TTL**: 1 year (365 days)

#### Tier 3: Moderate Cache (Configuration)

- **Files**: JSON, manifests, documents

- **Header**: `public, max-age=3600` to `public, max-age=86400`

- **Rationale**: Balance between freshness and performance

- **TTL**: 1 hour to 1 day

## CloudFront Integration

### Distribution Configuration

- **Origin**: `sagebrush-public.s3.us-west-2.amazonaws.com`

- **Origin Path**: `/brochure`

- **OAC**: Enabled for secure S3 access

- **Price Class**: All edge locations for global performance

### Behavior Patterns

1. **Default Behavior**: Serves all content under `/brochure/*`
2. **Cache Headers**: Respects S3 object cache-control headers
3. **Compression**: Automatic gzip compression enabled
4. **Security**: HTTPS redirect enforced

### Cache Invalidation

- **Manual**: Required for immediate updates to cached content

- **Patterns**: Use `/{SiteName}/*` for site-wide invalidation

- **Cost**: AWS charges per invalidation request

## Access Control

### S3 Bucket Policy

- **Public Read**: Denied (CloudFront OAC only)

- **Origin Access Control**: CloudFront distribution has exclusive read access

- **Upload Access**: Restricted to authenticated AWS accounts with appropriate IAM permissions

### Required IAM Permissions

For Brochure CLI operation:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:PutObjectAcl",
                "s3:GetObject",
                "s3:HeadObject"
            ],
            "Resource": "arn:aws:s3:::sagebrush-public/brochure/*"
        }
    ]
}
```

## Monitoring and Analytics

### CloudWatch Metrics

- **S3 Metrics**: Object count, bucket size, request metrics

- **CloudFront Metrics**: Cache hit ratio, origin requests, error rates

- **Custom Metrics**: Upload success/failure rates from CLI

### Logging

- **S3 Access Logs**: Optional for detailed access analysis

- **CloudFront Logs**: Standard or real-time logs for traffic analysis

- **CLI Logs**: Structured logging for upload operations

## Best Practices

### File Organization

1. **Consistent Structure**: Maintain similar directory structure across sites
2. **Asset Grouping**: Group similar files (CSS, JS, images) in dedicated folders
3. **Naming**: Use descriptive, lowercase file names with hyphens
4. **Versioning**: Consider including version info in asset file names for cache busting

### Performance Optimization

1. **Image Optimization**: Compress images before upload
2. **Minification**: Minify CSS and JavaScript files
3. **Compression**: Enable gzip for text-based files
4. **Lazy Loading**: Implement for non-critical resources

### Security Considerations

1. **No Sensitive Data**: Never upload sensitive information to public bucket
2. **Access Review**: Regularly audit IAM permissions
3. **HTTPS Only**: Enforce HTTPS for all content delivery
4. **Content Validation**: Validate uploaded content for security risks

## Troubleshooting

### Common Issues

#### Upload Failures

- **Permissions**: Verify IAM policy allows PutObject on bucket/prefix

- **Network**: Check internet connectivity and AWS service status

- **File Size**: Ensure large files use multipart upload

- **Rate Limits**: Retry logic handles AWS throttling

#### Content Not Updating

- **Cache**: CloudFront cache may need invalidation

- **TTL**: Check cache-control headers are set correctly

- **Propagation**: Allow time for global CDN propagation

#### Access Denied

- **OAC**: Verify CloudFront Origin Access Control is configured

- **Bucket Policy**: Ensure bucket policy allows CloudFront access

- **IAM**: Check user/role has required S3 permissions

### Debugging Commands

```bash
# Test CLI connectivity
swift run Brochure upload HoshiHoshi --dry-run --verbose

# Check S3 object details
aws s3api head-object --bucket sagebrush-public --key brochure/HoshiHoshi/index.html

# List bucket contents
aws s3 ls s3://sagebrush-public/brochure/ --recursive
```

## Configuration Reference

### Environment Variables

- `AWS_PROFILE`: AWS CLI profile for authentication

- `AWS_REGION`: Override default region (default: us-west-2)

- `AWS_ACCESS_KEY_ID`: Direct credential specification

- `AWS_SECRET_ACCESS_KEY`: Direct credential specification

### UploadConfiguration Options

```swift
UploadConfiguration(
    bucketName: "sagebrush-public",        // S3 bucket name
    keyPrefix: "brochure",                 // Object key prefix
    region: "us-west-2",                   // AWS region
    skipUnchangedFiles: true,              // MD5 comparison
    enableMultipartUpload: true,           // Large file handling
    multipartChunkSize: 5 * 1024 * 1024,  // 5MB chunks
    maxRetries: 3,                         // Retry attempts
    retryBaseDelay: 1.0                    // Exponential backoff base
)
```

This structure provides efficient, scalable static website hosting with optimal performance and security
characteristics.
