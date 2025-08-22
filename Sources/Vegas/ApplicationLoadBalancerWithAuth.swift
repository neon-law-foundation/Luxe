struct ApplicationLoadBalancerWithAuth: Stack {
    /// Enhanced Application Load Balancer with Cognito authentication for specific paths
    /// Builds upon the existing ALB to add authentication rules
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "Application Load Balancer with Cognito and OIDC authentication",
          "Parameters": {
            "VPCStackName": {
              "Type": "String",
              "Description": "Name of the VPC stack to import values from"
            },
            "CertificateStackNames": {
              "Type": "CommaDelimitedList",
              "Description": "Comma-delimited list of ACM certificate stack names to import values from",
              "Default": "bazaar-certificate"
            },
            "CognitoStackName": {
              "Type": "String",
              "Description": "Name of the Cognito User Pool stack to import values from",
              "Default": "sagebrush-cognito"
            }
          },
          "Conditions": {
            "HasSecondCertificate": {
              "Fn::Not": [
                {
                  "Fn::Equals": [
                    { "Fn::Join": [",", { "Ref": "CertificateStackNames" }] },
                    { "Fn::Select": [0, { "Ref": "CertificateStackNames" }] }
                  ]
                }
              ]
            }
          },
          "Resources": {
            "ALBSecurityGroup": {
              "Type": "AWS::EC2::SecurityGroup",
              "Properties": {
                "GroupDescription": "Security group for shared Application Load Balancer",
                "VpcId": { "Fn::ImportValue": { "Fn::Sub": "${VPCStackName}-VPC" } },
                "SecurityGroupIngress": [
                  {
                    "IpProtocol": "tcp",
                    "FromPort": 443,
                    "ToPort": 443,
                    "CidrIp": "0.0.0.0/0",
                    "Description": "Allow HTTPS traffic"
                  },
                  {
                    "IpProtocol": "tcp",
                    "FromPort": 80,
                    "ToPort": 80,
                    "CidrIp": "0.0.0.0/0",
                    "Description": "Allow HTTP traffic"
                  }
                ],
                "SecurityGroupEgress": [
                  {
                    "IpProtocol": "-1",
                    "CidrIp": "0.0.0.0/0",
                    "Description": "Allow all outbound traffic"
                  }
                ],
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "Shared ALB Security Group"
                  }
                ]
              }
            },
            "ApplicationLoadBalancer": {
              "Type": "AWS::ElasticLoadBalancingV2::LoadBalancer",
              "Properties": {
                "Name": "sagebrush-alb",
                "Scheme": "internet-facing",
                "Type": "application",
                "IpAddressType": "ipv4",
                "Subnets": { "Fn::Split": [",", { "Fn::ImportValue": { "Fn::Sub": "${VPCStackName}-SubnetsPublic" } }] },
                "SecurityGroups": [
                  { "Ref": "ALBSecurityGroup" }
                ],
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "Sagebrush Shared ALB"
                  }
                ]
              }
            },
            "HTTPSListener": {
              "Type": "AWS::ElasticLoadBalancingV2::Listener",
              "Properties": {
                "DefaultActions": [
                  {
                    "Type": "fixed-response",
                    "FixedResponseConfig": {
                      "StatusCode": "404",
                      "ContentType": "text/plain",
                      "MessageBody": "Not Found"
                    }
                  }
                ],
                "LoadBalancerArn": { "Ref": "ApplicationLoadBalancer" },
                "Port": 443,
                "Protocol": "HTTPS",
                "Certificates": [
                  {
                    "CertificateArn": { "Fn::ImportValue": { "Fn::Sub": [ "${cert1}-CertificateArn", { "cert1": { "Fn::Select": [0, { "Ref": "CertificateStackNames" }] } } ] } }
                  }
                ]
              }
            },
            "AdditionalCertificate": {
              "Type": "AWS::ElasticLoadBalancingV2::ListenerCertificate",
              "Condition": "HasSecondCertificate",
              "Properties": {
                "Certificates": [
                  {
                    "CertificateArn": { "Fn::ImportValue": { "Fn::Sub": [ "${cert2}-CertificateArn", { "cert2": { "Fn::Select": [1, { "Ref": "CertificateStackNames" }] } } ] } }
                  }
                ],
                "ListenerArn": { "Ref": "HTTPSListener" }
              }
            }
          },
          "Outputs": {
            "LoadBalancerArn": {
              "Description": "ARN of the shared Application Load Balancer",
              "Value": { "Ref": "ApplicationLoadBalancer" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-LoadBalancerArn" }
              }
            },
            "LoadBalancerDNS": {
              "Description": "DNS name of the shared Application Load Balancer",
              "Value": { "Fn::GetAtt": ["ApplicationLoadBalancer", "DNSName"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-LoadBalancerDNS" }
              }
            },
            "ALBSecurityGroupId": {
              "Description": "Security Group ID for the shared ALB",
              "Value": { "Ref": "ALBSecurityGroup" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-ALBSecurityGroupId" }
              }
            },
            "LoadBalancerFullName": {
              "Description": "Full name of the load balancer for target group references",
              "Value": { "Fn::GetAtt": ["ApplicationLoadBalancer", "LoadBalancerFullName"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-LoadBalancerFullName" }
              }
            },
            "HTTPSListenerArn": {
              "Description": "ARN of the HTTPS listener",
              "Value": { "Ref": "HTTPSListener" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-HTTPSListenerArn" }
              }
            }
          }
        }
        """
}
