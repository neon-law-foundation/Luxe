import Foundation

/// A CloudFormation stack that creates a private S3 bucket for storing incoming emails from SES.
///
/// This stack creates an S3 bucket with the following features:
/// - Named "sagebrush-emails" for email storage
/// - All public access is blocked
/// - Server-side encryption is enabled using AES256
/// - Versioning is enabled for data protection
/// - SES service has permission to put email objects
/// - Lifecycle policies for automatic cleanup of processed emails
/// - S3 notifications to trigger SQS queue for email processing
///
/// The bucket is designed to store raw email messages from SES before they are
/// processed and moved to the application database.
public struct PrivateEmailS3Bucket: Stack {
    /// Creates a new instance of the private email S3 bucket stack.
    public init() {}

    public var templateBody: String {
        """
        {
            "AWSTemplateFormatVersion": "2010-09-09",
            "Description": "Private S3 bucket for storing incoming emails from SES",
            "Parameters": {},
            "Resources": {
                "PrivateEmailS3Bucket": {
                    "Type": "AWS::S3::Bucket",
                    "Properties": {
                        "BucketName": "sagebrush-emails",
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
                            "Rules": [
                                {
                                    "Id": "DeleteProcessedEmails",
                                    "ExpirationInDays": 30,
                                    "Status": "Enabled"
                                },
                                {
                                    "Id": "DeleteOldVersions",
                                    "NoncurrentVersionExpirationInDays": 7,
                                    "Status": "Enabled"
                                }
                            ]
                        },
                        "NotificationConfiguration": {
                            "QueueConfigurations": [{
                                "Event": "s3:ObjectCreated:*",
                                "Queue": {
                                    "Fn::ImportValue": "SQSEmailQueueArn"
                                }
                            }]
                        }
                    }
                },
                "PrivateEmailS3BucketPolicy": {
                    "Type": "AWS::S3::BucketPolicy",
                    "Properties": {
                        "Bucket": {
                            "Ref": "PrivateEmailS3Bucket"
                        },
                        "PolicyDocument": {
                            "Version": "2012-10-17",
                            "Statement": [{
                                "Sid": "AllowSESPutObject",
                                "Effect": "Allow",
                                "Principal": {
                                    "Service": "ses.amazonaws.com"
                                },
                                "Action": [
                                    "s3:PutObject"
                                ],
                                "Resource": {
                                    "Fn::Sub": "${PrivateEmailS3Bucket.Arn}/*"
                                },
                                "Condition": {
                                    "StringLike": {
                                        "aws:SourceArn": {
                                            "Fn::Sub": "arn:aws:ses:${AWS::Region}:${AWS::AccountId}:*"
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
                    "Description": "Name of the private email S3 bucket",
                    "Value": {
                        "Ref": "PrivateEmailS3Bucket"
                    },
                    "Export": {
                        "Name": "PrivateEmailS3BucketName"
                    }
                },
                "BucketArn": {
                    "Description": "ARN of the private email S3 bucket",
                    "Value": {
                        "Fn::GetAtt": ["PrivateEmailS3Bucket", "Arn"]
                    },
                    "Export": {
                        "Name": "PrivateEmailS3BucketArn"
                    }
                },
                "BucketDomainName": {
                    "Description": "Domain name of the private email S3 bucket",
                    "Value": {
                        "Fn::GetAtt": ["PrivateEmailS3Bucket", "DomainName"]
                    },
                    "Export": {
                        "Name": "PrivateEmailS3BucketDomainName"
                    }
                }
            }
        }
        """
    }
}
