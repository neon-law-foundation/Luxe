struct OhioVPC: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "Ohio VPC: Bare bones VPC for GitHub Actions runners via Hyperenv",
          "Parameters": {
            "ClassB": {
              "Description": "Class B of VPC (10.XXX.0.0/16)",
              "Type": "Number",
              "Default": 222,
              "ConstraintDescription": "Must be in the range [0-255]",
              "MinValue": 0,
              "MaxValue": 255
            }
          },
          "Resources": {
            "VPC": {
              "Type": "AWS::EC2::VPC",
              "Properties": {
                "CidrBlock": { "Fn::Sub": "10.${ClassB}.0.0/16" },
                "EnableDnsSupport": true,
                "EnableDnsHostnames": true,
                "InstanceTenancy": "default",
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Fn::Sub": "10.${ClassB}.0.0/16" }
                  },
                  {
                    "Key": "Purpose",
                    "Value": "GitHub Actions runners via Hyperenv"
                  }
                ]
              }
            },
            "InternetGateway": {
              "Type": "AWS::EC2::InternetGateway",
              "Properties": {
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Fn::Sub": "10.${ClassB}.0.0/16-igw" }
                  },
                  {
                    "Key": "Purpose",
                    "Value": "Internet access for GitHub Actions runners"
                  }
                ]
              }
            },
            "VPCGatewayAttachment": {
              "Type": "AWS::EC2::VPCGatewayAttachment",
              "Properties": {
                "VpcId": { "Ref": "VPC" },
                "InternetGatewayId": { "Ref": "InternetGateway" }
              }
            },
            "SubnetPublic": {
              "Type": "AWS::EC2::Subnet",
              "Properties": {
                "AvailabilityZone": { "Fn::Select": [0, { "Fn::GetAZs": "" }] },
                "CidrBlock": { "Fn::Sub": "10.${ClassB}.0.0/24" },
                "MapPublicIpOnLaunch": true,
                "VpcId": { "Ref": "VPC" },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "GitHub Actions Public Subnet"
                  },
                  {
                    "Key": "Purpose",
                    "Value": "Public subnet for GitHub Actions runners"
                  }
                ]
              }
            },
            "RouteTablePublic": {
              "Type": "AWS::EC2::RouteTable",
              "Properties": {
                "VpcId": { "Ref": "VPC" },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "GitHub Actions Public Route Table"
                  },
                  {
                    "Key": "Purpose",
                    "Value": "Route table for GitHub Actions public subnet"
                  }
                ]
              }
            },
            "RouteTableAssociationPublic": {
              "Type": "AWS::EC2::SubnetRouteTableAssociation",
              "Properties": {
                "SubnetId": { "Ref": "SubnetPublic" },
                "RouteTableId": { "Ref": "RouteTablePublic" }
              }
            },
            "RouteTablePublicInternetRoute": {
              "Type": "AWS::EC2::Route",
              "DependsOn": "VPCGatewayAttachment",
              "Properties": {
                "RouteTableId": { "Ref": "RouteTablePublic" },
                "DestinationCidrBlock": "0.0.0.0/0",
                "GatewayId": { "Ref": "InternetGateway" }
              }
            }
          },
          "Outputs": {
            "VPC": {
              "Description": "VPC ID for GitHub Actions runners",
              "Value": { "Ref": "VPC" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-VPC" }
              }
            },
            "SubnetPublic": {
              "Description": "Public subnet for GitHub Actions runners",
              "Value": { "Ref": "SubnetPublic" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-SubnetPublic" }
              }
            },
            "CidrBlock": {
              "Description": "The CIDR block for the VPC",
              "Value": { "Fn::GetAtt": ["VPC", "CidrBlock"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-CidrBlock" }
              }
            },
            "InternetGateway": {
              "Description": "Internet Gateway for public access",
              "Value": { "Ref": "InternetGateway" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-InternetGateway" }
              }
            }
          }
        }
        """
}
