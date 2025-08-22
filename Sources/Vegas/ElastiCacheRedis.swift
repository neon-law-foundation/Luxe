/// ElastiCache Redis CloudFormation stack for production queue infrastructure
/// Provides managed Redis cluster for Vapor Queues in the Bazaar application
struct ElastiCacheRedis: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "ElastiCache Redis cluster for Vapor Queues job processing in production",
          "Parameters": {
            "VPCStackName": {
              "Type": "String",
              "Description": "Name of the VPC CloudFormation stack",
              "Default": "oregon-vpc"
            },
            "RedisPassword": {
              "Type": "String",
              "Description": "Password for Redis authentication",
              "NoEcho": true
            }
          },
          "Resources": {
            "CacheSubnetGroup": {
              "Type": "AWS::ElastiCache::SubnetGroup",
              "Properties": {
                "Description": "Subnet group for Redis cluster in private subnets",
                "SubnetIds": [
                  {
                    "Fn::ImportValue": {
                      "Fn::Sub": "${VPCStackName}-SubnetAPrivate"
                    }
                  },
                  {
                    "Fn::ImportValue": {
                      "Fn::Sub": "${VPCStackName}-SubnetBPrivate"
                    }
                  },
                  {
                    "Fn::ImportValue": {
                      "Fn::Sub": "${VPCStackName}-SubnetCPrivate"
                    }
                  }
                ]
              }
            },
            "SecurityGroup": {
              "Type": "AWS::EC2::SecurityGroup",
              "Properties": {
                "GroupDescription": "Security group for Redis cluster - allow access from VPC",
                "VpcId": {
                  "Fn::ImportValue": {
                    "Fn::Sub": "${VPCStackName}-VPC"
                  }
                },
                "SecurityGroupIngress": [
                  {
                    "IpProtocol": "tcp",
                    "FromPort": 6379,
                    "ToPort": 6379,
                    "CidrIp": {
                      "Fn::ImportValue": {
                        "Fn::Sub": "${VPCStackName}-CidrBlock"
                      }
                    },
                    "Description": "Redis access from VPC"
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
                    "Value": { "Fn::Sub": "${AWS::StackName}-redis-sg" }
                  },
                  {
                    "Key": "Purpose",
                    "Value": "ElastiCache Redis security"
                  }
                ]
              }
            },
            "CacheParameterGroup": {
              "Type": "AWS::ElastiCache::ParameterGroup",
              "Properties": {
                "CacheParameterGroupFamily": "redis7",
                "Description": "Custom parameter group for Vapor Queues Redis optimization",
                "Properties": {
                  "maxmemory-policy": "allkeys-lru",
                  "timeout": "300",
                  "tcp-keepalive": "300"
                }
              }
            },
            "ReplicationGroup": {
              "Type": "AWS::ElastiCache::ReplicationGroup",
              "DeletionPolicy": "Snapshot",
              "UpdateReplacePolicy": "Snapshot",
              "Properties": {
                "ReplicationGroupDescription": "Redis replication group for Vapor Queues job processing",
                "Engine": "redis",
                "EngineVersion": "7.0",
                "CacheNodeType": "cache.t3.micro",
                "NumNodeGroups": 1,
                "ReplicasPerNodeGroup": 0,
                "Port": 6379,
                "CacheParameterGroupName": { "Ref": "CacheParameterGroup" },
                "CacheSubnetGroupName": { "Ref": "CacheSubnetGroup" },
                "SecurityGroupIds": [
                  { "Ref": "SecurityGroup" }
                ],
                "MultiAZEnabled": false,
                "AutomaticFailoverEnabled": false,
                "AtRestEncryptionEnabled": true,
                "TransitEncryptionEnabled": true,
                "PreferredMaintenanceWindow": "sun:05:00-sun:09:00",
                "SnapshotRetentionLimit": 5,
                "SnapshotWindow": "03:00-05:00",
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Fn::Sub": "${AWS::StackName}-redis-cluster" }
                  },
                  {
                    "Key": "Purpose",
                    "Value": "Vapor Queues job processing"
                  },
                  {
                    "Key": "Application",
                    "Value": "Bazaar"
                  }
                ]
              }
            }
          },
          "Outputs": {
            "RedisEndpoint": {
              "Description": "Primary endpoint for Redis cluster",
              "Value": {
                "Fn::GetAtt": ["ReplicationGroup", "PrimaryEndPoint.Address"]
              },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RedisEndpoint" }
              }
            },
            "RedisPort": {
              "Description": "Port number for Redis cluster",
              "Value": {
                "Fn::GetAtt": ["ReplicationGroup", "PrimaryEndPoint.Port"]
              },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RedisPort" }
              }
            },
            "RedisSecurityGroup": {
              "Description": "Security group ID for Redis cluster",
              "Value": { "Ref": "SecurityGroup" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RedisSecurityGroup" }
              }
            },
            "RedisClusterId": {
              "Description": "Redis cluster identifier",
              "Value": { "Ref": "ReplicationGroup" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RedisClusterId" }
              }
            },
            "RedisConnectionString": {
              "Description": "Redis connection string format for applications",
              "Value": {
                "Fn::Sub": "redis://:${RedisPassword}@${ReplicationGroup.PrimaryEndPoint.Address}:${ReplicationGroup.PrimaryEndPoint.Port}/0"
              },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RedisConnectionString" }
              }
            }
          }
        }
        """
}
