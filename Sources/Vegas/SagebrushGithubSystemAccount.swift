struct SagebrushGithubSystemAccount: Stack {
    /// Create an IAM user with permissions to upload to s3://sagebrush-public/bin/
    /// and restart ECS services Bazaar and Destined.
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "IAM user with permissions for GitHub Actions to upload to S3 and restart ECS services.",
          "Resources": {
            "SagebrushGithubUser": {
              "Type": "AWS::IAM::User",
              "Properties": {
                "UserName": "sagebrush-github-system-account"
              }
            },
            "SagebrushGithubS3Policy": {
              "Type": "AWS::IAM::Policy",
              "Properties": {
                "PolicyName": "SagebrushS3BinAccessPolicy",
                "Users": [ { "Ref": "SagebrushGithubUser" } ],
                "PolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Action": [
                        "s3:PutObject",
                        "s3:PutObjectAcl"
                      ],
                      "Resource": "arn:aws:s3:::sagebrush-public/bin/*"
                    }
                  ]
                }
              }
            },
            "SagebrushGithubECSPolicy": {
              "Type": "AWS::IAM::Policy",
              "Properties": {
                "PolicyName": "SagebrushECSServiceRestartPolicy",
                "Users": [ { "Ref": "SagebrushGithubUser" } ],
                "PolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Action": [
                        "ecs:UpdateService",
                        "ecs:DescribeServices"
                      ],
                      "Resource": [
                        "arn:aws:ecs:*:*:service/*/Bazaar",
                        "arn:aws:ecs:*:*:service/*/Destined"
                      ]
                    },
                    {
                      "Effect": "Allow",
                      "Action": [
                        "ecs:ListServices",
                        "ecs:ListClusters"
                      ],
                      "Resource": "*"
                    }
                  ]
                }
              }
            }
          },
          "Outputs": {
            "SagebrushGithubUserName": {
              "Description": "Name of the Sagebrush GitHub system account IAM user",
              "Value": { "Ref": "SagebrushGithubUser" },
              "Export": {
                "Name": "SagebrushGithubSystemAccount-UserName"
              }
            },
            "SagebrushGithubUserArn": {
              "Description": "ARN of the Sagebrush GitHub system account IAM user",
              "Value": { "Fn::GetAtt": ["SagebrushGithubUser", "Arn"] },
              "Export": {
                "Name": "SagebrushGithubSystemAccount-UserArn"
              }
            }
          }
        }
        """
}
