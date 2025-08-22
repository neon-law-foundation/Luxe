#!/bin/bash

# LocalStack SQS and S3 initialization script for email processing system
# This script creates the necessary SQS queues and S3 buckets for local development

echo "Initializing LocalStack SQS and S3 for email processing system..."

# Create the email processing queue
awslocal sqs create-queue --queue-name email-processing

# Create a dead letter queue for failed email processing
awslocal sqs create-queue --queue-name email-processing_failed

# Set up the dead letter queue policy
DLQ_URL=$(awslocal sqs get-queue-url --queue-name email-processing_failed --query 'QueueUrl' --output text)
DLQ_ARN=$(awslocal sqs get-queue-attributes --queue-url $DLQ_URL --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)

# Configure the main queue to use the dead letter queue
MAIN_QUEUE_URL=$(awslocal sqs get-queue-url --queue-name email-processing --query 'QueueUrl' --output text)
awslocal sqs set-queue-attributes --queue-url $MAIN_QUEUE_URL --attributes '{
    "RedrivePolicy": "{\"deadLetterTargetArn\":\"'$DLQ_ARN'\",\"maxReceiveCount\":\"3\"}",
    "VisibilityTimeoutSeconds": "300",
    "MessageRetentionPeriod": "1209600"
}'

echo "SQS queues created successfully:"
echo "- Email processing queue: email-processing"
echo "- Email processing dead letter queue: email-processing_failed"

# List all queues to verify
echo "Available queues:"
awslocal sqs list-queues

# Create S3 buckets for local development
echo "Creating S3 buckets..."

# Create the main application buckets
awslocal s3 mb s3://luxe-private-bucket
awslocal s3 mb s3://luxe-public-bucket
awslocal s3 mb s3://sagebrush-emails

# Set public read access for the public bucket
awslocal s3api put-bucket-acl --bucket luxe-public-bucket --acl public-read

# Create holiday/vacation mode buckets
awslocal s3 mb s3://luxe-holiday-bucket

# Configure S3 bucket notification for email processing
EMAIL_QUEUE_ARN=$(awslocal sqs get-queue-attributes --queue-url $MAIN_QUEUE_URL --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)
awslocal s3api put-bucket-notification-configuration --bucket sagebrush-emails --notification-configuration '{
    "QueueConfigurations": [
        {
            "Id": "EmailProcessingNotification",
            "QueueArn": "'$EMAIL_QUEUE_ARN'",
            "Events": ["s3:ObjectCreated:*"]
        }
    ]
}'

echo "S3 buckets created successfully:"
echo "- Private bucket: luxe-private-bucket"
echo "- Public bucket: luxe-public-bucket"
echo "- Email processing bucket: sagebrush-emails"
echo "- Holiday bucket: luxe-holiday-bucket"

# List all buckets to verify
echo "Available buckets:"
awslocal s3 ls

echo "LocalStack SQS and S3 initialization for email processing complete!"