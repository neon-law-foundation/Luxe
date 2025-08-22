import Foundation
import Testing

@testable import Vegas

@Suite("SQS Email Processing Queue Infrastructure", .serialized)
struct SQSEmailQueueTests {
    @Test("SQS email queue should be named email-processing")
    func queueNameIsConfiguredCorrectly() throws {
        let stack = SQSEmailQueue()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]
        let queue = resources?["EmailProcessingQueue"] as? [String: Any]
        let properties = queue?["Properties"] as? [String: Any]
        let queueName = properties?["QueueName"] as? String

        #expect(queueName == "email-processing")
    }

    @Test("SQS email queue should have dead letter queue configuration")
    func deadLetterQueueIsConfiguredCorrectly() throws {
        let stack = SQSEmailQueue()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]

        // Check dead letter queue exists
        let deadLetterQueue = resources?["EmailProcessingDeadLetterQueue"] as? [String: Any]
        let dlqProperties = deadLetterQueue?["Properties"] as? [String: Any]
        #expect(dlqProperties?["QueueName"] as? String == "email-processing_failed")

        // Check main queue has redrive policy
        let mainQueue = resources?["EmailProcessingQueue"] as? [String: Any]
        let mainProperties = mainQueue?["Properties"] as? [String: Any]
        let redrivePolicy = mainProperties?["RedrivePolicy"] as? [String: Any]
        #expect(redrivePolicy?["maxReceiveCount"] as? Int == 3)
    }

    @Test("SQS email queue should have encryption enabled")
    func encryptionIsConfiguredCorrectly() throws {
        let stack = SQSEmailQueue()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]
        let queue = resources?["EmailProcessingQueue"] as? [String: Any]
        let properties = queue?["Properties"] as? [String: Any]
        let kmsMasterKeyId = properties?["KmsMasterKeyId"] as? String

        #expect(kmsMasterKeyId == "alias/aws/sqs")
    }

    @Test("SQS email queue should have long polling configured")
    func longPollingIsConfiguredCorrectly() throws {
        let stack = SQSEmailQueue()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]
        let queue = resources?["EmailProcessingQueue"] as? [String: Any]
        let properties = queue?["Properties"] as? [String: Any]
        let receiveMessageWaitTime = properties?["ReceiveMessageWaitTimeSeconds"] as? Int

        #expect(receiveMessageWaitTime == 20)
    }

    @Test("SQS email queue should have S3 bucket access policy")
    func s3BucketPolicyIsConfiguredCorrectly() throws {
        let stack = SQSEmailQueue()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let resources = template?["Resources"] as? [String: Any]
        let queuePolicy = resources?["EmailProcessingQueuePolicy"] as? [String: Any]
        let properties = queuePolicy?["Properties"] as? [String: Any]
        let policyDocument = properties?["PolicyDocument"] as? [String: Any]
        let statements = policyDocument?["Statement"] as? [[String: Any]]

        #expect(statements?.count == 1)

        let allowStatement = statements?.first
        #expect(allowStatement?["Effect"] as? String == "Allow")
        #expect(allowStatement?["Principal"] as? [String: String] == ["Service": "s3.amazonaws.com"])

        let actions = allowStatement?["Action"] as? String
        #expect(actions == "sqs:SendMessage")
    }

    @Test("SQS email queue should have appropriate outputs")
    func outputsAreConfiguredCorrectly() throws {
        let stack = SQSEmailQueue()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let outputs = template?["Outputs"] as? [String: Any]

        // Check that the SQSEmailQueueArn output exists (used by S3 bucket notifications)
        #expect(outputs?["SQSEmailQueueArn"] != nil)
        #expect(outputs?["QueueUrl"] != nil)
        #expect(outputs?["QueueName"] != nil)
        #expect(outputs?["DeadLetterQueueArn"] != nil)
        #expect(outputs?["DeadLetterQueueUrl"] != nil)
    }

    @Test("SQS email queue should have no required parameters")
    func noRequiredParametersAreNeeded() throws {
        let stack = SQSEmailQueue()
        let template = try JSONSerialization.jsonObject(with: Data(stack.templateBody.utf8)) as? [String: Any]

        let parameters = template?["Parameters"] as? [String: Any]
        #expect(parameters?.isEmpty == true)
    }
}
