struct RDS: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "RDS PostgreSQL database in VPC with private subnets",
          "Parameters": {
            "VPCStackName": {
              "Description": "Name of the VPC stack to reference",
              "Type": "String",
              "Default": "vpc-stack"
            },
            "DBUsername": {
              "Description": "Master username for the RDS instance",
              "Type": "String",
              "Default": "postgres",
              "MinLength": 1,
              "MaxLength": 16,
              "AllowedPattern": "[a-zA-Z][a-zA-Z0-9]*",
              "ConstraintDescription": "Must begin with a letter and contain only alphanumeric characters"
            },
            "DBPassword": {
              "Description": "Master password for the RDS instance",
              "Type": "String",
              "NoEcho": true,
              "MinLength": 8,
              "MaxLength": 41,
              "AllowedPattern": "[a-zA-Z0-9]*",
              "ConstraintDescription": "Must contain only alphanumeric characters and be between 8-41 characters"
            },
            "DBInstanceClass": {
              "Description": "RDS instance class",
              "Type": "String",
              "Default": "db.t3.micro",
              "AllowedValues": [
                "db.t3.micro",
                "db.t3.small",
                "db.t3.medium",
                "db.t3.large",
                "db.r5.large",
                "db.r5.xlarge"
              ]
            }
          },
          "Resources": {
            "DBSubnetGroup": {
              "Type": "AWS::RDS::DBSubnetGroup",
              "Properties": {
                "DBSubnetGroupDescription": "Subnet group for RDS database",
                "SubnetIds": {
                  "Fn::Split": [
                    ",",
                    {
                      "Fn::ImportValue": {
                        "Fn::Sub": "${VPCStackName}-SubnetsPrivate"
                      }
                    }
                  ]
                },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "RDS DB Subnet Group"
                  }
                ]
              }
            },
            "DBSecurityGroup": {
              "Type": "AWS::EC2::SecurityGroup",
              "Properties": {
                "GroupDescription": "Security group for RDS PostgreSQL database",
                "VpcId": {
                  "Fn::ImportValue": {
                    "Fn::Sub": "${VPCStackName}-VPC"
                  }
                },
                "SecurityGroupIngress": [
                  {
                    "IpProtocol": "tcp",
                    "FromPort": 5432,
                    "ToPort": 5432,
                    "CidrIp": {
                      "Fn::ImportValue": {
                        "Fn::Sub": "${VPCStackName}-CidrBlock"
                      }
                    },
                    "Description": "PostgreSQL access from VPC"
                  }
                ],
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "RDS PostgreSQL Security Group"
                  }
                ]
              }
            },
            "DBParameterGroup": {
              "Type": "AWS::RDS::DBParameterGroup",
              "Properties": {
                "Family": "postgres17",
                "Description": "PostgreSQL parameter group for optimization",
                "Parameters": {
                  "log_statement": "all",
                  "log_min_duration_statement": "1000"
                },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "PostgreSQL Parameter Group"
                  }
                ]
              }
            },
            "Database": {
              "Type": "AWS::RDS::DBInstance",
              "DeletionPolicy": "Snapshot",
              "Properties": {
                "DBInstanceIdentifier": {
                  "Fn::Sub": "${AWS::StackName}-postgres"
                },
                "DBName": "luxe",
                "Engine": "postgres",
                "EngineVersion": "17.2",
                "AutoMinorVersionUpgrade": true,
                "DBInstanceClass": {
                  "Ref": "DBInstanceClass"
                },
                "AllocatedStorage": 100,
                "StorageType": "gp3",
                "StorageEncrypted": true,
                "MasterUsername": {
                  "Ref": "DBUsername"
                },
                "MasterUserPassword": {
                  "Ref": "DBPassword"
                },
                "VPCSecurityGroups": [
                  {
                    "Ref": "DBSecurityGroup"
                  }
                ],
                "DBSubnetGroupName": {
                  "Ref": "DBSubnetGroup"
                },
                "DBParameterGroupName": {
                  "Ref": "DBParameterGroup"
                },
                "BackupRetentionPeriod": 7,
                "PreferredBackupWindow": "03:00-04:00",
                "PreferredMaintenanceWindow": "sun:04:00-sun:05:00",
                "MultiAZ": false,
                "PubliclyAccessible": false,
                "EnablePerformanceInsights": true,
                "PerformanceInsightsRetentionPeriod": 7,
                "DeletionProtection": false,
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "Luxe PostgreSQL Database"
                  }
                ]
              }
            }
          },
          "Outputs": {
            "DatabaseEndpoint": {
              "Description": "RDS PostgreSQL endpoint",
              "Value": {
                "Fn::GetAtt": [
                  "Database",
                  "Endpoint.Address"
                ]
              },
              "Export": {
                "Name": {
                  "Fn::Sub": "${AWS::StackName}-DatabaseEndpoint"
                }
              }
            },
            "DatabasePort": {
              "Description": "RDS PostgreSQL port",
              "Value": {
                "Fn::GetAtt": [
                  "Database",
                  "Endpoint.Port"
                ]
              },
              "Export": {
                "Name": {
                  "Fn::Sub": "${AWS::StackName}-DatabasePort"
                }
              }
            },
            "DatabaseName": {
              "Description": "Database name",
              "Value": "luxe",
              "Export": {
                "Name": {
                  "Fn::Sub": "${AWS::StackName}-DatabaseName"
                }
              }
            },
            "DBSubnetGroup": {
              "Description": "DB subnet group",
              "Value": {
                "Ref": "DBSubnetGroup"
              },
              "Export": {
                "Name": {
                  "Fn::Sub": "${AWS::StackName}-DBSubnetGroup"
                }
              }
            },
            "DBSecurityGroup": {
              "Description": "DB security group",
              "Value": {
                "Ref": "DBSecurityGroup"
              },
              "Export": {
                "Name": {
                  "Fn::Sub": "${AWS::StackName}-DBSecurityGroup"
                }
              }
            },
            "DBUsername": {
              "Description": "Database username",
              "Value": {
                "Ref": "DBUsername"
              },
              "Export": {
                "Name": {
                  "Fn::Sub": "${AWS::StackName}-DBUsername"
                }
              }
            },
            "DBPassword": {
              "Description": "Database password",
              "Value": {
                "Ref": "DBPassword"
              },
              "Export": {
                "Name": {
                  "Fn::Sub": "${AWS::StackName}-DBPassword"
                }
              }
            },
            "DatabaseURL": {
              "Description": "Complete PostgreSQL database URL",
              "Value": {
                "Fn::Join": [
                  "",
                  [
                    "postgresql://",
                    { "Ref": "DBUsername" },
                    ":",
                    { "Ref": "DBPassword" },
                    "@",
                    { "Fn::GetAtt": ["Database", "Endpoint.Address"] },
                    ":",
                    { "Fn::GetAtt": ["Database", "Endpoint.Port"] },
                    "/luxe?sslmode=require"
                  ]
                ]
              },
              "Export": {
                "Name": {
                  "Fn::Sub": "${AWS::StackName}-DatabaseURL"
                }
              }
            }
          }
        }
        """
}
