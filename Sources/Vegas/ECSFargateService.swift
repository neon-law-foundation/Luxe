struct ECSFargateService: Stack {
    /// Create an ECS Fargate service with target group and listener rule for applications.
    /// Requires VPC, ALB, ACM certificate, and SecretsManager stacks to be deployed first.
    /// Supports database connectivity for all services.
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "ECS Fargate service for web applications with database support",
          "Parameters": {
            "VPCStackName": {
              "Type": "String",
              "Description": "Name of the VPC stack to import values from"
            },
            "ALBStackName": {
              "Type": "String",
              "Description": "Name of the ALB stack to import values from"
            },
            "CertificateStackName": {
              "Type": "String",
              "Description": "Name of the ACM certificate stack to import values from"
            },
            "SecretsStackName": {
              "Type": "String",
              "Description": "Name of the Secrets Manager stack to import values from"
            },
            "CognitoStackName": {
              "Type": "String",
              "Description": "Name of the Cognito User Pool stack to import values from",
              "Default": "sagebrush-cognito"
            },
            "RedisStackName": {
              "Type": "String",
              "Description": "Name of the Redis ElastiCache stack to import values from",
              "Default": "oregon-redis"
            },
            "ServiceName": {
              "Type": "String",
              "Description": "Name of the ECS service",
              "Default": "standards"
            },
            "ContainerImage": {
              "Type": "String",
              "Description": "Docker image URI for the container"
            },
            "ImageTag": {
              "Type": "String",
              "Description": "Docker image tag (version) to deploy",
              "Default": "latest"
            },
            "ContainerPort": {
              "Type": "Number",
              "Description": "Port the container listens on",
              "Default": 3000
            },
            "HostHeader": {
              "Type": "String",
              "Description": "Host header for ALB listener rule",
              "Default": "standards.sagebrush.services"
            },
            "ListenerRulePriority": {
              "Type": "Number",
              "Description": "Priority for the ALB listener rule",
              "Default": 100
            },
            "EnableDatabase": {
              "Type": "String",
              "Description": "Whether to include database environment variables",
              "Default": "true",
              "AllowedValues": ["true", "false"]
            }
          },
          "Conditions": {
            "DatabaseEnabled": {
              "Fn::Equals": [
                { "Ref": "EnableDatabase" },
                "true"
              ]
            }
          },
          "Resources": {
            "ECSCluster": {
              "Type": "AWS::ECS::Cluster",
              "Properties": {
                "ClusterName": { "Fn::Sub": "${ServiceName}-cluster" },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Fn::Sub": "${ServiceName} ECS Cluster" }
                  }
                ]
              }
            },
            "TaskExecutionRole": {
              "Type": "AWS::IAM::Role",
              "Properties": {
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
                "ManagedPolicyArns": [
                  "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
                ],
                "Policies": [
                  {
                    "Fn::If": [
                      "DatabaseEnabled",
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
                                {
                                  "Fn::ImportValue": {
                                    "Fn::Sub": "${SecretsStackName}-ApplicationSecretArn"
                                  }
                                }
                              ]
                            }
                          ]
                        }
                      },
                      { "Ref": "AWS::NoValue" }
                    ]
                  }
                ],
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Fn::Sub": "${ServiceName} Task Execution Role" }
                  }
                ]
              }
            },
            "TaskRole": {
              "Type": "AWS::IAM::Role",
              "Properties": {
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
                    "PolicyName": "PrivateS3Access",
                    "PolicyDocument": {
                      "Version": "2012-10-17",
                      "Statement": [
                        {
                          "Effect": "Allow",
                          "Action": [
                            "s3:GetObject",
                            "s3:PutObject",
                            "s3:DeleteObject",
                            "s3:ListBucket"
                          ],
                          "Resource": [
                            "arn:aws:s3:::sagebrush-private",
                            "arn:aws:s3:::sagebrush-private/*"
                          ]
                        }
                      ]
                    }
                  },
                  {
                    "PolicyName": "SESEmailAccess",
                    "PolicyDocument": {
                      "Version": "2012-10-17",
                      "Statement": [
                        {
                          "Effect": "Allow",
                          "Action": [
                            "ses:SendEmail",
                            "ses:SendRawEmail",
                            "ses:GetSendQuota",
                            "ses:GetSendStatistics",
                            "ses:GetAccountSendingEnabled",
                            "ses:ListIdentities",
                            "ses:GetIdentityVerificationAttributes"
                          ],
                          "Resource": [
                            { "Fn::Sub": "arn:aws:ses:${AWS::Region}:${AWS::AccountId}:identity/sagebrush.services" },
                            { "Fn::Sub": "arn:aws:ses:${AWS::Region}:${AWS::AccountId}:identity/support@sagebrush.services" }
                          ]
                        }
                      ]
                    }
                  }
                ],
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Fn::Sub": "${ServiceName} Task Role" }
                  }
                ]
              }
            },
            "TaskDefinition": {
              "Type": "AWS::ECS::TaskDefinition",
              "Properties": {
                "Family": { "Ref": "ServiceName" },
                "NetworkMode": "awsvpc",
                "RequiresCompatibilities": ["FARGATE"],
                "Cpu": "256",
                "Memory": "512",
                "ExecutionRoleArn": { "Ref": "TaskExecutionRole" },
                "TaskRoleArn": { "Ref": "TaskRole" },
                "ContainerDefinitions": [
                  {
                    "Name": { "Ref": "ServiceName" },
                    "Image": { "Ref": "ContainerImage" },
                    "PortMappings": [
                      {
                        "ContainerPort": { "Ref": "ContainerPort" },
                        "Protocol": "tcp"
                      }
                    ],
                    "Essential": true,
                    "Environment": {
                      "Fn::If": [
                        "DatabaseEnabled",
                        [
                          {
                            "Name": "REDIS_URL",
                            "Value": {
                              "Fn::Sub": [
                                "redis://${RedisEndpoint}:${RedisPort}",
                                {
                                  "RedisEndpoint": {
                                    "Fn::ImportValue": {
                                      "Fn::Sub": "${RedisStackName}-RedisEndpoint"
                                    }
                                  },
                                  "RedisPort": {
                                    "Fn::ImportValue": {
                                      "Fn::Sub": "${RedisStackName}-RedisPort"
                                    }
                                  }
                                }
                              ]
                            }
                          },
                          {
                            "Name": "AWS_REGION",
                            "Value": { "Ref": "AWS::Region" }
                          },
                          {
                            "Name": "COGNITO_CLIENT_ID",
                            "Value": {
                              "Fn::ImportValue": {
                                "Fn::Sub": "${CognitoStackName}-UserPoolClientId"
                              }
                            }
                          },
                          {
                            "Name": "COGNITO_CLIENT_SECRET",
                            "Value": {
                              "Fn::ImportValue": {
                                "Fn::Sub": "${CognitoStackName}-UserPoolClientSecret"
                              }
                            }
                          },
                          {
                            "Name": "COGNITO_ISSUER",
                            "Value": {
                              "Fn::Sub": [
                                "https://cognito-idp.${AWS::Region}.amazonaws.com/${UserPoolId}",
                                {
                                  "UserPoolId": {
                                    "Fn::ImportValue": {
                                      "Fn::Sub": "${CognitoStackName}-UserPoolId"
                                    }
                                  }
                                }
                              ]
                            }
                          },
                          {
                            "Name": "COGNITO_JWKS_URL",
                            "Value": {
                              "Fn::Sub": [
                                "https://cognito-idp.${AWS::Region}.amazonaws.com/${UserPoolId}/.well-known/jwks.json",
                                {
                                  "UserPoolId": {
                                    "Fn::ImportValue": {
                                      "Fn::Sub": "${CognitoStackName}-UserPoolId"
                                    }
                                  }
                                }
                              ]
                            }
                          }
                        ],
                        [
                          {
                            "Name": "REDIS_URL",
                            "Value": {
                              "Fn::Sub": [
                                "redis://${RedisEndpoint}:${RedisPort}",
                                {
                                  "RedisEndpoint": {
                                    "Fn::ImportValue": {
                                      "Fn::Sub": "${RedisStackName}-RedisEndpoint"
                                    }
                                  },
                                  "RedisPort": {
                                    "Fn::ImportValue": {
                                      "Fn::Sub": "${RedisStackName}-RedisPort"
                                    }
                                  }
                                }
                              ]
                            }
                          },
                          {
                            "Name": "AWS_REGION",
                            "Value": { "Ref": "AWS::Region" }
                          },
                          {
                            "Name": "COGNITO_CLIENT_ID",
                            "Value": {
                              "Fn::ImportValue": {
                                "Fn::Sub": "${CognitoStackName}-UserPoolClientId"
                              }
                            }
                          },
                          {
                            "Name": "COGNITO_CLIENT_SECRET",
                            "Value": {
                              "Fn::ImportValue": {
                                "Fn::Sub": "${CognitoStackName}-UserPoolClientSecret"
                              }
                            }
                          },
                          {
                            "Name": "COGNITO_ISSUER",
                            "Value": {
                              "Fn::Sub": [
                                "https://cognito-idp.${AWS::Region}.amazonaws.com/${UserPoolId}",
                                {
                                  "UserPoolId": {
                                    "Fn::ImportValue": {
                                      "Fn::Sub": "${CognitoStackName}-UserPoolId"
                                    }
                                  }
                                }
                              ]
                            }
                          },
                          {
                            "Name": "COGNITO_JWKS_URL",
                            "Value": {
                              "Fn::Sub": [
                                "https://cognito-idp.${AWS::Region}.amazonaws.com/${UserPoolId}/.well-known/jwks.json",
                                {
                                  "UserPoolId": {
                                    "Fn::ImportValue": {
                                      "Fn::Sub": "${CognitoStackName}-UserPoolId"
                                    }
                                  }
                                }
                              ]
                            }
                          }
                        ]
                      ]
                    },
                    "Secrets": {
                      "Fn::If": [
                        "DatabaseEnabled",
                        [
                          {
                            "Name": "DATABASE_URL",
                            "ValueFrom": {
                              "Fn::Sub": [
                                "${SecretArn}:DATABASE_URL::",
                                {
                                  "SecretArn": {
                                    "Fn::ImportValue": {
                                      "Fn::Sub": "${SecretsStackName}-ApplicationSecretArn"
                                    }
                                  }
                                }
                              ]
                            }
                          },
                          {
                            "Name": "ENV",
                            "ValueFrom": {
                              "Fn::Sub": [
                                "${SecretArn}:ENV::",
                                {
                                  "SecretArn": {
                                    "Fn::ImportValue": {
                                      "Fn::Sub": "${SecretsStackName}-ApplicationSecretArn"
                                    }
                                  }
                                }
                              ]
                            }
                          }
                        ],
                        []
                      ]
                    },
                    "LogConfiguration": {
                      "LogDriver": "awslogs",
                      "Options": {
                        "awslogs-group": { "Ref": "LogGroup" },
                        "awslogs-region": { "Ref": "AWS::Region" },
                        "awslogs-stream-prefix": "ecs"
                      }
                    }
                  }
                ],
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Fn::Sub": "${ServiceName} Task Definition" }
                  }
                ]
              }
            },
            "LogGroup": {
              "Type": "AWS::Logs::LogGroup",
              "Properties": {
                "LogGroupName": { "Fn::Sub": "/ecs/${ServiceName}" },
                "RetentionInDays": 30
              }
            },
            "ECSSecurityGroup": {
              "Type": "AWS::EC2::SecurityGroup",
              "Properties": {
                "GroupDescription": { "Fn::Sub": "Security group for ${ServiceName} ECS tasks" },
                "VpcId": { "Fn::ImportValue": { "Fn::Sub": "${VPCStackName}-VPC" } },
                "SecurityGroupIngress": [
                  {
                    "IpProtocol": "tcp",
                    "FromPort": { "Ref": "ContainerPort" },
                    "ToPort": { "Ref": "ContainerPort" },
                    "SourceSecurityGroupId": { "Fn::ImportValue": { "Fn::Sub": "${ALBStackName}-ALBSecurityGroupId" } },
                    "Description": "Allow traffic from ALB"
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
                    "Value": { "Fn::Sub": "${ServiceName} ECS Security Group" }
                  }
                ]
              }
            },
            "TargetGroup": {
              "Type": "AWS::ElasticLoadBalancingV2::TargetGroup",
              "Properties": {
                "Name": { "Fn::Sub": "${ServiceName}-targets" },
                "Port": { "Ref": "ContainerPort" },
                "Protocol": "HTTP",
                "TargetType": "ip",
                "VpcId": { "Fn::ImportValue": { "Fn::Sub": "${VPCStackName}-VPC" } },
                "HealthCheckEnabled": true,
                "HealthCheckIntervalSeconds": 30,
                "HealthCheckPath": "/health",
                "HealthCheckProtocol": "HTTP",
                "HealthCheckPort": { "Ref": "ContainerPort" },
                "HealthCheckTimeoutSeconds": 5,
                "HealthyThresholdCount": 2,
                "UnhealthyThresholdCount": 3,
                "Matcher": {
                  "HttpCode": "200"
                },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Fn::Sub": "${ServiceName} Target Group" }
                  }
                ]
              }
            },
            "ECSService": {
              "Type": "AWS::ECS::Service",
              "Properties": {
                "ServiceName": { "Ref": "ServiceName" },
                "Cluster": { "Ref": "ECSCluster" },
                "TaskDefinition": { "Ref": "TaskDefinition" },
                "LaunchType": "FARGATE",
                "DesiredCount": 1,
                "NetworkConfiguration": {
                  "AwsvpcConfiguration": {
                    "SecurityGroups": [
                      { "Ref": "ECSSecurityGroup" }
                    ],
                    "Subnets": { "Fn::Split": [",", { "Fn::ImportValue": { "Fn::Sub": "${VPCStackName}-SubnetsPublic" } }] },
                    "AssignPublicIp": "ENABLED"
                  }
                },
                "LoadBalancers": [
                  {
                    "TargetGroupArn": { "Ref": "TargetGroup" },
                    "ContainerName": { "Ref": "ServiceName" },
                    "ContainerPort": { "Ref": "ContainerPort" }
                  }
                ],
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Fn::Sub": "${ServiceName} ECS Service" }
                  }
                ]
              }
            },
            "ListenerRule": {
              "Type": "AWS::ElasticLoadBalancingV2::ListenerRule",
              "Properties": {
                "Actions": [
                  {
                    "Type": "forward",
                    "ForwardConfig": {
                      "TargetGroups": [
                        {
                          "TargetGroupArn": { "Ref": "TargetGroup" },
                          "Weight": 100
                        }
                      ]
                    }
                  }
                ],
                "Conditions": [
                  {
                    "Field": "host-header",
                    "Values": [
                      { "Ref": "HostHeader" }
                    ]
                  }
                ],
                "ListenerArn": { "Fn::ImportValue": { "Fn::Sub": "${ALBStackName}-HTTPSListenerArn" } },
                "Priority": { "Ref": "ListenerRulePriority" }
              }
            }
          },
          "Outputs": {
            "ClusterArn": {
              "Description": "ARN of the ECS cluster",
              "Value": { "Ref": "ECSCluster" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-ClusterArn" }
              }
            },
            "ServiceArn": {
              "Description": "ARN of the ECS service",
              "Value": { "Ref": "ECSService" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-ServiceArn" }
              }
            },
            "TargetGroupArn": {
              "Description": "ARN of the target group",
              "Value": { "Ref": "TargetGroup" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-TargetGroupArn" }
              }
            },
            "ServiceURL": {
              "Description": "URL where the service is accessible",
              "Value": {
                "Fn::Sub": "https://${HostHeader}"
              },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-ServiceURL" }
              }
            },
            "DeployedImageTag": {
              "Description": "Version/tag of the deployed Docker image",
              "Value": { "Ref": "ImageTag" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-DeployedImageTag" }
              }
            },
            "DeployedImage": {
              "Description": "Full Docker image URI that was deployed",
              "Value": { "Ref": "ContainerImage" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-DeployedImage" }
              }
            }
          }
        }
        """
}
