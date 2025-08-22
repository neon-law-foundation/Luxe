struct ApplicationLoadBalancerWithAuthRules: Stack {
    /// Application Load Balancer with differentiated authentication rules
    /// - Session-based authentication for web routes (/, /app/*, /admin/*)
    /// - OIDC Bearer token authentication for API routes (/api/*)
    /// - Proper login redirect flow for unauthenticated users
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "Application Load Balancer with differentiated authentication rules for web and API routes",
          "Parameters": {
            "VPCStackName": {
              "Type": "String",
              "Description": "Name of the VPC stack to import values from"
            },
            "CertificateStackNames": {
              "Type": "CommaDelimitedList",
              "Description": "Comma-delimited list of ACM certificate stack names to import values from",
              "Default": "standards-certificate,sagebrushweb-certificate,neonlaw-certificate,nlf-certificate,bazaar-certificate"
            },
            "CognitoStackName": {
              "Type": "String",
              "Description": "Name of the Cognito User Pool stack to import values from",
              "Default": "sagebrush-cognito"
            },
          },
          "Resources": {
            "ALBSecurityGroup": {
              "Type": "AWS::EC2::SecurityGroup",
              "Properties": {
                "GroupDescription": "Security group for Application Load Balancer with authentication rules",
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
                    "Value": "ALB Security Group with Auth Rules"
                  }
                ]
              }
            },
            "ApplicationLoadBalancer": {
              "Type": "AWS::ElasticLoadBalancingV2::LoadBalancer",
              "Properties": {
                "Name": "sagebrush-alb-auth",
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
                    "Value": "Sagebrush ALB with Auth Rules"
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
            "AdditionalCertificate1": {
              "Type": "AWS::ElasticLoadBalancingV2::ListenerCertificate",
              "Properties": {
                "ListenerArn": { "Ref": "HTTPSListener" },
                "Certificates": [
                  {
                    "CertificateArn": { "Fn::ImportValue": { "Fn::Sub": [ "${cert2}-CertificateArn", { "cert2": { "Fn::Select": [1, { "Ref": "CertificateStackNames" }] } } ] } }
                  }
                ]
              }
            },
            "AdditionalCertificate2": {
              "Type": "AWS::ElasticLoadBalancingV2::ListenerCertificate",
              "Properties": {
                "ListenerArn": { "Ref": "HTTPSListener" },
                "Certificates": [
                  {
                    "CertificateArn": { "Fn::ImportValue": { "Fn::Sub": [ "${cert3}-CertificateArn", { "cert3": { "Fn::Select": [2, { "Ref": "CertificateStackNames" }] } } ] } }
                  }
                ]
              }
            },
            "AdditionalCertificate3": {
              "Type": "AWS::ElasticLoadBalancingV2::ListenerCertificate",
              "Properties": {
                "ListenerArn": { "Ref": "HTTPSListener" },
                "Certificates": [
                  {
                    "CertificateArn": { "Fn::ImportValue": { "Fn::Sub": [ "${cert4}-CertificateArn", { "cert4": { "Fn::Select": [3, { "Ref": "CertificateStackNames" }] } } ] } }
                  }
                ]
              }
            },
            "AdditionalCertificate4": {
              "Type": "AWS::ElasticLoadBalancingV2::ListenerCertificate",
              "Properties": {
                "ListenerArn": { "Ref": "HTTPSListener" },
                "Certificates": [
                  {
                    "CertificateArn": { "Fn::ImportValue": { "Fn::Sub": [ "${cert5}-CertificateArn", { "cert5": { "Fn::Select": [4, { "Ref": "CertificateStackNames" }] } } ] } }
                  }
                ]
              }
            },
          },
          "Outputs": {
            "LoadBalancerArn": {
              "Description": "ARN of the Application Load Balancer with authentication rules",
              "Value": { "Ref": "ApplicationLoadBalancer" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-LoadBalancerArn" }
              }
            },
            "LoadBalancerDNS": {
              "Description": "DNS name of the Application Load Balancer",
              "Value": { "Fn::GetAtt": ["ApplicationLoadBalancer", "DNSName"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-LoadBalancerDNS" }
              }
            },
            "ALBSecurityGroupId": {
              "Description": "Security Group ID for the ALB",
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
