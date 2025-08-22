import Foundation

/// A CloudFormation stack that creates a private S3 bucket accessible only via VPC endpoint.
///
/// This stack creates an S3 bucket with the following security features:
/// - All public access is blocked
/// - Server-side encryption is enabled using AES256
/// - Versioning is enabled for data protection
/// - Access is restricted to a specific VPC endpoint via bucket policy
/// - Old versions are automatically deleted after 90 days
///
/// The bucket is designed for storing private assets and uploads that should only be
/// accessible from within the VPC.
public struct PrivateS3Bucket: Stack {
    /// Creates a new instance of the private S3 bucket stack.
    public init() {}

    public var templateBody: String {
        """
        {
            "AWSTemplateFormatVersion": "2010-09-09",
            "Description": "Private S3 bucket accessible only via VPC endpoint",
            "Parameters": {
                "VPCStackName": {
                    "Type": "String",
                    "Description": "The name of the VPC stack to import S3 VPC endpoint ID from"
                }
            },
            "Resources": {
                "PrivateS3Bucket": {
                    "Type": "AWS::S3::Bucket",
                    "Properties": {
                        "BucketName": "sagebrush-private",
                        "PublicAccessBlockConfiguration": {
                            "BlockPublicAcls": true,
                            "BlockPublicPolicy": true,
                            "IgnorePublicAcls": true,
                            "RestrictPublicBuckets": true
                        },
                        "BucketEncryption": {
                            "ServerSideEncryptionConfiguration": [{
                                "ServerSideEncryptionByDefault": {
                                    "SSEAlgorithm": "AES256"
                                }
                            }]
                        },
                        "VersioningConfiguration": {
                            "Status": "Enabled"
                        },
                        "LifecycleConfiguration": {
                            "Rules": [{
                                "Id": "DeleteOldVersions",
                                "NoncurrentVersionExpirationInDays": 90,
                                "Status": "Enabled"
                            }]
                        }
                    }
                },
                "PrivateS3BucketPolicy": {
                    "Type": "AWS::S3::BucketPolicy",
                    "Properties": {
                        "Bucket": {
                            "Ref": "PrivateS3Bucket"
                        },
                        "PolicyDocument": {
                            "Version": "2012-10-17",
                            "Statement": [{
                                "Sid": "DenyAllExceptVPCEndpoint",
                                "Effect": "Deny",
                                "Principal": "*",
                                "Action": "s3:*",
                                "Resource": [
                                    {
                                        "Fn::GetAtt": ["PrivateS3Bucket", "Arn"]
                                    },
                                    {
                                        "Fn::Sub": "${PrivateS3Bucket.Arn}/*"
                                    }
                                ],
                                "Condition": {
                                    "StringNotEquals": {
                                        "aws:SourceVpce": {
                                            "Fn::ImportValue": {
                                                "Fn::Sub": "${VPCStackName}-S3VPCEndpointId"
                                            }
                                        }
                                    }
                                }
                            }]
                        }
                    }
                }
            },
            "Outputs": {
                "BucketName": {
                    "Description": "Name of the private S3 bucket",
                    "Value": {
                        "Ref": "PrivateS3Bucket"
                    },
                    "Export": {
                        "Name": "PrivateS3BucketName"
                    }
                },
                "BucketArn": {
                    "Description": "ARN of the private S3 bucket",
                    "Value": {
                        "Fn::GetAtt": ["PrivateS3Bucket", "Arn"]
                    },
                    "Export": {
                        "Name": "PrivateS3BucketArn"
                    }
                }
            }
        }
        """
    }
}
