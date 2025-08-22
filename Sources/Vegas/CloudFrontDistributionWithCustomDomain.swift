struct CloudFrontDistributionWithCustomDomain: Stack {
    /// Create a CloudFront distribution with custom domain (requires pre-existing ACM certificate in us-east-1)
    let templateBody: String = """
            {
              "AWSTemplateFormatVersion": "2010-09-09",
              "Description": "CloudFront: Distribution with custom domain for static website delivery from S3",
              "Parameters": {
                "S3BucketName": {
                  "Type": "String",
                  "Description": "The name of the S3 bucket containing static content"
                },
                "S3OriginPath": {
                  "Type": "String",
                  "Description": "The path prefix in S3 bucket (e.g., /Brochure/NeonLaw)",
                  "Default": "/Brochure"
                },
                "CustomDomainName": {
                  "Type": "String",
                  "Description": "The custom domain name for the CloudFront distribution (e.g., www.neonlaw.com)"
                },
                "SiteName": {
                  "Type": "String",
                  "Description": "The site name for resource naming (e.g., NeonLaw)"
                },
                "ACMCertificateArn": {
                  "Type": "String",
                  "Description": "The ARN of the ACM certificate in us-east-1 region"
                }
              },
              "Resources": {
                "OriginAccessControl": {
                  "Type": "AWS::CloudFront::OriginAccessControl",
                  "Properties": {
                    "OriginAccessControlConfig": {
                      "Name": { "Fn::Sub": "sagebrush-${SiteName}-oac" },
                      "OriginAccessControlOriginType": "s3",
                      "SigningBehavior": "always",
                      "SigningProtocol": "sigv4"
                    }
                  }
                },
                "CloudFrontDistribution": {
                  "Type": "AWS::CloudFront::Distribution",
                  "Properties": {
                    "DistributionConfig": {
                      "Enabled": true,
                      "Comment": { "Fn::Sub": "Sagebrush ${SiteName} static website distribution" },
                      "DefaultRootObject": "index.html",
                      "Aliases": [
                        { "Ref": "CustomDomainName" }
                      ],
                      "ViewerCertificate": {
                        "AcmCertificateArn": { "Ref": "ACMCertificateArn" },
                        "SslSupportMethod": "sni-only",
                        "MinimumProtocolVersion": "TLSv1.2_2021"
                      },
                      "Origins": [
                        {
                          "Id": "S3Origin",
                          "DomainName": {
                            "Fn::Sub": "${S3BucketName}.s3.us-west-2.amazonaws.com"
                          },
                          "OriginPath": { "Ref": "S3OriginPath" },
                          "S3OriginConfig": {
                            "OriginAccessIdentity": ""
                          },
                          "OriginAccessControlId": { "Ref": "OriginAccessControl" }
                        }
                      ],
                      "DefaultCacheBehavior": {
                        "TargetOriginId": "S3Origin",
                        "ViewerProtocolPolicy": "redirect-to-https",
                        "CachePolicyId": "4135ea2d-6df8-44a3-9df3-4b5a84be39ad",
                        "Compress": true,
                        "AllowedMethods": [ "GET", "HEAD" ],
                        "CachedMethods": [ "GET", "HEAD" ]
                      },
                      "CacheBehaviors": [
                        {
                          "PathPattern": "*.html",
                          "TargetOriginId": "S3Origin",
                          "ViewerProtocolPolicy": "redirect-to-https",
                          "CachePolicyId": "4135ea2d-6df8-44a3-9df3-4b5a84be39ad",
                          "Compress": true,
                          "AllowedMethods": [ "GET", "HEAD" ],
                          "CachedMethods": [ "GET", "HEAD" ]
                        },
                        {
                          "PathPattern": "*.css",
                          "TargetOriginId": "S3Origin",
                          "ViewerProtocolPolicy": "redirect-to-https",
                          "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
                          "Compress": true,
                          "AllowedMethods": [ "GET", "HEAD" ],
                          "CachedMethods": [ "GET", "HEAD" ]
                        },
                        {
                          "PathPattern": "*.js",
                          "TargetOriginId": "S3Origin",
                          "ViewerProtocolPolicy": "redirect-to-https",
                          "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
                          "Compress": true,
                          "AllowedMethods": [ "GET", "HEAD" ],
                          "CachedMethods": [ "GET", "HEAD" ]
                        },
                        {
                          "PathPattern": "*.png",
                          "TargetOriginId": "S3Origin",
                          "ViewerProtocolPolicy": "redirect-to-https",
                          "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
                          "Compress": false,
                          "AllowedMethods": [ "GET", "HEAD" ],
                          "CachedMethods": [ "GET", "HEAD" ]
                        },
                        {
                          "PathPattern": "*.jpg",
                          "TargetOriginId": "S3Origin",
                          "ViewerProtocolPolicy": "redirect-to-https",
                          "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
                          "Compress": false,
                          "AllowedMethods": [ "GET", "HEAD" ],
                          "CachedMethods": [ "GET", "HEAD" ]
                        },
                        {
                          "PathPattern": "*.jpeg",
                          "TargetOriginId": "S3Origin",
                          "ViewerProtocolPolicy": "redirect-to-https",
                          "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
                          "Compress": false,
                          "AllowedMethods": [ "GET", "HEAD" ],
                          "CachedMethods": [ "GET", "HEAD" ]
                        },
                        {
                          "PathPattern": "*.gif",
                          "TargetOriginId": "S3Origin",
                          "ViewerProtocolPolicy": "redirect-to-https",
                          "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
                          "Compress": false,
                          "AllowedMethods": [ "GET", "HEAD" ],
                          "CachedMethods": [ "GET", "HEAD" ]
                        },
                        {
                          "PathPattern": "*.svg",
                          "TargetOriginId": "S3Origin",
                          "ViewerProtocolPolicy": "redirect-to-https",
                          "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
                          "Compress": true,
                          "AllowedMethods": [ "GET", "HEAD" ],
                          "CachedMethods": [ "GET", "HEAD" ]
                        },
                        {
                          "PathPattern": "*.webp",
                          "TargetOriginId": "S3Origin",
                          "ViewerProtocolPolicy": "redirect-to-https",
                          "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
                          "Compress": false,
                          "AllowedMethods": [ "GET", "HEAD" ],
                          "CachedMethods": [ "GET", "HEAD" ]
                        },
                        {
                          "PathPattern": "*.ico",
                          "TargetOriginId": "S3Origin",
                          "ViewerProtocolPolicy": "redirect-to-https",
                          "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
                          "Compress": false,
                          "AllowedMethods": [ "GET", "HEAD" ],
                          "CachedMethods": [ "GET", "HEAD" ]
                        },
                        {
                          "PathPattern": "*.woff",
                          "TargetOriginId": "S3Origin",
                          "ViewerProtocolPolicy": "redirect-to-https",
                          "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
                          "Compress": false,
                          "AllowedMethods": [ "GET", "HEAD" ],
                          "CachedMethods": [ "GET", "HEAD" ]
                        },
                        {
                          "PathPattern": "*.woff2",
                          "TargetOriginId": "S3Origin",
                          "ViewerProtocolPolicy": "redirect-to-https",
                          "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
                          "Compress": false,
                          "AllowedMethods": [ "GET", "HEAD" ],
                          "CachedMethods": [ "GET", "HEAD" ]
                        },
                        {
                          "PathPattern": "*.ttf",
                          "TargetOriginId": "S3Origin",
                          "ViewerProtocolPolicy": "redirect-to-https",
                          "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6",
                          "Compress": false,
                          "AllowedMethods": [ "GET", "HEAD" ],
                          "CachedMethods": [ "GET", "HEAD" ]
                        },
                        {
                          "PathPattern": "*.json",
                          "TargetOriginId": "S3Origin",
                          "ViewerProtocolPolicy": "redirect-to-https",
                          "CachePolicyId": "4135ea2d-6df8-44a3-9df3-4b5a84be39ad",
                          "Compress": true,
                          "AllowedMethods": [ "GET", "HEAD" ],
                          "CachedMethods": [ "GET", "HEAD" ]
                        }
                      ],
                      "CustomErrorResponses": [
                        {
                          "ErrorCode": 403,
                          "ResponseCode": 404,
                          "ResponsePagePath": "/404.html",
                          "ErrorCachingMinTTL": 300
                        },
                        {
                          "ErrorCode": 404,
                          "ResponseCode": 404,
                          "ResponsePagePath": "/404.html",
                          "ErrorCachingMinTTL": 300
                        }
                      ],
                      "PriceClass": "PriceClass_100",
                      "HttpVersion": "http2and3",
                      "IPV6Enabled": true
                    }
                  }
                }
              },
              "Outputs": {
                "DistributionId": {
                  "Description": "CloudFront Distribution ID",
                  "Value": { "Ref": "CloudFrontDistribution" }
                },
                "DistributionDomainName": {
                  "Description": "CloudFront Distribution Domain Name",
                  "Value": { "Fn::GetAtt": [ "CloudFrontDistribution", "DomainName" ] }
                },
                "CustomDomainName": {
                  "Description": "Custom Domain Name",
                  "Value": { "Ref": "CustomDomainName" }
                },
                "ACMCertificateArn": {
                  "Description": "ACM Certificate ARN",
                  "Value": { "Ref": "ACMCertificateArn" }
                },
                "OriginAccessControlId": {
                  "Description": "Origin Access Control ID",
                  "Value": { "Ref": "OriginAccessControl" }
                }
              }
            }
        """
}
