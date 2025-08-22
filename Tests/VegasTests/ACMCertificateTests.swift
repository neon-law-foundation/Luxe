import Testing

@testable import Vegas

@Suite("ACM Certificate Stack", .serialized)
struct ACMCertificateTests {
    @Test("Creates ACM certificate template with correct structure")
    func createsValidTemplate() throws {
        let stack = ACMCertificate()
        let template = stack.templateBody

        #expect(template.contains("AWS::CertificateManager::Certificate"))
        #expect(template.contains("DomainName"))
        #expect(template.contains("ValidationMethod"))
        #expect(template.contains("SubjectAlternativeNames"))
    }

    @Test("Template has correct parameters")
    func hasCorrectParameters() throws {
        let stack = ACMCertificate()
        let template = stack.templateBody

        #expect(template.contains("\"DomainName\": {"))
        #expect(template.contains("\"Type\": \"String\""))
        #expect(template.contains("\"ValidationMethod\": {"))
        #expect(template.contains("\"Default\": \"EMAIL\""))
        #expect(template.contains("\"AllowedValues\": [\"EMAIL\", \"DNS\"]"))
    }

    @Test("Template has email validation by default")
    func hasEmailValidationDefault() throws {
        let stack = ACMCertificate()
        let template = stack.templateBody

        #expect(template.contains("\"Default\": \"EMAIL\""))
    }

    @Test("Template supports DNS validation option")
    func supportsDNSValidation() throws {
        let stack = ACMCertificate()
        let template = stack.templateBody

        #expect(template.contains("\"UseDNSValidation\": {"))
        #expect(template.contains("\"Fn::Equals\": ["))
        #expect(template.contains("\"DNS\""))
    }

    @Test("Template exports certificate ARN")
    func exportsCertificateArn() throws {
        let stack = ACMCertificate()
        let template = stack.templateBody

        #expect(template.contains("\"CertificateArn\": {"))
        #expect(template.contains("\"Value\": { \"Ref\": \"SSLCertificate\" }"))
        #expect(template.contains("\"Export\": {"))
    }

    @Test("Template exports domain name")
    func exportsDomainName() throws {
        let stack = ACMCertificate()
        let template = stack.templateBody

        #expect(template.contains("\"DomainName\": {"))
        #expect(template.contains("\"Description\": \"Primary domain name of the certificate\""))
        #expect(template.contains("\"Export\": {"))
    }

    @Test("Template handles Subject Alternative Names")
    func handlesSubjectAlternativeNames() throws {
        let stack = ACMCertificate()
        let template = stack.templateBody

        #expect(template.contains("\"SubjectAlternativeNames\": {"))
        #expect(template.contains("\"Type\": \"CommaDelimitedList\""))
        #expect(template.contains("\"HasSubjectAlternativeNames\": {"))
    }

    @Test("Stack can be used for Destined domain")
    func canBeUsedForDestinedDomain() throws {
        // This test verifies the stack can be instantiated and used
        // for www.destined.app domain with email validation
        let stack = ACMCertificate()
        let _ = "www.destined.app"  // Domain name for template validation
        let _ = "EMAIL"  // Validation method for template validation

        // The actual parameters would be passed when creating the CloudFormation stack
        // This test verifies the template supports these parameters
        #expect(stack.templateBody.contains("\"DomainName\": {"))
        #expect(stack.templateBody.contains("\"ValidationMethod\": {"))
        #expect(stack.templateBody.contains("\"Default\": \"EMAIL\""))
    }
}
