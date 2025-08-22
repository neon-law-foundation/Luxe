struct CognitoUserPool: Stack {
    /// Create a Cognito User Pool for OIDC authentication
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "Cognito User Pool for OIDC authentication",
          "Parameters": {
            "UserPoolName": {
              "Type": "String",
              "Description": "Name of the Cognito User Pool",
              "Default": "sagebrush-user-pool"
            },
            "DomainPrefix": {
              "Type": "String",
              "Description": "Domain prefix for the Cognito User Pool Domain",
              "Default": "sagebrush-auth"
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
                }
              }
            },
            "UserPoolClient": {
              "Type": "AWS::Cognito::UserPoolClient",
              "Properties": {
                "UserPoolId": { "Ref": "UserPool" },
                "ClientName": "sagebrush-alb-client",
                "GenerateSecret": true,
                "SupportedIdentityProviders": ["COGNITO"],
                "CallbackURLs": [
                  "https://www.sagebrush.services/oauth2/idpresponse",
                  "https://bazaar.sagebrush.services/oauth2/idpresponse"
                ],
                "LogoutURLs": [
                  "https://www.sagebrush.services/logout",
                  "https://bazaar.sagebrush.services/logout"
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
            }
          },
          "Outputs": {
            "UserPoolId": {
              "Description": "ID of the Cognito User Pool",
              "Value": { "Ref": "UserPool" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-UserPoolId" }
              }
            },
            "UserPoolArn": {
              "Description": "ARN of the Cognito User Pool",
              "Value": { "Fn::GetAtt": ["UserPool", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-UserPoolArn" }
              }
            },
            "UserPoolClientId": {
              "Description": "Client ID of the Cognito User Pool Client",
              "Value": { "Ref": "UserPoolClient" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-UserPoolClientId" }
              }
            },
            "UserPoolClientSecret": {
              "Description": "Client Secret of the Cognito User Pool Client",
              "Value": { "Fn::GetAtt": ["UserPoolClient", "ClientSecret"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-UserPoolClientSecret" }
              }
            },
            "UserPoolDomain": {
              "Description": "Domain of the Cognito User Pool",
              "Value": { "Ref": "UserPoolDomain" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-UserPoolDomain" }
              }
            },
            "AuthorizationEndpoint": {
              "Description": "Authorization endpoint URL",
              "Value": { "Fn::Sub": "https://${UserPoolDomain}.auth.${AWS::Region}.amazoncognito.com/oauth2/authorize" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-AuthorizationEndpoint" }
              }
            },
            "TokenEndpoint": {
              "Description": "Token endpoint URL",
              "Value": { "Fn::Sub": "https://${UserPoolDomain}.auth.${AWS::Region}.amazoncognito.com/oauth2/token" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-TokenEndpoint" }
              }
            },
            "UserInfoEndpoint": {
              "Description": "User info endpoint URL",
              "Value": { "Fn::Sub": "https://${UserPoolDomain}.auth.${AWS::Region}.amazoncognito.com/oauth2/userInfo" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-UserInfoEndpoint" }
              }
            },
            "JWKSUri": {
              "Description": "JWKS URI for token validation",
              "Value": { "Fn::Sub": "https://cognito-idp.${AWS::Region}.amazonaws.com/${UserPool}/.well-known/jwks.json" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-JWKSUri" }
              }
            }
          }
        }
        """
}
