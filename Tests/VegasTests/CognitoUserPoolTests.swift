import Testing

@testable import Vegas

@Suite("Cognito User Pool Infrastructure", .serialized)
struct CognitoUserPoolTests {

    @Test("Should create Cognito User Pool CloudFormation template")
    func cognitoUserPoolTemplateCreation() async throws {
        // Given a Cognito User Pool stack
        let cognitoUserPool = CognitoUserPool()

        // When we get the template body
        let templateBody = cognitoUserPool.templateBody

        // Then it should contain essential Cognito resources
        #expect(templateBody.contains("AWS::Cognito::UserPool"))
        #expect(templateBody.contains("AWS::Cognito::UserPoolClient"))
        #expect(templateBody.contains("AWS::Cognito::UserPoolDomain"))
    }

    @Test("Should configure user pool for OIDC authentication")
    func cognitoUserPoolOIDCConfiguration() async throws {
        // Given a Cognito User Pool stack
        let cognitoUserPool = CognitoUserPool()

        // When we examine the template
        let templateBody = cognitoUserPool.templateBody

        // Then it should support OIDC authentication
        #expect(templateBody.contains("openid"))
        #expect(templateBody.contains("email"))
        #expect(templateBody.contains("profile"))
    }

    @Test("Should export necessary values for ALB integration")
    func cognitoUserPoolALBIntegration() async throws {
        // Given a Cognito User Pool stack
        let cognitoUserPool = CognitoUserPool()

        // When we examine the outputs
        let templateBody = cognitoUserPool.templateBody

        // Then it should export values needed for ALB authentication
        #expect(templateBody.contains("UserPoolArn"))
        #expect(templateBody.contains("UserPoolClientId"))
        #expect(templateBody.contains("UserPoolDomain"))
    }
}
