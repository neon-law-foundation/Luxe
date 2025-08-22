struct ACMCertificateForCloudFront: Stack {
    /// Create ACM certificate in us-east-1 region for CloudFront distributions
    let templateBody: String = """
            {
              "AWSTemplateFormatVersion": "2010-09-09",
              "Description": "ACM: SSL certificate in us-east-1 region for CloudFront distributions",
              "Parameters": {
                "CustomDomainName": {
                  "Type": "String",
                  "Description": "The custom domain name for the certificate (e.g., www.neonlaw.com)"
                },
                "SiteName": {
                  "Type": "String",
                  "Description": "The site name for resource naming (e.g., NeonLaw)"
                }
              },
              "Resources": {
                "ACMCertificate": {
                  "Type": "AWS::CertificateManager::Certificate",
                  "Properties": {
                    "DomainName": { "Ref": "CustomDomainName" },
                    "SubjectAlternativeNames": [
                      {
                        "Fn::Sub": [
                          "*.${RootDomain}",
                          {
                            "RootDomain": {
                              "Fn::Join": [
                                ".",
                                [
                                  {
                                    "Fn::Select": [
                                      1,
                                      {
                                        "Fn::Split": [
                                          ".",
                                          { "Ref": "CustomDomainName" }
                                        ]
                                      }
                                    ]
                                  },
                                  {
                                    "Fn::Select": [
                                      2,
                                      {
                                        "Fn::Split": [
                                          ".",
                                          { "Ref": "CustomDomainName" }
                                        ]
                                      }
                                    ]
                                  }
                                ]
                              ]
                            }
                          }
                        ]
                      }
                    ],
                    "ValidationMethod": "EMAIL",
                    "Tags": [
                      {
                        "Key": "Name",
                        "Value": { "Fn::Sub": "${SiteName}-CloudFront-SSL-Certificate" }
                      },
                      {
                        "Key": "Site",
                        "Value": { "Ref": "SiteName" }
                      },
                      {
                        "Key": "Purpose",
                        "Value": "CloudFront"
                      }
                    ]
                  }
                }
              },
              "Outputs": {
                "ACMCertificateArn": {
                  "Description": "ACM Certificate ARN for CloudFront",
                  "Value": { "Ref": "ACMCertificate" },
                  "Export": {
                    "Name": { "Fn::Sub": "${AWS::StackName}-ACMCertificateArn" }
                  }
                },
                "CustomDomainName": {
                  "Description": "Custom Domain Name",
                  "Value": { "Ref": "CustomDomainName" }
                }
              }
            }
        """
}
