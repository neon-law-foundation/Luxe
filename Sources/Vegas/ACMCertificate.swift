struct ACMCertificate: Stack {
    /// Create an ACM SSL certificate for a domain.
    /// This will create a certificate with configurable validation method and optional Subject Alternative Names.
    let templateBody: String = """
        {
          "AWSTemplateFormatVersion": "2010-09-09",
          "Description": "ACM SSL certificate with configurable validation",
          "Parameters": {
            "DomainName": {
              "Type": "String",
              "Description": "The primary domain name for the SSL certificate",
              "Default": "standards.sagebrush.services"
            },
            "SubjectAlternativeNames": {
              "Type": "CommaDelimitedList",
              "Description": "Optional comma-delimited list of additional domain names",
              "Default": ""
            },
            "ValidationMethod": {
              "Type": "String",
              "Description": "Method to use for domain validation",
              "Default": "EMAIL",
              "AllowedValues": ["EMAIL", "DNS"]
            }
          },
          "Conditions": {
            "UseDNSValidation": {
              "Fn::Equals": [
                { "Ref": "ValidationMethod" },
                "DNS"
              ]
            },
            "HasSubjectAlternativeNames": {
              "Fn::Not": [
                { "Fn::Equals": [
                  { "Fn::Join": ["", { "Ref": "SubjectAlternativeNames" }] },
                  ""
                ]}
              ]
            }
          },
          "Resources": {
            "SSLCertificate": {
              "Type": "AWS::CertificateManager::Certificate",
              "Properties": {
                "DomainName": { "Ref": "DomainName" },
                "SubjectAlternativeNames": {
                  "Fn::If": [
                    "HasSubjectAlternativeNames",
                    { "Ref": "SubjectAlternativeNames" },
                    { "Ref": "AWS::NoValue" }
                  ]
                },
                "ValidationMethod": { "Ref": "ValidationMethod" },
                "DomainValidationOptions": {
                  "Fn::If": [
                    "UseDNSValidation",
                    [
                      {
                        "DomainName": { "Ref": "DomainName" },
                        "ValidationDomain": { "Ref": "DomainName" }
                      }
                    ],
                    { "Ref": "AWS::NoValue" }
                  ]
                },
                "Tags": [
                  {
                    "Key": "Name",
                    "Value": { "Ref": "DomainName" }
                  }
                ]
              }
            }
          },
          "Outputs": {
            "CertificateArn": {
              "Description": "ARN of the SSL certificate",
              "Value": { "Ref": "SSLCertificate" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-CertificateArn" }
              }
            },
            "DomainName": {
              "Description": "Primary domain name of the certificate",
              "Value": { "Ref": "DomainName" },
              "Export": {
                "Name": { "Fn::Sub": "${AWS::StackName}-DomainName" }
              }
            }
          }
        }
        """
}
