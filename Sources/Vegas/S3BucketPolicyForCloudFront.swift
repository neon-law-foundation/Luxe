struct S3BucketPolicyForCloudFront: Stack {
    /// Create a centralized S3 bucket policy that allows access from all CloudFront distributions
    let templateBody: String = """
            {
              "AWSTemplateFormatVersion": "2010-09-09",
              "Description": "S3 Bucket Policy: Centralized policy for CloudFront access to static brochure content",
              "Parameters": {
                "S3BucketName": {
                  "Type": "String",
                  "Description": "The name of the S3 bucket containing static content",
                  "Default": "sagebrush-public"
                },
                "NeonLawDistributionId": {
                  "Type": "String",
                  "Description": "CloudFront Distribution ID for NeonLaw"
                },
                "HoshiHoshiDistributionId": {
                  "Type": "String",
                  "Description": "CloudFront Distribution ID for HoshiHoshi"
                },
                "TarotSwiftDistributionId": {
                  "Type": "String",
                  "Description": "CloudFront Distribution ID for TarotSwift"
                },
                "NeonLawOrgDistributionId": {
                  "Type": "String",
                  "Description": "CloudFront Distribution ID for NeonLaw.org"
                },
                "NVSciTechDistributionId": {
                  "Type": "String",
                  "Description": "CloudFront Distribution ID for NVSciTech"
                },
                "LeetLawyersDistributionId": {
                  "Type": "String",
                  "Description": "CloudFront Distribution ID for 1337lawyers"
                },
                "LegacyBrochureDistributionId": {
                  "Type": "String",
                  "Description": "CloudFront Distribution ID for legacy brochure (fallback)",
                  "Default": ""
                }
              },
              "Conditions": {
                "HasLegacyDistribution": {
                  "Fn::Not": [
                    { "Fn::Equals": [ { "Ref": "LegacyBrochureDistributionId" }, "" ] }
                  ]
                }
              },
              "Resources": {
                "S3BucketPolicy": {
                  "Type": "AWS::S3::BucketPolicy",
                  "Properties": {
                    "Bucket": { "Ref": "S3BucketName" },
                    "PolicyDocument": {
                      "Version": "2008-10-17",
                      "Statement": [
                        {
                          "Effect": "Allow",
                          "Principal": {
                            "Service": "cloudfront.amazonaws.com"
                          },
                          "Action": "s3:GetObject",
                          "Resource": {
                            "Fn::Sub": "arn:aws:s3:::${S3BucketName}/Brochure/*"
                          },
                          "Condition": {
                            "StringEquals": {
                              "AWS:SourceArn": {
                                "Fn::If": [
                                  "HasLegacyDistribution",
                                  [
                                    { "Fn::Sub": "arn:aws:cloudfront::${AWS::AccountId}:distribution/${NeonLawDistributionId}" },
                                    { "Fn::Sub": "arn:aws:cloudfront::${AWS::AccountId}:distribution/${HoshiHoshiDistributionId}" },
                                    { "Fn::Sub": "arn:aws:cloudfront::${AWS::AccountId}:distribution/${TarotSwiftDistributionId}" },
                                    { "Fn::Sub": "arn:aws:cloudfront::${AWS::AccountId}:distribution/${NeonLawOrgDistributionId}" },
                                    { "Fn::Sub": "arn:aws:cloudfront::${AWS::AccountId}:distribution/${NVSciTechDistributionId}" },
                                    { "Fn::Sub": "arn:aws:cloudfront::${AWS::AccountId}:distribution/${LeetLawyersDistributionId}" },
                                    { "Fn::Sub": "arn:aws:cloudfront::${AWS::AccountId}:distribution/${LegacyBrochureDistributionId}" }
                                  ],
                                  [
                                    { "Fn::Sub": "arn:aws:cloudfront::${AWS::AccountId}:distribution/${NeonLawDistributionId}" },
                                    { "Fn::Sub": "arn:aws:cloudfront::${AWS::AccountId}:distribution/${HoshiHoshiDistributionId}" },
                                    { "Fn::Sub": "arn:aws:cloudfront::${AWS::AccountId}:distribution/${TarotSwiftDistributionId}" },
                                    { "Fn::Sub": "arn:aws:cloudfront::${AWS::AccountId}:distribution/${NeonLawOrgDistributionId}" },
                                    { "Fn::Sub": "arn:aws:cloudfront::${AWS::AccountId}:distribution/${NVSciTechDistributionId}" },
                                    { "Fn::Sub": "arn:aws:cloudfront::${AWS::AccountId}:distribution/${LeetLawyersDistributionId}" }
                                  ]
                                ]
                              }
                            }
                          }
                        }
                      ]
                    }
                  }
                }
              },
              "Outputs": {
                "BucketPolicyId": {
                  "Description": "S3 Bucket Policy ID",
                  "Value": { "Ref": "S3BucketPolicy" }
                },
                "BucketName": {
                  "Description": "S3 Bucket Name",
                  "Value": { "Ref": "S3BucketName" }
                }
              }
            }
        """
}
