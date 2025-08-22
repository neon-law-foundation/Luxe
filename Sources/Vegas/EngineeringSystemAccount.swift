struct EngineeringSystemAccount: Stack {
    /// Create an IAM user with AdministratorAccess and an EC2 KeyPair for engineering access.
    /// The IAM key will be manually created and updated in Doppler.
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "IAM user with AdministratorAccess and EC2 KeyPair for engineering system access.",
          "Resources": {
            "EngineeringUser": {
              "Type": "AWS::IAM::User",
              "Properties": {
                "UserName": "engineering-system-account"
              }
            },
            "EngineeringUserAdministratorPolicy": {
              "Type": "AWS::IAM::Policy",
              "Properties": {
                "PolicyName": "EngineeringAdministratorAccessPolicy",
                "Users": [ { "Ref": "EngineeringUser" } ],
                "PolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Action": "*",
                      "Resource": "*"
                    }
                  ]
                }
              }
            },
            "EngineeringEC2KeyPair": {
              "Type": "AWS::EC2::KeyPair",
              "Properties": {
                "KeyName": "engineering-system-keypair",
                "KeyType": "rsa",
                "KeyFormat": "pem"
              }
            }
          },
          "Outputs": {
            "EngineeringUserName": {
              "Description": "Name of the engineering system account IAM user",
              "Value": { "Ref": "EngineeringUser" },
              "Export": {
                "Name": "EngineeringSystemAccount-UserName"
              }
            },
            "EngineeringUserArn": {
              "Description": "ARN of the engineering system account IAM user",
              "Value": { "Fn::GetAtt": ["EngineeringUser", "Arn"] },
              "Export": {
                "Name": "EngineeringSystemAccount-UserArn"
              }
            },
            "EngineeringEC2KeyPairName": {
              "Description": "Name of the engineering EC2 KeyPair",
              "Value": { "Ref": "EngineeringEC2KeyPair" },
              "Export": {
                "Name": "EngineeringSystemAccount-KeyPairName"
              }
            },
            "EngineeringEC2KeyPairId": {
              "Description": "ID of the engineering EC2 KeyPair",
              "Value": { "Fn::GetAtt": ["EngineeringEC2KeyPair", "KeyPairId"] },
              "Export": {
                "Name": "EngineeringSystemAccount-KeyPairId"
              }
            }
          }
        }
        """
}
