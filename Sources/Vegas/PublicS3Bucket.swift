struct PublicS3Bucket: Stack {
    /// Create a publicly readable S3 bucket with appropriate policies.
    let templateBody: String = """
            {
              "AWSTemplateFormatVersion": "2010-09-09",
              "Description": "S3: Public S3 Bucket for static assets",
              "Parameters": {
                "BucketName": {
                  "Type": "String",
                  "Description": "The name of the S3 bucket"
                }
              },
              "Resources": {
                "S3Bucket": {
                  "Type": "AWS::S3::Bucket",
                  "Properties": {
                    "BucketName": { "Ref": "BucketName" },
                    "PublicAccessBlockConfiguration": {
                      "BlockPublicAcls": false,
                      "BlockPublicPolicy": false,
                      "IgnorePublicAcls": false,
                      "RestrictPublicBuckets": false
                    }
                  }
                }
              },
              "Outputs": {
                "BucketName": {
                  "Description": "Name of the S3 bucket",
                  "Value": { "Ref": "S3Bucket" }
                },
                "BucketDomainName": {
                  "Description": "Domain name of the S3 bucket",
                  "Value": { "Fn::GetAtt": [ "S3Bucket", "DomainName" ] }
                },
                "BucketWebsiteURL": {
                  "Description": "Website URL of the S3 bucket",
                  "Value": { "Fn::GetAtt": [ "S3Bucket", "WebsiteURL" ] }
                }
              }
            }
        """
}
