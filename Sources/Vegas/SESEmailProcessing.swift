import Foundation

/// A CloudFormation stack that creates SES receipt rules for inbound email processing.
///
/// This stack creates SES infrastructure for processing incoming emails:
/// - Receipt rule set for organizing email processing rules
/// - Receipt rules for support@sagebrush.services, support@neonlaw.com, and support@neonlaw.org
/// - S3 actions to store incoming emails in the private email bucket
/// - Proper rule ordering and organization by domain
///
/// The receipt rules automatically store incoming emails in S3 with domain-specific prefixes
/// for easy organization and processing.
public struct SESEmailProcessing: Stack {
    /// Creates a new instance of the SES email processing stack.
    public init() {}

    public var templateBody: String {
        """
        {
            "AWSTemplateFormatVersion": "2010-09-09",
            "Description": "SES receipt rules for inbound email processing",
            "Parameters": {
                "S3BucketName": {
                    "Type": "String",
                    "Description": "The name of the S3 bucket to store incoming emails"
                }
            },
            "Resources": {
                "EmailReceiptRuleSet": {
                    "Type": "AWS::SES::ReceiptRuleSet",
                    "Properties": {
                        "RuleSetName": "sagebrush-email-rules"
                    }
                },
                "SagebrushSupportRule": {
                    "Type": "AWS::SES::ReceiptRule",
                    "Properties": {
                        "RuleSetName": {
                            "Ref": "EmailReceiptRuleSet"
                        },
                        "Rule": {
                            "Name": "sagebrush-support-rule",
                            "Enabled": true,
                            "Recipients": [
                                "support@sagebrush.services"
                            ],
                            "Actions": [{
                                "S3Action": {
                                    "BucketName": {
                                        "Ref": "S3BucketName"
                                    },
                                    "ObjectKeyPrefix": "sagebrush/"
                                }
                            }]
                        }
                    }
                },
                "NeonLawComSupportRule": {
                    "Type": "AWS::SES::ReceiptRule",
                    "Properties": {
                        "RuleSetName": {
                            "Ref": "EmailReceiptRuleSet"
                        },
                        "Rule": {
                            "Name": "neonlaw-com-support-rule",
                            "Enabled": true,
                            "Recipients": [
                                "support@neonlaw.com"
                            ],
                            "Actions": [{
                                "S3Action": {
                                    "BucketName": {
                                        "Ref": "S3BucketName"
                                    },
                                    "ObjectKeyPrefix": "neonlaw-com/"
                                }
                            }]
                        }
                    },
                    "DependsOn": "SagebrushSupportRule"
                },
                "NeonLawOrgSupportRule": {
                    "Type": "AWS::SES::ReceiptRule",
                    "Properties": {
                        "RuleSetName": {
                            "Ref": "EmailReceiptRuleSet"
                        },
                        "Rule": {
                            "Name": "neonlaw-org-support-rule",
                            "Enabled": true,
                            "Recipients": [
                                "support@neonlaw.org"
                            ],
                            "Actions": [{
                                "S3Action": {
                                    "BucketName": {
                                        "Ref": "S3BucketName"
                                    },
                                    "ObjectKeyPrefix": "neonlaw-org/"
                                }
                            }]
                        }
                    },
                    "DependsOn": "NeonLawComSupportRule"
                }
            },
            "Outputs": {
                "RuleSetName": {
                    "Description": "Name of the SES receipt rule set",
                    "Value": {
                        "Ref": "EmailReceiptRuleSet"
                    },
                    "Export": {
                        "Name": "EmailReceiptRuleSetName"
                    }
                },
                "SagebrushRuleName": {
                    "Description": "Name of the Sagebrush support receipt rule",
                    "Value": "sagebrush-support-rule",
                    "Export": {
                        "Name": "SagebrushSupportRuleName"
                    }
                },
                "NeonLawComRuleName": {
                    "Description": "Name of the Neon Law .com support receipt rule",
                    "Value": "neonlaw-com-support-rule",
                    "Export": {
                        "Name": "NeonLawComSupportRuleName"
                    }
                },
                "NeonLawOrgRuleName": {
                    "Description": "Name of the Neon Law .org support receipt rule",
                    "Value": "neonlaw-org-support-rule",
                    "Export": {
                        "Name": "NeonLawOrgSupportRuleName"
                    }
                }
            }
        }
        """
    }
}
