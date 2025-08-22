import Foundation

/// A CloudFormation stack that creates SES resources for newsletter sending.
///
/// This stack creates SES infrastructure for sending newsletters:
/// - Domain identity verification for sagebrush.services and nvscitech.org
/// - Email address identities for specific sending addresses
/// - DKIM signing configuration
/// - Configuration set for tracking delivery metrics
/// - SNS topics for bounce and complaint handling
///
/// The stack ensures proper email authentication and deliverability
/// while providing tracking and monitoring capabilities.
public struct SESNewsletterSending: Stack {
    /// Creates a new instance of the SES newsletter sending stack.
    public init() {}

    public var templateBody: String {
        """
        {
            "AWSTemplateFormatVersion": "2010-09-09",
            "Description": "SES configuration for newsletter sending with DKIM and monitoring",
            "Resources": {
                "SagebrushDomainIdentity": {
                    "Type": "AWS::SES::EmailIdentity",
                    "Properties": {
                        "EmailIdentity": "sagebrush.services",
                        "DkimSigningAttributes": {
                            "NextSigningKeyLength": "RSA_2048_BIT"
                        }
                    }
                },
                "NVSciTechDomainIdentity": {
                    "Type": "AWS::SES::EmailIdentity",
                    "Properties": {
                        "EmailIdentity": "nvscitech.org",
                        "DkimSigningAttributes": {
                            "NextSigningKeyLength": "RSA_2048_BIT"
                        }
                    }
                },
                "NeonLawDomainIdentity": {
                    "Type": "AWS::SES::EmailIdentity",
                    "Properties": {
                        "EmailIdentity": "neonlaw.com",
                        "DkimSigningAttributes": {
                            "NextSigningKeyLength": "RSA_2048_BIT"
                        }
                    }
                },
                "SagebrushSupportEmailIdentity": {
                    "Type": "AWS::SES::EmailIdentity",
                    "Properties": {
                        "EmailIdentity": "support@sagebrush.services"
                    }
                },
                "NVSciTechTeamEmailIdentity": {
                    "Type": "AWS::SES::EmailIdentity",
                    "Properties": {
                        "EmailIdentity": "team@nvscitech.org"
                    }
                },
                "NeonLawAdminEmailIdentity": {
                    "Type": "AWS::SES::EmailIdentity",
                    "Properties": {
                        "EmailIdentity": "admin@neonlaw.com"
                    }
                },
                "NewsletterConfigurationSet": {
                    "Type": "AWS::SES::ConfigurationSet",
                    "Properties": {
                        "Name": "newsletter-tracking"
                    }
                },
                "EventDestination": {
                    "Type": "AWS::SES::ConfigurationSetEventDestination",
                    "Properties": {
                        "ConfigurationSetName": {
                            "Ref": "NewsletterConfigurationSet"
                        },
                        "EventDestination": {
                            "Name": "newsletter-events",
                            "Enabled": true,
                            "MatchingEventTypes": [
                                "send",
                                "reject",
                                "bounce",
                                "complaint",
                                "delivery"
                            ],
                            "CloudWatchDestination": {
                                "DimensionConfigurations": [
                                    {
                                        "DimensionName": "MessageTag",
                                        "DimensionValueSource": "messageTag",
                                        "DefaultDimensionValue": "default"
                                    }
                                ]
                            }
                        }
                    }
                },
                "BounceHandlingTopic": {
                    "Type": "AWS::SNS::Topic",
                    "Properties": {
                        "TopicName": "ses-newsletter-bounces",
                        "DisplayName": "SES Newsletter Bounce Notifications"
                    }
                },
                "ComplaintHandlingTopic": {
                    "Type": "AWS::SNS::Topic",
                    "Properties": {
                        "TopicName": "ses-newsletter-complaints",
                        "DisplayName": "SES Newsletter Complaint Notifications"
                    }
                },
            },
            "Outputs": {
                "SagebrushDomainIdentity": {
                    "Description": "The domain identity for sagebrush.services",
                    "Value": {
                        "Ref": "SagebrushDomainIdentity"
                    },
                    "Export": {
                        "Name": "SagebrushDomainIdentity"
                    }
                },
                "NVSciTechDomainIdentity": {
                    "Description": "The domain identity for nvscitech.org",
                    "Value": {
                        "Ref": "NVSciTechDomainIdentity"
                    },
                    "Export": {
                        "Name": "NVSciTechDomainIdentity"
                    }
                },
                "NeonLawDomainIdentity": {
                    "Description": "The domain identity for neonlaw.com",
                    "Value": {
                        "Ref": "NeonLawDomainIdentity"
                    },
                    "Export": {
                        "Name": "NeonLawDomainIdentity"
                    }
                },
                "SagebrushDKIMTokens": {
                    "Description": "DKIM tokens for sagebrush.services (use for DNS CNAME records)",
                    "Value": {
                        "Fn::Join": [
                            ",",
                            [
                                {
                                    "Fn::GetAtt": [
                                        "SagebrushDomainIdentity",
                                        "DkimDNSTokenValue1"
                                    ]
                                },
                                {
                                    "Fn::GetAtt": [
                                        "SagebrushDomainIdentity", 
                                        "DkimDNSTokenValue2"
                                    ]
                                },
                                {
                                    "Fn::GetAtt": [
                                        "SagebrushDomainIdentity",
                                        "DkimDNSTokenValue3"
                                    ]
                                }
                            ]
                        ]
                    },
                    "Export": {
                        "Name": "SagebrushDKIMTokens"
                    }
                },
                "NVSciTechDKIMTokens": {
                    "Description": "DKIM tokens for nvscitech.org (use for DNS CNAME records)",
                    "Value": {
                        "Fn::Join": [
                            ",",
                            [
                                {
                                    "Fn::GetAtt": [
                                        "NVSciTechDomainIdentity",
                                        "DkimDNSTokenValue1"
                                    ]
                                },
                                {
                                    "Fn::GetAtt": [
                                        "NVSciTechDomainIdentity", 
                                        "DkimDNSTokenValue2"
                                    ]
                                },
                                {
                                    "Fn::GetAtt": [
                                        "NVSciTechDomainIdentity",
                                        "DkimDNSTokenValue3"
                                    ]
                                }
                            ]
                        ]
                    },
                    "Export": {
                        "Name": "NVSciTechDKIMTokens"
                    }
                },
                "NeonLawDKIMTokens": {
                    "Description": "DKIM tokens for neonlaw.com (use for DNS CNAME records)",
                    "Value": {
                        "Fn::Join": [
                            ",",
                            [
                                {
                                    "Fn::GetAtt": [
                                        "NeonLawDomainIdentity",
                                        "DkimDNSTokenValue1"
                                    ]
                                },
                                {
                                    "Fn::GetAtt": [
                                        "NeonLawDomainIdentity", 
                                        "DkimDNSTokenValue2"
                                    ]
                                },
                                {
                                    "Fn::GetAtt": [
                                        "NeonLawDomainIdentity",
                                        "DkimDNSTokenValue3"
                                    ]
                                }
                            ]
                        ]
                    },
                    "Export": {
                        "Name": "NeonLawDKIMTokens"
                    }
                },
                "SagebrushDKIMTokenNames": {
                    "Description": "DKIM token names for sagebrush.services (use for DNS CNAME names)",
                    "Value": {
                        "Fn::Join": [
                            ",",
                            [
                                {
                                    "Fn::GetAtt": [
                                        "SagebrushDomainIdentity",
                                        "DkimDNSTokenName1"
                                    ]
                                },
                                {
                                    "Fn::GetAtt": [
                                        "SagebrushDomainIdentity", 
                                        "DkimDNSTokenName2"
                                    ]
                                },
                                {
                                    "Fn::GetAtt": [
                                        "SagebrushDomainIdentity",
                                        "DkimDNSTokenName3"
                                    ]
                                }
                            ]
                        ]
                    }
                },
                "NVSciTechDKIMTokenNames": {
                    "Description": "DKIM token names for nvscitech.org (use for DNS CNAME names)",
                    "Value": {
                        "Fn::Join": [
                            ",",
                            [
                                {
                                    "Fn::GetAtt": [
                                        "NVSciTechDomainIdentity",
                                        "DkimDNSTokenName1"
                                    ]
                                },
                                {
                                    "Fn::GetAtt": [
                                        "NVSciTechDomainIdentity", 
                                        "DkimDNSTokenName2"
                                    ]
                                },
                                {
                                    "Fn::GetAtt": [
                                        "NVSciTechDomainIdentity",
                                        "DkimDNSTokenName3"
                                    ]
                                }
                            ]
                        ]
                    }
                },
                "NeonLawDKIMTokenNames": {
                    "Description": "DKIM token names for neonlaw.com (use for DNS CNAME names)",
                    "Value": {
                        "Fn::Join": [
                            ",",
                            [
                                {
                                    "Fn::GetAtt": [
                                        "NeonLawDomainIdentity",
                                        "DkimDNSTokenName1"
                                    ]
                                },
                                {
                                    "Fn::GetAtt": [
                                        "NeonLawDomainIdentity", 
                                        "DkimDNSTokenName2"
                                    ]
                                },
                                {
                                    "Fn::GetAtt": [
                                        "NeonLawDomainIdentity",
                                        "DkimDNSTokenName3"
                                    ]
                                }
                            ]
                        ]
                    }
                },
                "ConfigurationSetName": {
                    "Description": "Configuration set name for newsletter tracking",
                    "Value": {
                        "Ref": "NewsletterConfigurationSet"
                    },
                    "Export": {
                        "Name": "NewsletterConfigurationSet"
                    }
                },
                "BounceTopicArn": {
                    "Description": "SNS topic ARN for bounce notifications",
                    "Value": {
                        "Ref": "BounceHandlingTopic"
                    },
                    "Export": {
                        "Name": "NewsletterBounceTopicArn"
                    }
                },
                "ComplaintTopicArn": {
                    "Description": "SNS topic ARN for complaint notifications",
                    "Value": {
                        "Ref": "ComplaintHandlingTopic"
                    },
                    "Export": {
                        "Name": "NewsletterComplaintTopicArn"
                    }
                }
            }
        }
        """
    }
}
