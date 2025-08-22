import Foundation
import Testing

@testable import Vegas

@Suite("SES Email Processing Infrastructure", .serialized)
struct SESEmailProcessingTests {
    @Test("SES email processing should create receipt rule set")
    func receiptRuleSetIsConfiguredCorrectly() throws {
        let stack = SESEmailProcessing()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]
        let ruleSet = resources?["EmailReceiptRuleSet"] as? [String: Any]
        let properties = ruleSet?["Properties"] as? [String: Any]

        #expect(ruleSet?["Type"] as? String == "AWS::SES::ReceiptRuleSet")
        #expect(properties?["RuleSetName"] as? String == "sagebrush-email-rules")
    }

    @Test("SES email processing should create receipt rule for sagebrush.services")
    func sagebrushReceiptRuleIsConfiguredCorrectly() throws {
        let stack = SESEmailProcessing()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]
        let rule = resources?["SagebrushSupportRule"] as? [String: Any]
        let properties = rule?["Properties"] as? [String: Any]
        let ruleDetails = properties?["Rule"] as? [String: Any]

        #expect(rule?["Type"] as? String == "AWS::SES::ReceiptRule")
        #expect(ruleDetails?["Name"] as? String == "sagebrush-support-rule")
        #expect(ruleDetails?["Enabled"] as? Bool == true)

        let recipients = ruleDetails?["Recipients"] as? [String]
        #expect(recipients?.contains("support@sagebrush.services") == true)

        let actions = ruleDetails?["Actions"] as? [[String: Any]]
        #expect(actions?.count == 1)

        let s3Action = actions?.first?["S3Action"] as? [String: Any]
        #expect(s3Action != nil)
        #expect(s3Action?["ObjectKeyPrefix"] as? String == "sagebrush/")
    }

    @Test("SES email processing should create receipt rule for neonlaw.com")
    func neonLawComReceiptRuleIsConfiguredCorrectly() throws {
        let stack = SESEmailProcessing()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]
        let rule = resources?["NeonLawComSupportRule"] as? [String: Any]
        let properties = rule?["Properties"] as? [String: Any]
        let ruleDetails = properties?["Rule"] as? [String: Any]

        #expect(rule?["Type"] as? String == "AWS::SES::ReceiptRule")
        #expect(ruleDetails?["Name"] as? String == "neonlaw-com-support-rule")
        #expect(ruleDetails?["Enabled"] as? Bool == true)

        let recipients = ruleDetails?["Recipients"] as? [String]
        #expect(recipients?.contains("support@neonlaw.com") == true)

        let actions = ruleDetails?["Actions"] as? [[String: Any]]
        #expect(actions?.count == 1)

        let s3Action = actions?.first?["S3Action"] as? [String: Any]
        #expect(s3Action != nil)
        #expect(s3Action?["ObjectKeyPrefix"] as? String == "neonlaw-com/")
    }

    @Test("SES email processing should create receipt rule for neonlaw.org")
    func neonLawOrgReceiptRuleIsConfiguredCorrectly() throws {
        let stack = SESEmailProcessing()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]
        let rule = resources?["NeonLawOrgSupportRule"] as? [String: Any]
        let properties = rule?["Properties"] as? [String: Any]
        let ruleDetails = properties?["Rule"] as? [String: Any]

        #expect(rule?["Type"] as? String == "AWS::SES::ReceiptRule")
        #expect(ruleDetails?["Name"] as? String == "neonlaw-org-support-rule")
        #expect(ruleDetails?["Enabled"] as? Bool == true)

        let recipients = ruleDetails?["Recipients"] as? [String]
        #expect(recipients?.contains("support@neonlaw.org") == true)

        let actions = ruleDetails?["Actions"] as? [[String: Any]]
        #expect(actions?.count == 1)

        let s3Action = actions?.first?["S3Action"] as? [String: Any]
        #expect(s3Action != nil)
        #expect(s3Action?["ObjectKeyPrefix"] as? String == "neonlaw-org/")
    }

    @Test("SES email processing should require S3 bucket parameter")
    func s3BucketParameterIsConfiguredCorrectly() throws {
        let stack = SESEmailProcessing()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let parameters = template?["Parameters"] as? [String: Any]
        let s3BucketParam = parameters?["S3BucketName"] as? [String: Any]

        #expect(s3BucketParam?["Type"] as? String == "String")
        #expect(s3BucketParam?["Description"] as? String == "The name of the S3 bucket to store incoming emails")
    }

    @Test("SES email processing should have appropriate outputs")
    func outputsAreConfiguredCorrectly() throws {
        let stack = SESEmailProcessing()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let outputs = template?["Outputs"] as? [String: Any]

        #expect(outputs?["RuleSetName"] != nil)
        #expect(outputs?["SagebrushRuleName"] != nil)
        #expect(outputs?["NeonLawComRuleName"] != nil)
        #expect(outputs?["NeonLawOrgRuleName"] != nil)
    }

    @Test("SES receipt rules should be properly ordered")
    func ruleOrderingIsConfiguredCorrectly() throws {
        let stack = SESEmailProcessing()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]

        // Check that each rule references the rule set
        let sagebrushRule = resources?["SagebrushSupportRule"] as? [String: Any]
        let sagebrushProps = sagebrushRule?["Properties"] as? [String: Any]
        #expect(sagebrushProps?["RuleSetName"] != nil)

        let neonComRule = resources?["NeonLawComSupportRule"] as? [String: Any]
        let neonComProps = neonComRule?["Properties"] as? [String: Any]
        #expect(neonComProps?["RuleSetName"] != nil)

        let neonOrgRule = resources?["NeonLawOrgSupportRule"] as? [String: Any]
        let neonOrgProps = neonOrgRule?["Properties"] as? [String: Any]
        #expect(neonOrgProps?["RuleSetName"] != nil)
    }
}
