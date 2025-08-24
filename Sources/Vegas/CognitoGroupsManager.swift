struct CognitoGroupsManager: Stack {
    /// Manages Cognito User Pool groups and role mappings for RBAC
    /// Provides utilities for assigning users to groups and managing role-based access
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "Cognito Groups Manager for role-based access control",
          "Parameters": {
            "CognitoUserPoolId": {
              "Type": "String",
              "Description": "ID of the Cognito User Pool to manage groups for"
            },
            "CustomerRolePrecedence": {
              "Type": "Number",
              "Description": "Precedence value for customer role (higher number = lower precedence)",
              "Default": 3,
              "MinValue": 0,
              "MaxValue": 10
            },
            "StaffRolePrecedence": {
              "Type": "Number",
              "Description": "Precedence value for staff role",
              "Default": 2,
              "MinValue": 0,
              "MaxValue": 10
            },
            "AdminRolePrecedence": {
              "Type": "Number",
              "Description": "Precedence value for admin role (lower number = higher precedence)",
              "Default": 1,
              "MinValue": 0,
              "MaxValue": 10
            }
          },
          "Resources": {
            "CustomerGroup": {
              "Type": "AWS::Cognito::UserPoolGroup",
              "Properties": {
                "GroupName": "customer",
                "Description": "Customer role with basic access permissions",
                "UserPoolId": { "Ref": "CognitoUserPoolId" },
                "Precedence": { "Ref": "CustomerRolePrecedence" }
              }
            },
            "StaffGroup": {
              "Type": "AWS::Cognito::UserPoolGroup",
              "Properties": {
                "GroupName": "staff",
                "Description": "Staff role with elevated access permissions",
                "UserPoolId": { "Ref": "CognitoUserPoolId" },
                "Precedence": { "Ref": "StaffRolePrecedence" }
              }
            },
            "AdminGroup": {
              "Type": "AWS::Cognito::UserPoolGroup",
              "Properties": {
                "GroupName": "admin",
                "Description": "Administrator role with full access permissions",
                "UserPoolId": { "Ref": "CognitoUserPoolId" },
                "Precedence": { "Ref": "AdminRolePrecedence" }
              }
            },
            "UserGroupAssignmentFunction": {
              "Type": "AWS::Lambda::Function",
              "Properties": {
                "FunctionName": "cognito-user-group-assignment",
                "Runtime": "python3.11",
                "Handler": "index.lambda_handler",
                "Role": { "Fn::GetAtt": ["UserGroupAssignmentRole", "Arn"] },
                "Code": {
                  "ZipFile": {
                    "Fn::Sub": [
                      "import boto3\\nimport json\\n\\ndef lambda_handler(event, context):\\n    cognito_client = boto3.client('cognito-idp')\\n    \\n    user_pool_id = '${UserPoolId}'\\n    username = event.get('username')\\n    group_name = event.get('group_name', 'customer')\\n    \\n    if not username:\\n        return {\\n            'statusCode': 400,\\n            'body': json.dumps('Username is required')\\n        }\\n    \\n    try:\\n        # Add user to specified group\\n        cognito_client.admin_add_user_to_group(\\n            UserPoolId=user_pool_id,\\n            Username=username,\\n            GroupName=group_name\\n        )\\n        \\n        return {\\n            'statusCode': 200,\\n            'body': json.dumps(f'User {username} added to group {group_name}')\\n        }\\n    except Exception as e:\\n        return {\\n            'statusCode': 500,\\n            'body': json.dumps(f'Error adding user to group: {str(e)}')\\n        }\\n",
                      {
                        "UserPoolId": { "Ref": "CognitoUserPoolId" }
                      }
                    ]
                  }
                },
                "Description": "Lambda function for managing Cognito user group assignments",
                "Timeout": 30,
                "Tags": [
                  {
                    "Key": "Purpose",
                    "Value": "Cognito Group Management"
                  }
                ]
              }
            },
            "UserGroupAssignmentRole": {
              "Type": "AWS::IAM::Role",
              "Properties": {
                "AssumeRolePolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Principal": {
                        "Service": "lambda.amazonaws.com"
                      },
                      "Action": "sts:AssumeRole"
                    }
                  ]
                },
                "ManagedPolicyArns": [
                  "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
                ],
                "Policies": [
                  {
                    "PolicyName": "CognitoGroupManagement",
                    "PolicyDocument": {
                      "Version": "2012-10-17",
                      "Statement": [
                        {
                          "Effect": "Allow",
                          "Action": [
                            "cognito-idp:AdminAddUserToGroup",
                            "cognito-idp:AdminRemoveUserFromGroup",
                            "cognito-idp:AdminListGroupsForUser",
                            "cognito-idp:ListUsers",
                            "cognito-idp:ListGroups"
                          ],
                          "Resource": { "Fn::Sub": "arn:aws:cognito-idp:${AWS::Region}:${AWS::AccountId}:userpool/${CognitoUserPoolId}" }
                        }
                      ]
                    }
                  }
                ]
              }
            }
          },
          "Outputs": {
            "CustomerGroupArn": {
              "Description": "ARN of the customer group",
              "Value": { "Fn::GetAtt": ["CustomerGroup", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-CustomerGroupArn" }
              }
            },
            "StaffGroupArn": {
              "Description": "ARN of the staff group",
              "Value": { "Fn::GetAtt": ["StaffGroup", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-StaffGroupArn" }
              }
            },
            "AdminGroupArn": {
              "Description": "ARN of the admin group",
              "Value": { "Fn::GetAtt": ["AdminGroup", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-AdminGroupArn" }
              }
            },
            "UserGroupAssignmentFunctionArn": {
              "Description": "ARN of the Lambda function for user group assignments",
              "Value": { "Fn::GetAtt": ["UserGroupAssignmentFunction", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-UserGroupAssignmentFunctionArn" }
              }
            },
            "GroupNames": {
              "Description": "List of available group names for role mapping",
              "Value": "customer,staff,admin",
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-GroupNames" }
              }
            },
            "RolePrecedenceMapping": {
              "Description": "JSON mapping of roles to their precedence values",
              "Value": { "Fn::Sub": "{\"admin\": ${AdminRolePrecedence}, \"staff\": ${StaffRolePrecedence}, \"customer\": ${CustomerRolePrecedence}}" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RolePrecedenceMapping" }
              }
            }
          }
        }
        """
}
