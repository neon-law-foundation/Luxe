struct CloudFrontDistribution: Stack {
    /// Create a CloudFront distribution for serving static websites from S3
    let templateBody: String = """
            {
              "AWSTemplateFormatVersion": "2010-09-09",
              "Description": "CloudFront: Distribution for static website delivery from S3",
              "Parameters": {
                "S3BucketName": {
                  "Type": "String",
                  "Description": "The name of the S3 bucket containing static content"
                },
                "S3OriginPath": {
                  "Type": "String",
                  "Description": "The path prefix in S3 bucket (e.g., /Brochure)",
                  "Default": "/Brochure"
                }
              },
              "Resources": {
                "OriginAccessControl": {
                  "Type": "AWS::CloudFront::OriginAccessControl",
                  "Properties": {
                    "OriginAccessControlConfig": {
                      "Name": "sagebrush-brochure-oac",
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
                      "Comment": "Sagebrush static brochure sites distribution",
                      "DefaultRootObject": "index.html",
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
                        }
                      ],
                      "PriceClass": "PriceClass_100",
                      "HttpVersion": "http2",
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
                "OriginAccessControlId": {
                  "Description": "Origin Access Control ID",
                  "Value": { "Ref": "OriginAccessControl" }
                }
              }
            }
        """
}
