struct ALBListenerRules: Stack {
    /// ALB listener rules with differentiated authentication for public and protected paths
    /// Implements path-based routing with Cognito authentication for protected routes
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "ALB Listener Rules with Cognito authentication routing",
          "Parameters": {
            "LoadBalancerArn": {
              "Type": "String",
              "Description": "ARN of the Application Load Balancer"
            },
            "HTTPSListenerArn": {
              "Type": "String",
              "Description": "ARN of the HTTPS listener to attach rules to"
            },
            "TargetGroupArn": {
              "Type": "String",
              "Description": "ARN of the target group to forward traffic to"
            },
            "CognitoUserPoolArn": {
              "Type": "String",
              "Description": "ARN of the Cognito User Pool for authentication"
            },
            "CognitoUserPoolClientId": {
              "Type": "String",
              "Description": "Client ID of the Cognito User Pool client"
            },
            "CognitoUserPoolDomain": {
              "Type": "String",
              "Description": "Domain of the Cognito User Pool"
            },
            "AuthenticationRequestExtraParams": {
              "Type": "String",
              "Description": "Extra parameters for authentication requests",
              "Default": "{}"
            },
            "OnUnauthenticatedRequest": {
              "Type": "String",
              "Description": "Action when request is unauthenticated",
              "Default": "authenticate",
              "AllowedValues": ["authenticate", "allow", "deny"]
            },
            "Scope": {
              "Type": "String",
              "Description": "OAuth scopes for authentication",
              "Default": "openid email profile"
            },
            "SessionCookieName": {
              "Type": "String",
              "Description": "Name of the session cookie",
              "Default": "AWSELBAuthSessionCookie"
            },
            "SessionTimeout": {
              "Type": "Number",
              "Description": "Session timeout in seconds",
              "Default": 604800,
              "MinValue": 1,
              "MaxValue": 604800
            }
          },
          "Resources": {
            "PublicPathRule": {
              "Type": "AWS::ElasticLoadBalancingV2::ListenerRule",
              "Properties": {
                "ListenerArn": { "Ref": "HTTPSListenerArn" },
                "Priority": 100,
                "Conditions": [
                  {
                    "Field": "path-pattern",
                    "Values": ["/", "/health", "/assets/*", "/favicon.ico", "/robots.txt"]
                  }
                ],
                "Actions": [
                  {
                    "Type": "forward",
                    "TargetGroupArn": { "Ref": "TargetGroupArn" }
                  }
                ]
              }
            },
            "ProtectedWebPathRule": {
              "Type": "AWS::ElasticLoadBalancingV2::ListenerRule",
              "Properties": {
                "ListenerArn": { "Ref": "HTTPSListenerArn" },
                "Priority": 200,
                "Conditions": [
                  {
                    "Field": "path-pattern",
                    "Values": ["/app/*", "/admin/*", "/dashboard/*"]
                  }
                ],
                "Actions": [
                  {
                    "Type": "authenticate-cognito",
                    "AuthenticateCognitoConfig": {
                      "UserPoolArn": { "Ref": "CognitoUserPoolArn" },
                      "UserPoolClientId": { "Ref": "CognitoUserPoolClientId" },
                      "UserPoolDomain": { "Ref": "CognitoUserPoolDomain" },
                      "AuthenticationRequestExtraParams": { "Ref": "AuthenticationRequestExtraParams" },
                      "OnUnauthenticatedRequest": { "Ref": "OnUnauthenticatedRequest" },
                      "Scope": { "Ref": "Scope" },
                      "SessionCookieName": { "Ref": "SessionCookieName" },
                      "SessionTimeout": { "Ref": "SessionTimeout" }
                    },
                    "Order": 1
                  },
                  {
                    "Type": "forward",
                    "TargetGroupArn": { "Ref": "TargetGroupArn" },
                    "Order": 2
                  }
                ]
              }
            },
            "APIPathRule": {
              "Type": "AWS::ElasticLoadBalancingV2::ListenerRule",
              "Properties": {
                "ListenerArn": { "Ref": "HTTPSListenerArn" },
                "Priority": 300,
                "Conditions": [
                  {
                    "Field": "path-pattern",
                    "Values": ["/api/*"]
                  }
                ],
                "Actions": [
                  {
                    "Type": "authenticate-cognito",
                    "AuthenticateCognitoConfig": {
                      "UserPoolArn": { "Ref": "CognitoUserPoolArn" },
                      "UserPoolClientId": { "Ref": "CognitoUserPoolClientId" },
                      "UserPoolDomain": { "Ref": "CognitoUserPoolDomain" },
                      "OnUnauthenticatedRequest": "deny",
                      "Scope": { "Ref": "Scope" },
                      "SessionCookieName": { "Ref": "SessionCookieName" },
                      "SessionTimeout": { "Ref": "SessionTimeout" }
                    },
                    "Order": 1
                  },
                  {
                    "Type": "forward",
                    "TargetGroupArn": { "Ref": "TargetGroupArn" },
                    "Order": 2
                  }
                ]
              }
            },
            "LogoutRule": {
              "Type": "AWS::ElasticLoadBalancingV2::ListenerRule",
              "Properties": {
                "ListenerArn": { "Ref": "HTTPSListenerArn" },
                "Priority": 150,
                "Conditions": [
                  {
                    "Field": "path-pattern",
                    "Values": ["/logout"]
                  }
                ],
                "Actions": [
                  {
                    "Type": "redirect",
                    "RedirectConfig": {
                      "Protocol": "HTTPS",
                      "Host": "#{host}",
                      "Path": "/",
                      "Query": "#{query}",
                      "StatusCode": "HTTP_302"
                    }
                  }
                ]
              }
            }
          },
          "Outputs": {
            "PublicPathRuleArn": {
              "Description": "ARN of the public path listener rule",
              "Value": { "Ref": "PublicPathRule" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-PublicPathRuleArn" }
              }
            },
            "ProtectedWebPathRuleArn": {
              "Description": "ARN of the protected web path listener rule",
              "Value": { "Ref": "ProtectedWebPathRule" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-ProtectedWebPathRuleArn" }
              }
            },
            "APIPathRuleArn": {
              "Description": "ARN of the API path listener rule",
              "Value": { "Ref": "APIPathRule" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-APIPathRuleArn" }
              }
            },
            "LogoutRuleArn": {
              "Description": "ARN of the logout listener rule",
              "Value": { "Ref": "LogoutRule" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-LogoutRuleArn" }
              }
            }
          }
        }
        """
}
