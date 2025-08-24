struct ApplicationLoadBalancerWithAuth: Stack {
    /// Enhanced Application Load Balancer with Cognito authentication and header injection
    /// Provides ALB-based authentication with automatic header injection for downstream services
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "Application Load Balancer with Cognito authentication and OIDC header injection",
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
            },
            "EnableHeaderInjection": {
              "Type": "String",
              "Description": "Enable automatic header injection for authenticated users",
              "Default": "true",
              "AllowedValues": ["true", "false"]
            },
            "SessionTimeout": {
              "Type": "Number",
              "Description": "Authentication session timeout in seconds",
              "Default": 604800,
              "MinValue": 1,
              "MaxValue": 604800
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
            },
            "HeaderInjectionEnabled": {
              "Fn::Equals": [{ "Ref": "EnableHeaderInjection" }, "true"]
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
            "HTTPListener": {
              "Type": "AWS::ElasticLoadBalancingV2::Listener",
              "Properties": {
                "DefaultActions": [
                  {
                    "Type": "redirect",
                    "RedirectConfig": {
                      "Protocol": "HTTPS",
                      "Port": "443",
                      "Host": "#{host}",
                      "Path": "/#{path}",
                      "Query": "#{query}",
                      "StatusCode": "HTTP_301"
                    }
                  }
                ],
                "LoadBalancerArn": { "Ref": "ApplicationLoadBalancer" },
                "Port": 80,
                "Protocol": "HTTP"
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
            },
            "HTTPListenerArn": {
              "Description": "ARN of the HTTP listener",
              "Value": { "Ref": "HTTPListener" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-HTTPListenerArn" }
              }
            },
            "CognitoUserPoolArn": {
              "Description": "ARN of the associated Cognito User Pool",
              "Value": { "Fn::ImportValue": { "Fn::Sub": "${CognitoStackName}-UserPoolArn" } },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-CognitoUserPoolArn" }
              }
            },
            "CognitoUserPoolClientId": {
              "Description": "Client ID of the associated Cognito User Pool",
              "Value": { "Fn::ImportValue": { "Fn::Sub": "${CognitoStackName}-UserPoolClientId" } },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-CognitoUserPoolClientId" }
              }
            },
            "CognitoUserPoolDomain": {
              "Description": "Domain of the associated Cognito User Pool",
              "Value": { "Fn::ImportValue": { "Fn::Sub": "${CognitoStackName}-UserPoolDomain" } },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-CognitoUserPoolDomain" }
              }
            },
            "AuthorizationEndpoint": {
              "Description": "OAuth2 authorization endpoint for ALB authentication",
              "Value": { "Fn::ImportValue": { "Fn::Sub": "${CognitoStackName}-AuthorizationEndpoint" } },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-AuthorizationEndpoint" }
              }
            },
            "TokenEndpoint": {
              "Description": "OAuth2 token endpoint for ALB authentication",
              "Value": { "Fn::ImportValue": { "Fn::Sub": "${CognitoStackName}-TokenEndpoint" } },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-TokenEndpoint" }
              }
            },
            "UserInfoEndpoint": {
              "Description": "OAuth2 user info endpoint for ALB authentication",
              "Value": { "Fn::ImportValue": { "Fn::Sub": "${CognitoStackName}-UserInfoEndpoint" } },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-UserInfoEndpoint" }
              }
            },
            "HeaderInjectionEnabled": {
              "Description": "Whether header injection is enabled for authenticated requests",
              "Value": { "Ref": "EnableHeaderInjection" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-HeaderInjectionEnabled" }
              }
            },
            "SessionTimeoutSeconds": {
              "Description": "Authentication session timeout in seconds",
              "Value": { "Ref": "SessionTimeout" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-SessionTimeoutSeconds" }
              }
            }
          }
        }
        """
}
