import Foundation

/// A CloudFormation stack that creates an SQS queue specifically for email processing.
///
/// This stack creates SQS infrastructure for inbound email processing:
/// - Email processing queue triggered by S3 bucket notifications
/// - Dead letter queue for failed email processing
/// - Server-side encryption using AWS managed keys
/// - Long polling configuration for efficient message retrieval
/// - Message retention and redrive policies
///
/// The queue is used specifically for processing incoming emails from SES,
/// separate from general application job processing.
public struct SQSEmailQueue: Stack {
    /// Creates a new instance of the SQS email queue stack.
    public init() {}

    public var templateBody: String {
        """
        {
            "AWSTemplateFormatVersion": "2010-09-09",
            "Description": "SQS queue for processing inbound emails from SES",
            "Parameters": {},
            "Resources": {
                "EmailProcessingDeadLetterQueue": {
                    "Type": "AWS::SQS::Queue",
                    "Properties": {
                        "QueueName": "email-processing_failed",
                        "MessageRetentionPeriod": 1209600,
                        "KmsMasterKeyId": "alias/aws/sqs"
                    }
                },
                "EmailProcessingQueue": {
                    "Type": "AWS::SQS::Queue",
                    "Properties": {
                        "QueueName": "email-processing",
                        "VisibilityTimeout": 300,
                        "MessageRetentionPeriod": 1209600,
                        "ReceiveMessageWaitTimeSeconds": 20,
                        "KmsMasterKeyId": "alias/aws/sqs",
                        "RedrivePolicy": {
                            "maxReceiveCount": 3,
                            "deadLetterTargetArn": {
                                "Fn::GetAtt": ["EmailProcessingDeadLetterQueue", "Arn"]
                            }
                        }
                    }
                },
                "EmailProcessingQueuePolicy": {
                    "Type": "AWS::SQS::QueuePolicy",
                    "Properties": {
                        "Queues": [{
                            "Ref": "EmailProcessingQueue"
                        }],
                        "PolicyDocument": {
                            "Version": "2012-10-17",
                            "Statement": [{
                                "Sid": "AllowS3BucketNotification",
                                "Effect": "Allow",
                                "Principal": {
                                    "Service": "s3.amazonaws.com"
                                },
                                "Action": "sqs:SendMessage",
                                "Resource": {
                                    "Fn::GetAtt": ["EmailProcessingQueue", "Arn"]
                                },
                                "Condition": {
                                    "StringEquals": {
                                        "aws:SourceAccount": {
                                            "Ref": "AWS::AccountId"
                                        }
                                    },
                                    "ArnLike": {
                                        "aws:SourceArn": {
                                            "Fn::Sub": "arn:aws:s3:::sagebrush-emails"
                                        }
                                    }
                                }
                            }]
                        }
                    }
                }
            },
            "Outputs": {
                "SQSEmailQueueArn": {
                    "Description": "ARN of the SQS email processing queue for S3 notifications",
                    "Value": {
                        "Fn::GetAtt": ["EmailProcessingQueue", "Arn"]
                    },
                    "Export": {
                        "Name": "SQSEmailQueueArn"
                    }
                },
                "QueueUrl": {
                    "Description": "URL of the email processing queue",
                    "Value": {
                        "Ref": "EmailProcessingQueue"
                    },
                    "Export": {
                        "Name": "EmailProcessingQueueUrl"
                    }
                },
                "QueueName": {
                    "Description": "Name of the email processing queue",
                    "Value": {
                        "Fn::GetAtt": ["EmailProcessingQueue", "QueueName"]
                    },
                    "Export": {
                        "Name": "EmailProcessingQueueName"
                    }
                },
                "DeadLetterQueueArn": {
                    "Description": "ARN of the email processing dead letter queue",
                    "Value": {
                        "Fn::GetAtt": ["EmailProcessingDeadLetterQueue", "Arn"]
                    },
                    "Export": {
                        "Name": "EmailProcessingDeadLetterQueueArn"
                    }
                },
                "DeadLetterQueueUrl": {
                    "Description": "URL of the email processing dead letter queue",
                    "Value": {
                        "Ref": "EmailProcessingDeadLetterQueue"
                    },
                    "Export": {
                        "Name": "EmailProcessingDeadLetterQueueUrl"
                    }
                }
            }
        }
        """
    }
}
