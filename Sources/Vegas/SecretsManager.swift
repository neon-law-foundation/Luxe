struct SecretsManager: Stack {
    /// Create AWS Secrets Manager secrets for database credentials and other sensitive data.
    /// This will create secrets and make them available for ECS services.
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "AWS Secrets Manager for database and application secrets",
          "Parameters": {
            "RDSStackName": {
              "Type": "String",
              "Description": "Name of the RDS stack to import database URL from"
            },
            "ElasticacheStackName": {
              "Type": "String",
              "Description": "Name of the Elasticache stack to import Redis URL from"
            }
          },
          "Resources": {
            "DatabaseSecret": {
              "Type": "AWS::SecretsManager::Secret",
              "Properties": {
                "Name": { "Fn::Sub": "${AWS::StackName}-database-credentials" },
                "Description": "Database credentials for PostgreSQL",
                "SecretString": {
                  "Fn::Join": [
                    "",
                    [
                      "{\\\"username\\\":\\\"",
                      { "Fn::ImportValue": { "Fn::Sub": "${RDSStackName}-DBUsername" } },
                      "\\\",\\\"password\\\":\\\"",
                      { "Fn::ImportValue": { "Fn::Sub": "${RDSStackName}-DBPassword" } },
                      "\\\",\\\"engine\\\":\\\"postgres\\\",\\\"host\\\":\\\"",
                      { "Fn::ImportValue": { "Fn::Sub": "${RDSStackName}-DatabaseEndpoint" } },
                      "\\\",\\\"port\\\":",
                      { "Fn::ImportValue": { "Fn::Sub": "${RDSStackName}-DatabasePort" } },
                      ",\\\"dbname\\\":\\\"luxe\\\",\\\"url\\\":\\\"",
                      { "Fn::ImportValue": { "Fn::Sub": "${RDSStackName}-DatabaseURL" } },
                      "\\\"}"
                    ]
                  ]
                },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "Database Credentials"
                  },
                  {
                    "Key": "Application",
                    "Value": "Luxe"
                  }
                ]
              }
            },
            "DatabaseSecretPolicy": {
              "Type": "AWS::SecretsManager::ResourcePolicy",
              "Properties": {
                "SecretId": { "Ref": "DatabaseSecret" },
                "ResourcePolicy": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Principal": {
                        "AWS": { "Fn::Sub": "arn:aws:iam::${AWS::AccountId}:root" }
                      },
                      "Action": "secretsmanager:GetSecretValue",
                      "Resource": "*",
                      "Condition": {
                        "StringEquals": {
                          "secretsmanager:ResourceTag/Application": "Luxe"
                        }
                      }
                    }
                  ]
                }
              }
            },
            "ApplicationSecret": {
              "Type": "AWS::SecretsManager::Secret",
              "Properties": {
                "Name": { "Fn::Sub": "${AWS::StackName}-application-secrets" },
                "Description": "Consolidated JSON secret containing all application configuration",
                "SecretString": {
                  "Fn::Join": [
                    "",
                    [
                      "{",
                      "\\\"DATABASE_URL\\\":\\\"",
                      { "Fn::ImportValue": { "Fn::Sub": "${RDSStackName}-DatabaseURL" } },
                      "\\\",",
                      "\\\"DB_USERNAME\\\":\\\"",
                      { "Fn::ImportValue": { "Fn::Sub": "${RDSStackName}-DBUsername" } },
                      "\\\",",
                      "\\\"DB_PASSWORD\\\":\\\"",
                      { "Fn::ImportValue": { "Fn::Sub": "${RDSStackName}-DBPassword" } },
                      "\\\",",
                      "\\\"DB_HOST\\\":\\\"",
                      { "Fn::ImportValue": { "Fn::Sub": "${RDSStackName}-DatabaseEndpoint" } },
                      "\\\",",
                      "\\\"DB_PORT\\\":",
                      { "Fn::ImportValue": { "Fn::Sub": "${RDSStackName}-DatabasePort" } },
                      ",",
                      "\\\"DB_NAME\\\":\\\"luxe\\\",",
                      "\\\"ENV\\\":\\\"PRODUCTION\\\"",
                      "}"
                    ]
                  ]
                },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "Application Secrets"
                  },
                  {
                    "Key": "Application",
                    "Value": "Luxe"
                  }
                ]
              }
            },
            "ApplicationSecretPolicy": {
              "Type": "AWS::SecretsManager::ResourcePolicy",
              "Properties": {
                "SecretId": { "Ref": "ApplicationSecret" },
                "ResourcePolicy": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Principal": {
                        "AWS": { "Fn::Sub": "arn:aws:iam::${AWS::AccountId}:root" }
                      },
                      "Action": "secretsmanager:GetSecretValue",
                      "Resource": "*",
                      "Condition": {
                        "StringEquals": {
                          "secretsmanager:ResourceTag/Application": "Luxe"
                        }
                      }
                    }
                  ]
                }
              }
            },
            "ECSTaskRole": {
              "Type": "AWS::IAM::Role",
              "Properties": {
                "RoleName": { "Fn::Sub": "${AWS::StackName}-ecs-task-role" },
                "AssumeRolePolicyDocument": {
                  "Version": "2012-10-17",
                  "Statement": [
                    {
                      "Effect": "Allow",
                      "Principal": {
                        "Service": "ecs-tasks.amazonaws.com"
                      },
                      "Action": "sts:AssumeRole"
                    }
                  ]
                },
                "Policies": [
                  {
                    "PolicyName": "SecretsManagerAccess",
                    "PolicyDocument": {
                      "Version": "2012-10-17",
                      "Statement": [
                        {
                          "Effect": "Allow",
                          "Action": [
                            "secretsmanager:GetSecretValue"
                          ],
                          "Resource": [
                            { "Ref": "ApplicationSecret" },
                            { "Ref": "DatabaseSecret" }
                          ]
                        }
                      ]
                    }
                  }
                ],
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "ECS Task Role for Secrets Access"
                  }
                ]
              }
            }
          },
          "Outputs": {
            "DatabaseSecretArn": {
              "Description": "ARN of the database secret",
              "Value": { "Ref": "DatabaseSecret" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-DatabaseSecretArn" }
              }
            },
            "DatabaseSecretName": {
              "Description": "Name of the database secret",
              "Value": { "Ref": "DatabaseSecret" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-DatabaseSecretName" }
              }
            },
            "ApplicationSecretArn": {
              "Description": "ARN of the consolidated application secrets",
              "Value": { "Ref": "ApplicationSecret" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-ApplicationSecretArn" }
              }
            },
            "ApplicationSecretName": {
              "Description": "Name of the consolidated application secrets",
              "Value": { "Ref": "ApplicationSecret" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-ApplicationSecretName" }
              }
            },
            "ECSTaskRoleArn": {
              "Description": "ARN of the ECS task role for secrets access",
              "Value": { "Fn::GetAtt": ["ECSTaskRole", "Arn"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-ECSTaskRoleArn" }
              }
            },
            "DatabaseURL": {
              "Description": "Database URL from imported RDS stack",
              "Value": {
                "Fn::ImportValue": {
                  "Fn::Sub": "${RDSStackName}-DatabaseURL"
                }
              },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-DatabaseURL" }
              }
            }
          }
        }
        """
}
