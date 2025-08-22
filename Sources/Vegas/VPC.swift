struct VPC: Stack {
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "VPC: public and private subnets in three availability zones, a cloudonaut.io template",
          "Parameters": {
            "ClassB": {
              "Description": "Class B of VPC (10.XXX.0.0/16)",
              "Type": "Number",
              "Default": 0,
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
                  }
                ]
              }
            },
            "VPCCidrBlock": {
              "Type": "AWS::EC2::VPCCidrBlock",
              "Properties": {
                "AmazonProvidedIpv6CidrBlock": true,
                "VpcId": { "Ref": "VPC" }
              }
            },
            "InternetGateway": {
              "Type": "AWS::EC2::InternetGateway",
              "Properties": {
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Fn::Sub": "10.${ClassB}.0.0/16" }
                  }
                ]
              }
            },
            "EgressOnlyInternetGateway": {
              "Type": "AWS::EC2::EgressOnlyInternetGateway",
              "Properties": {
                "VpcId": { "Ref": "VPC" }
              }
            },
            "VPCGatewayAttachment": {
              "Type": "AWS::EC2::VPCGatewayAttachment",
              "Properties": {
                "VpcId": { "Ref": "VPC" },
                "InternetGatewayId": { "Ref": "InternetGateway" }
              }
            },
            "SubnetAPublic": {
              "DependsOn": "VPCCidrBlock",
              "Type": "AWS::EC2::Subnet",
              "Properties": {
                "AvailabilityZone": { "Fn::Select": [0, { "Fn::GetAZs": "" }] },
                "CidrBlock": { "Fn::Sub": "10.${ClassB}.0.0/20" },
                "Ipv6CidrBlock": { "Fn::Select": [0, { "Fn::Cidr": [{ "Fn::Select": [0, { "Fn::GetAtt": ["VPC", "Ipv6CidrBlocks"] }] }, 6, 64] }] },
                "MapPublicIpOnLaunch": true,
                "VpcId": { "Ref": "VPC" },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "A public"
                  },
                  {
                    "Key": "Reach",
                    "Value": "public"
                  }
                ]
              }
            },
            "SubnetAPrivate": {
              "DependsOn": "VPCCidrBlock",
              "Type": "AWS::EC2::Subnet",
              "Properties": {
                "AssignIpv6AddressOnCreation": false,
                "AvailabilityZone": { "Fn::Select": [0, { "Fn::GetAZs": "" }] },
                "CidrBlock": { "Fn::Sub": "10.${ClassB}.16.0/20" },
                "Ipv6CidrBlock": { "Fn::Select": [1, { "Fn::Cidr": [{ "Fn::Select": [0, { "Fn::GetAtt": ["VPC", "Ipv6CidrBlocks"] }] }, 6, 64] }] },
                "VpcId": { "Ref": "VPC" },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "A private"
                  },
                  {
                    "Key": "Reach",
                    "Value": "private"
                  }
                ]
              }
            },
            "SubnetBPublic": {
              "DependsOn": "VPCCidrBlock",
              "Type": "AWS::EC2::Subnet",
              "Properties": {
                "AvailabilityZone": { "Fn::Select": [1, { "Fn::GetAZs": "" }] },
                "CidrBlock": { "Fn::Sub": "10.${ClassB}.32.0/20" },
                "Ipv6CidrBlock": { "Fn::Select": [2, { "Fn::Cidr": [{ "Fn::Select": [0, { "Fn::GetAtt": ["VPC", "Ipv6CidrBlocks"] }] }, 6, 64] }] },
                "MapPublicIpOnLaunch": true,
                "VpcId": { "Ref": "VPC" },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "B public"
                  },
                  {
                    "Key": "Reach",
                    "Value": "public"
                  }
                ]
              }
            },
            "SubnetBPrivate": {
              "DependsOn": "VPCCidrBlock",
              "Type": "AWS::EC2::Subnet",
              "Properties": {
                "AssignIpv6AddressOnCreation": false,
                "AvailabilityZone": { "Fn::Select": [1, { "Fn::GetAZs": "" }] },
                "CidrBlock": { "Fn::Sub": "10.${ClassB}.48.0/20" },
                "Ipv6CidrBlock": { "Fn::Select": [3, { "Fn::Cidr": [{ "Fn::Select": [0, { "Fn::GetAtt": ["VPC", "Ipv6CidrBlocks"] }] }, 6, 64] }] },
                "VpcId": { "Ref": "VPC" },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "B private"
                  },
                  {
                    "Key": "Reach",
                    "Value": "private"
                  }
                ]
              }
            },
            "SubnetCPublic": {
              "DependsOn": "VPCCidrBlock",
              "Type": "AWS::EC2::Subnet",
              "Properties": {
                "AvailabilityZone": { "Fn::Select": [2, { "Fn::GetAZs": "" }] },
                "CidrBlock": { "Fn::Sub": "10.${ClassB}.64.0/20" },
                "Ipv6CidrBlock": { "Fn::Select": [4, { "Fn::Cidr": [{ "Fn::Select": [0, { "Fn::GetAtt": ["VPC", "Ipv6CidrBlocks"] }] }, 6, 64] }] },
                "MapPublicIpOnLaunch": true,
                "VpcId": { "Ref": "VPC" },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "C public"
                  },
                  {
                    "Key": "Reach",
                    "Value": "public"
                  }
                ]
              }
            },
            "SubnetCPrivate": {
              "DependsOn": "VPCCidrBlock",
              "Type": "AWS::EC2::Subnet",
              "Properties": {
                "AssignIpv6AddressOnCreation": false,
                "AvailabilityZone": { "Fn::Select": [2, { "Fn::GetAZs": "" }] },
                "CidrBlock": { "Fn::Sub": "10.${ClassB}.80.0/20" },
                "Ipv6CidrBlock": { "Fn::Select": [5, { "Fn::Cidr": [{ "Fn::Select": [0, { "Fn::GetAtt": ["VPC", "Ipv6CidrBlocks"] }] }, 6, 64] }] },
                "VpcId": { "Ref": "VPC" },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "C private"
                  },
                  {
                    "Key": "Reach",
                    "Value": "private"
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
                    "Value": "Public"
                  }
                ]
              }
            },
            "RouteTablePrivate": {
              "Type": "AWS::EC2::RouteTable",
              "Properties": {
                "VpcId": { "Ref": "VPC" },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "Private"
                  }
                ]
              }
            },
            "RouteTableBPublic": {
              "Type": "AWS::EC2::RouteTable",
              "Properties": {
                "VpcId": { "Ref": "VPC" },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "B Public"
                  }
                ]
              }
            },
            "RouteTableBPrivate": {
              "Type": "AWS::EC2::RouteTable",
              "Properties": {
                "VpcId": { "Ref": "VPC" },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "B Private"
                  }
                ]
              }
            },
            "RouteTableCPublic": {
              "Type": "AWS::EC2::RouteTable",
              "Properties": {
                "VpcId": { "Ref": "VPC" },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "C Public"
                  }
                ]
              }
            },
            "RouteTableCPrivate": {
              "Type": "AWS::EC2::RouteTable",
              "Properties": {
                "VpcId": { "Ref": "VPC" },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "C Private"
                  }
                ]
              }
            },
            "RouteTableAssociationAPublic": {
              "Type": "AWS::EC2::SubnetRouteTableAssociation",
              "Properties": {
                "SubnetId": { "Ref": "SubnetAPublic" },
                "RouteTableId": { "Ref": "RouteTablePublic" }
              }
            },
            "RouteTableAssociationAPrivate": {
              "Type": "AWS::EC2::SubnetRouteTableAssociation",
              "Properties": {
                "SubnetId": { "Ref": "SubnetAPrivate" },
                "RouteTableId": { "Ref": "RouteTablePrivate" }
              }
            },
            "RouteTableAssociationBPublic": {
              "Type": "AWS::EC2::SubnetRouteTableAssociation",
              "Properties": {
                "SubnetId": { "Ref": "SubnetBPublic" },
                "RouteTableId": { "Ref": "RouteTableBPublic" }
              }
            },
            "RouteTableAssociationBPrivate": {
              "Type": "AWS::EC2::SubnetRouteTableAssociation",
              "Properties": {
                "SubnetId": { "Ref": "SubnetBPrivate" },
                "RouteTableId": { "Ref": "RouteTableBPrivate" }
              }
            },
            "RouteTableAssociationCPublic": {
              "Type": "AWS::EC2::SubnetRouteTableAssociation",
              "Properties": {
                "SubnetId": { "Ref": "SubnetCPublic" },
                "RouteTableId": { "Ref": "RouteTableCPublic" }
              }
            },
            "RouteTableAssociationCPrivate": {
              "Type": "AWS::EC2::SubnetRouteTableAssociation",
              "Properties": {
                "SubnetId": { "Ref": "SubnetCPrivate" },
                "RouteTableId": { "Ref": "RouteTableCPrivate" }
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
            },
            "RouteTablePublicAInternetRouteIPv6": {
              "Type": "AWS::EC2::Route",
              "DependsOn": "VPCGatewayAttachment",
              "Properties": {
                "RouteTableId": { "Ref": "RouteTablePublic" },
                "DestinationIpv6CidrBlock": "::/0",
                "GatewayId": { "Ref": "InternetGateway" }
              }
            },
            "VPCEndpointSecurityGroup": {
              "Type": "AWS::EC2::SecurityGroup",
              "Properties": {
                "GroupDescription": "Security group for VPC endpoints",
                "VpcId": { "Ref": "VPC" },
                "SecurityGroupIngress": [
                  {
                    "IpProtocol": "tcp",
                    "FromPort": 443,
                    "ToPort": 443,
                    "CidrIp": { "Fn::GetAtt": ["VPC", "CidrBlock"] },
                    "Description": "HTTPS from VPC"
                  }
                ],
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "VPC Endpoints Security Group"
                  }
                ]
              }
            },
            "S3VPCEndpoint": {
              "Type": "AWS::EC2::VPCEndpoint",
              "Properties": {
                "VpcId": { "Ref": "VPC" },
                "ServiceName": { "Fn::Sub": "com.amazonaws.${AWS::Region}.s3" },
                "VpcEndpointType": "Gateway",
                "RouteTableIds": [
                  { "Ref": "RouteTablePrivate" },
                  { "Ref": "RouteTableBPrivate" },
                  { "Ref": "RouteTableCPrivate" }
                ]
              }
            },
            "RouteTablePrivateAInternetRouteIPv6": {
              "Type": "AWS::EC2::Route",
              "Properties": {
                "RouteTableId": { "Ref": "RouteTablePrivate" },
                "DestinationIpv6CidrBlock": "::/0",
                "EgressOnlyInternetGatewayId": { "Ref": "EgressOnlyInternetGateway" }
              }
            },
            "RouteTablePublicBInternetRoute": {
              "Type": "AWS::EC2::Route",
              "DependsOn": "VPCGatewayAttachment",
              "Properties": {
                "RouteTableId": { "Ref": "RouteTableBPublic" },
                "DestinationCidrBlock": "0.0.0.0/0",
                "GatewayId": { "Ref": "InternetGateway" }
              }
            },
            "RouteTablePublicBInternetRouteIPv6": {
              "Type": "AWS::EC2::Route",
              "DependsOn": "VPCGatewayAttachment",
              "Properties": {
                "RouteTableId": { "Ref": "RouteTableBPublic" },
                "DestinationIpv6CidrBlock": "::/0",
                "GatewayId": { "Ref": "InternetGateway" }
              }
            },
            "RouteTablePrivateBInternetRouteIPv6": {
              "Type": "AWS::EC2::Route",
              "Properties": {
                "RouteTableId": { "Ref": "RouteTableBPrivate" },
                "DestinationIpv6CidrBlock": "::/0",
                "EgressOnlyInternetGatewayId": { "Ref": "EgressOnlyInternetGateway" }
              }
            },
            "RouteTablePublicCInternetRoute": {
              "Type": "AWS::EC2::Route",
              "DependsOn": "VPCGatewayAttachment",
              "Properties": {
                "RouteTableId": { "Ref": "RouteTableCPublic" },
                "DestinationCidrBlock": "0.0.0.0/0",
                "GatewayId": { "Ref": "InternetGateway" }
              }
            },
            "RouteTablePublicCInternetRouteIPv6": {
              "Type": "AWS::EC2::Route",
              "DependsOn": "VPCGatewayAttachment",
              "Properties": {
                "RouteTableId": { "Ref": "RouteTableCPublic" },
                "DestinationIpv6CidrBlock": "::/0",
                "GatewayId": { "Ref": "InternetGateway" }
              }
            },
            "RouteTablePrivateCInternetRouteIPv6": {
              "Type": "AWS::EC2::Route",
              "Properties": {
                "RouteTableId": { "Ref": "RouteTableCPrivate" },
                "DestinationIpv6CidrBlock": "::/0",
                "EgressOnlyInternetGatewayId": { "Ref": "EgressOnlyInternetGateway" }
              }
            },
            "NetworkAclPublic": {
              "Type": "AWS::EC2::NetworkAcl",
              "Properties": {
                "VpcId": { "Ref": "VPC" },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "Public"
                  }
                ]
              }
            },
            "NetworkAclPrivate": {
              "Type": "AWS::EC2::NetworkAcl",
              "Properties": {
                "VpcId": { "Ref": "VPC" },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": "Private"
                  }
                ]
              }
            },
            "SubnetNetworkAclAssociationAPublic": {
              "Type": "AWS::EC2::SubnetNetworkAclAssociation",
              "Properties": {
                "SubnetId": { "Ref": "SubnetAPublic" },
                "NetworkAclId": { "Ref": "NetworkAclPublic" }
              }
            },
            "SubnetNetworkAclAssociationAPrivate": {
              "Type": "AWS::EC2::SubnetNetworkAclAssociation",
              "Properties": {
                "SubnetId": { "Ref": "SubnetAPrivate" },
                "NetworkAclId": { "Ref": "NetworkAclPrivate" }
              }
            },
            "SubnetNetworkAclAssociationBPublic": {
              "Type": "AWS::EC2::SubnetNetworkAclAssociation",
              "Properties": {
                "SubnetId": { "Ref": "SubnetBPublic" },
                "NetworkAclId": { "Ref": "NetworkAclPublic" }
              }
            },
            "SubnetNetworkAclAssociationBPrivate": {
              "Type": "AWS::EC2::SubnetNetworkAclAssociation",
              "Properties": {
                "SubnetId": { "Ref": "SubnetBPrivate" },
                "NetworkAclId": { "Ref": "NetworkAclPrivate" }
              }
            },
            "SubnetNetworkAclAssociationCPublic": {
              "Type": "AWS::EC2::SubnetNetworkAclAssociation",
              "Properties": {
                "SubnetId": { "Ref": "SubnetCPublic" },
                "NetworkAclId": { "Ref": "NetworkAclPublic" }
              }
            },
            "SubnetNetworkAclAssociationCPrivate": {
              "Type": "AWS::EC2::SubnetNetworkAclAssociation",
              "Properties": {
                "SubnetId": { "Ref": "SubnetCPrivate" },
                "NetworkAclId": { "Ref": "NetworkAclPrivate" }
              }
            },
            "NetworkAclEntryInPublicAllowAll": {
              "Type": "AWS::EC2::NetworkAclEntry",
              "Properties": {
                "NetworkAclId": { "Ref": "NetworkAclPublic" },
                "RuleNumber": 99,
                "Protocol": -1,
                "RuleAction": "allow",
                "Egress": false,
                "CidrBlock": "0.0.0.0/0"
              }
            },
            "NetworkAclEntryInPublicAllowAllIPv6": {
              "Type": "AWS::EC2::NetworkAclEntry",
              "Properties": {
                "NetworkAclId": { "Ref": "NetworkAclPublic" },
                "RuleNumber": 98,
                "Protocol": -1,
                "RuleAction": "allow",
                "Egress": false,
                "Ipv6CidrBlock": "::/0"
              }
            },
            "NetworkAclEntryOutPublicAllowAll": {
              "Type": "AWS::EC2::NetworkAclEntry",
              "Properties": {
                "NetworkAclId": { "Ref": "NetworkAclPublic" },
                "RuleNumber": 99,
                "Protocol": -1,
                "RuleAction": "allow",
                "Egress": true,
                "CidrBlock": "0.0.0.0/0"
              }
            },
            "NetworkAclEntryOutPublicAllowAllIPv6": {
              "Type": "AWS::EC2::NetworkAclEntry",
              "Properties": {
                "NetworkAclId": { "Ref": "NetworkAclPublic" },
                "RuleNumber": 98,
                "Protocol": -1,
                "RuleAction": "allow",
                "Egress": true,
                "Ipv6CidrBlock": "::/0"
              }
            },
            "NetworkAclEntryInPrivateAllowAll": {
              "Type": "AWS::EC2::NetworkAclEntry",
              "Properties": {
                "NetworkAclId": { "Ref": "NetworkAclPrivate" },
                "RuleNumber": 99,
                "Protocol": -1,
                "RuleAction": "allow",
                "Egress": false,
                "CidrBlock": "0.0.0.0/0"
              }
            },
            "NetworkAclEntryInPrivateAllowAllIPv6": {
              "Type": "AWS::EC2::NetworkAclEntry",
              "Properties": {
                "NetworkAclId": { "Ref": "NetworkAclPrivate" },
                "RuleNumber": 98,
                "Protocol": -1,
                "RuleAction": "allow",
                "Egress": false,
                "Ipv6CidrBlock": "::/0"
              }
            },
            "NetworkAclEntryOutPrivateAllowAll": {
              "Type": "AWS::EC2::NetworkAclEntry",
              "Properties": {
                "NetworkAclId": { "Ref": "NetworkAclPrivate" },
                "RuleNumber": 99,
                "Protocol": -1,
                "RuleAction": "allow",
                "Egress": true,
                "CidrBlock": "0.0.0.0/0"
              }
            },
            "NetworkAclEntryOutPrivateAllowAllIPv6": {
              "Type": "AWS::EC2::NetworkAclEntry",
              "Properties": {
                "NetworkAclId": { "Ref": "NetworkAclPrivate" },
                "RuleNumber": 98,
                "Protocol": -1,
                "RuleAction": "allow",
                "Egress": true,
                "Ipv6CidrBlock": "::/0"
              }
            }
          },
          "Outputs": {
            "TemplateID": {
              "Description": "cloudonaut.io template id.",
              "Value": "vpc/vpc-3azs"
            },
            "TemplateVersion": {
              "Description": "cloudonaut.io template version.",
              "Value": "__VERSION__"
            },
            "StackName": {
              "Description": "Stack name.",
              "Value": { "Fn::Sub": "${AWS::StackName}" }
            },
            "AZs": {
              "Description": "Number of AZs",
              "Value": 3,
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-AZs" }
              }
            },
            "AZList": {
              "Description": "List of AZs",
              "Value": { "Fn::Join": [",", [{ "Fn::Select": [0, { "Fn::GetAZs": "" }] }, { "Fn::Select": [1, { "Fn::GetAZs": "" }] }, { "Fn::Select": [2, { "Fn::GetAZs": "" }] }]] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-AZList" }
              }
            },
            "AZA": {
              "Description": "AZ of A",
              "Value": { "Fn::Select": [0, { "Fn::GetAZs": "" }] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-AZA" }
              }
            },
            "AZB": {
              "Description": "AZ of B",
              "Value": { "Fn::Select": [1, { "Fn::GetAZs": "" }] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-AZB" }
              }
            },
            "AZC": {
              "Description": "AZ of C",
              "Value": { "Fn::Select": [2, { "Fn::GetAZs": "" }] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-AZC" }
              }
            },
            "CidrBlock": {
              "Description": "The set of IP addresses for the VPC.",
              "Value": { "Fn::GetAtt": ["VPC", "CidrBlock"] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-CidrBlock" }
              }
            },
            "CidrBlockIPv6": {
              "Description": "The set of IPv6 addresses for the VPC.",
              "Value": { "Fn::Select": [0, { "Fn::GetAtt": ["VPC", "Ipv6CidrBlocks"] }] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-CidrBlockIPv6" }
              }
            },
            "VPC": {
              "Description": "VPC.",
              "Value": { "Ref": "VPC" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-VPC" }
              }
            },
            "InternetGateway": {
              "Description": "InternetGateway.",
              "Value": { "Ref": "InternetGateway" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-InternetGateway" }
              }
            },
            "SubnetsPublic": {
              "Description": "Subnets public.",
              "Value": { "Fn::Join": [",", [{ "Ref": "SubnetAPublic" }, { "Ref": "SubnetBPublic" }, { "Ref": "SubnetCPublic" }]] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-SubnetsPublic" }
              }
            },
            "SubnetsPrivate": {
              "Description": "Subnets private.",
              "Value": { "Fn::Join": [",", [{ "Ref": "SubnetAPrivate" }, { "Ref": "SubnetBPrivate" }, { "Ref": "SubnetCPrivate" }]] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-SubnetsPrivate" }
              }
            },
            "RouteTablesPrivate": {
              "Description": "Route tables private.",
              "Value": { "Fn::Join": [",", [{ "Ref": "RouteTablePrivate" }, { "Ref": "RouteTableBPrivate" }, { "Ref": "RouteTableCPrivate" }]] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RouteTablesPrivate" }
              }
            },
            "RouteTablesPublic": {
              "Description": "Route tables public.",
              "Value": { "Fn::Join": [",", [{ "Ref": "RouteTablePublic" }, { "Ref": "RouteTableBPublic" }, { "Ref": "RouteTableCPublic" }]] },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RouteTablesPublic" }
              }
            },
            "SubnetAPublic": {
              "Description": "Subnet A public.",
              "Value": { "Ref": "SubnetAPublic" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-SubnetAPublic" }
              }
            },
            "RouteTableAPublic": {
              "Description": "Route table A public.",
              "Value": { "Ref": "RouteTablePublic" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RouteTableAPublic" }
              }
            },
            "SubnetAPrivate": {
              "Description": "Subnet A private.",
              "Value": { "Ref": "SubnetAPrivate" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-SubnetAPrivate" }
              }
            },
            "RouteTableAPrivate": {
              "Description": "Route table A private.",
              "Value": { "Ref": "RouteTablePrivate" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RouteTableAPrivate" }
              }
            },
            "SubnetBPublic": {
              "Description": "Subnet B public.",
              "Value": { "Ref": "SubnetBPublic" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-SubnetBPublic" }
              }
            },
            "RouteTableBPublic": {
              "Description": "Route table B public.",
              "Value": { "Ref": "RouteTableBPublic" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RouteTableBPublic" }
              }
            },
            "SubnetBPrivate": {
              "Description": "Subnet B private.",
              "Value": { "Ref": "SubnetBPrivate" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-SubnetBPrivate" }
              }
            },
            "RouteTableBPrivate": {
              "Description": "Route table B private.",
              "Value": { "Ref": "RouteTableBPrivate" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RouteTableBPrivate" }
              }
            },
            "SubnetCPublic": {
              "Description": "Subnet C public.",
              "Value": { "Ref": "SubnetCPublic" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-SubnetCPublic" }
              }
            },
            "RouteTableCPublic": {
              "Description": "Route table C public.",
              "Value": { "Ref": "RouteTableCPublic" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RouteTableCPublic" }
              }
            },
            "SubnetCPrivate": {
              "Description": "Subnet C private.",
              "Value": { "Ref": "SubnetCPrivate" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-SubnetCPrivate" }
              }
            },
            "RouteTableCPrivate": {
              "Description": "Route table C private.",
              "Value": { "Ref": "RouteTableCPrivate" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-RouteTableCPrivate" }
              }
            },
            "S3VPCEndpointId": {
              "Description": "S3 VPC endpoint ID for private bucket access.",
              "Value": { "Ref": "S3VPCEndpoint" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-S3VPCEndpointId" }
              }
            }
          }
        }
        """
}
