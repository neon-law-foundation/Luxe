struct BastionHost: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "EC2 bastion host for secure access to private VPC resources",
          "Parameters": {
            "VPCStackName": {
              "Type": "String",
              "Description": "Name of the VPC CloudFormation stack"
            },
            "KeyPairName": {
              "Type": "String",
              "Description": "EC2 Key Pair name for SSH access",
              "Default": "engineering-system-keypair"
            },
            "LatestAmiId": {
              "Type": "AWS::SSM::Parameter::Value<AWS::EC2::Image::Id>",
              "Default": "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2",
              "Description": "Latest Amazon Linux 2 AMI ID"
            }
          },
          "Resources": {
            "BastionSecurityGroup": {
              "Type": "AWS::EC2::SecurityGroup",
              "Properties": {
                "GroupDescription": "Security group for bastion host",
                "VpcId": {
                  "Fn::ImportValue": {
                    "Fn::Sub": "${VPCStackName}-VPC"
                  }
                },
                "SecurityGroupEgress": [
                  {
                    "IpProtocol": "tcp",
                    "FromPort": 5432,
                    "ToPort": 5432,
                    "CidrIp": "10.0.0.0/8"
                  },
                  {
                    "IpProtocol": "tcp",
                    "FromPort": 443,
                    "ToPort": 443,
                    "CidrIp": "0.0.0.0/0"
                  }
                ],
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "bastion-security-group"
                  }
                ]
              }
            },
            "BastionInstance": {
              "Type": "AWS::EC2::Instance",
              "Properties": {
                "ImageId": { "Ref": "LatestAmiId" },
                "InstanceType": "t3.nano",
                "KeyName": { "Ref": "KeyPairName" },
                "SecurityGroupIds": [
                  { "Ref": "BastionSecurityGroup" }
                ],
                "SubnetId": {
                  "Fn::ImportValue": {
                    "Fn::Sub": "${VPCStackName}-SubnetAPublic"
                  }
                },
                "IamInstanceProfile": { "Ref": "BastionInstanceProfile" },
                "UserData": {
                  "Fn::Base64": {
                    "Fn::Sub": [
                      "#!/bin/bash\\nyum update -y\\nyum install -y amazon-ssm-agent\\nsystemctl enable amazon-ssm-agent\\nsystemctl start amazon-ssm-agent\\n",
                      {}
                    ]
                  }
                },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "bastion-host"
                  }
                ]
              }
            },
            "BastionInstanceProfile": {
              "Type": "AWS::IAM::InstanceProfile",
              "Properties": {
                "Roles": [ { "Ref": "BastionRole" } ]
              }
            },
            "BastionRole": {
              "Type": "AWS::IAM::Role",
              "Properties": {
                "AssumeRolePolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Principal": {
                        "Service": "ec2.amazonaws.com"
                      },
                      "Action": "sts:AssumeRole"
                    }
                  ]
                },
                "ManagedPolicyArns": [
                  "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
                ]
              }
            }
          },
          "Outputs": {
            "BastionInstanceId": {
              "Description": "Instance ID of the bastion host",
              "Value": { "Ref": "BastionInstance" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-BastionInstanceId" }
              }
            },
            "BastionSecurityGroupId": {
              "Description": "Security group ID of the bastion host",
              "Value": { "Ref": "BastionSecurityGroup" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-BastionSecurityGroupId" }
              }
            }
          }
        }
        """
}
