struct CognitoUserPoolWithALB: Stack {
    /// Enhanced Cognito User Pool specifically configured for ALB integration
    /// Extends the base user pool with ALB-specific OAuth configuration and additional endpoints
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "Cognito User Pool optimized for Application Load Balancer integration",
          "Parameters": {
            "UserPoolName": {
              "Type": "String",
              "Description": "Name of the Cognito User Pool",
              "Default": "sagebrush-alb-user-pool"
            },
            "DomainPrefix": {
              "Type": "String",
              "Description": "Domain prefix for the Cognito User Pool Domain",
              "Default": "sagebrush-alb-auth"
            },
            "ALBDomain": {
              "Type": "String",
              "Description": "Domain name where the ALB will be hosted",
              "Default": "www.sagebrush.services"
            },
            "BazaarDomain": {
              "Type": "String",
              "Description": "Domain name for the Bazaar application",
              "Default": "bazaar.sagebrush.services"
            }
          },
          "Resources": {
            "UserPool": {
              "Type": "AWS::Cognito::UserPool",
              "Properties": {
                "UserPoolName": { "Ref": "UserPoolName" },
                "AutoVerifiedAttributes": ["email"],
                "UsernameAttributes": ["email"],
                "UsernameConfiguration": {
                  "CaseSensitive": false
                },
                "Policies": {
                  "PasswordPolicy": {
                    "MinimumLength": 8,
                    "RequireUppercase": true,
                    "RequireLowercase": true,
                    "RequireNumbers": true,
                    "RequireSymbols": false
                  }
                },
                "Schema": [
                  {
                    "Name": "email",
                    "AttributeDataType": "String",
                    "Required": true,
                    "Mutable": true
                  },
                  {
                    "Name": "given_name",
                    "AttributeDataType": "String",
                    "Required": false,
                    "Mutable": true
                  },
                  {
                    "Name": "family_name",
                    "AttributeDataType": "String",
                    "Required": false,
                    "Mutable": true
                  },
                  {
                    "Name": "role",
                    "AttributeDataType": "String",
                    "Required": false,
                    "Mutable": true,
                    "DeveloperOnlyAttribute": false
                  }
                ],
                "UserAttributeUpdateSettings": {
                  "AttributesRequireVerificationBeforeUpdate": ["email"]
                },
                "AccountRecoverySetting": {
                  "RecoveryMechanisms": [
                    {
                      "Name": "verified_email",
                      "Priority": 1
                    }
                  ]
                },
                "AdminCreateUserConfig": {
                  "AllowAdminCreateUserOnly": false,
                  "InviteMessageAction": "EMAIL"
                }
              }
            },
            "UserPoolClient": {
              "Type": "AWS::Cognito::UserPoolClient",
              "Properties": {
                "UserPoolId": { "Ref": "UserPool" },
                "ClientName": "alb-integration-client",
                "GenerateSecret": true,
                "SupportedIdentityProviders": ["COGNITO"],
                "CallbackURLs": [
                  { "Fn::Sub": "https://${ALBDomain}/oauth2/idpresponse" },
                  { "Fn::Sub": "https://${BazaarDomain}/oauth2/idpresponse" }
                ],
                "LogoutURLs": [
                  { "Fn::Sub": "https://${ALBDomain}/logout" },
                  { "Fn::Sub": "https://${BazaarDomain}/logout" }
                ],
                "AllowedOAuthFlows": ["code"],
                "AllowedOAuthScopes": ["openid", "email", "profile"],
                "AllowedOAuthFlowsUserPoolClient": true,
                "ExplicitAuthFlows": [
                  "ALLOW_ADMIN_USER_PASSWORD_AUTH",
                  "ALLOW_USER_PASSWORD_AUTH",
                  "ALLOW_USER_SRP_AUTH",
                  "ALLOW_REFRESH_TOKEN_AUTH"
                ],
                "PreventUserExistenceErrors": "ENABLED",
                "EnableTokenRevocation": true,
                "RefreshTokenValidity": 30,
                "AccessTokenValidity": 60,
                "IdTokenValidity": 60,
                "TokenValidityUnits": {
                  "RefreshToken": "days",
                  "AccessToken": "minutes",
                  "IdToken": "minutes"
                }
              }
            },
            "UserPoolDomain": {
              "Type": "AWS::Cognito::UserPoolDomain",
              "Properties": {
                "Domain": { "Ref": "DomainPrefix" },
                "UserPoolId": { "Ref": "UserPool" }
              }
            },
            "CustomerGroup": {
              "Type": "AWS::Cognito::UserPoolGroup",
              "Properties": {
                "GroupName": "customer",
                "Description": "Customer role group for basic user access",
                "UserPoolId": { "Ref": "UserPool" },
                "Precedence": 3
              }
            },
            "StaffGroup": {
              "Type": "AWS::Cognito::UserPoolGroup",
              "Properties": {
                "GroupName": "staff",
                "Description": "Staff role group for elevated access",
                "UserPoolId": { "Ref": "UserPool" },
                "Precedence": 2
              }
            },
            "AdminGroup": {
              "Type": "AWS::Cognito::UserPoolGroup",
              "Properties": {
                "GroupName": "admin",
                "Description": "Administrator role group for full access",
                "UserPoolId": { "Ref": "UserPool" },
                "Precedence": 1
              }
            }
          },
          "Outputs": {
            "UserPoolId": {
              "Description": "ID of the ALB-integrated Cognito User Pool",
              "Value": { "Ref": "UserPool" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-UserPoolId" }
              }
            },
            "UserPoolArn": {
              "Description": "ARN of the ALB-integrated Cognito User Pool",
              "Value": { "Fn::GetAtt": ["UserPool", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-UserPoolArn" }
              }
            },
            "UserPoolClientId": {
              "Description": "Client ID of the ALB integration client",
              "Value": { "Ref": "UserPoolClient" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-UserPoolClientId" }
              }
            },
            "UserPoolClientSecret": {
              "Description": "Client Secret of the ALB integration client",
              "Value": { "Fn::GetAtt": ["UserPoolClient", "ClientSecret"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-UserPoolClientSecret" }
              }
            },
            "UserPoolDomain": {
              "Description": "Domain of the Cognito User Pool for ALB authentication",
              "Value": { "Ref": "UserPoolDomain" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-UserPoolDomain" }
              }
            },
            "AuthorizationEndpoint": {
              "Description": "OAuth2 authorization endpoint for ALB authentication",
              "Value": { "Fn::Sub": "https://${UserPoolDomain}.auth.${AWS::Region}.amazoncognito.com/oauth2/authorize" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-AuthorizationEndpoint" }
              }
            },
            "TokenEndpoint": {
              "Description": "OAuth2 token endpoint for ALB authentication",
              "Value": { "Fn::Sub": "https://${UserPoolDomain}.auth.${AWS::Region}.amazoncognito.com/oauth2/token" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-TokenEndpoint" }
              }
            },
            "UserInfoEndpoint": {
              "Description": "OAuth2 user info endpoint for ALB authentication",
              "Value": { "Fn::Sub": "https://${UserPoolDomain}.auth.${AWS::Region}.amazoncognito.com/oauth2/userInfo" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-UserInfoEndpoint" }
              }
            },
            "JWKSUri": {
              "Description": "JWKS URI for ALB token validation",
              "Value": { "Fn::Sub": "https://cognito-idp.${AWS::Region}.amazonaws.com/${UserPool}/.well-known/jwks.json" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-JWKSUri" }
              }
            },
            "IssuerUrl": {
              "Description": "OIDC issuer URL for ALB authentication",
              "Value": { "Fn::Sub": "https://cognito-idp.${AWS::Region}.amazonaws.com/${UserPool}" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-IssuerUrl" }
              }
            }
          }
        }
        """
}
