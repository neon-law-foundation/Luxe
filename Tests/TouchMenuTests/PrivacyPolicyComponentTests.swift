import Elementary
import Testing

@testable import TouchMenu

@Suite("PrivacyPolicy Component", .serialized)
struct PrivacyPolicyComponentTests {

    @Suite("Content Rendering", .serialized)
    struct ContentRenderingTests {

        @Test("renders privacy policy title")
        func rendersPrivacyPolicyTitle() {
            let component = PrivacyPolicyComponent(companyName: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("<h1 class=\"title\">Privacy Policy</h1>"))
        }

        @Test("displays company information")
        func displaysCompanyInformation() {
            let component = PrivacyPolicyComponent(companyName: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("Test Company takes your privacy seriously"))
            #expect(html.contains("To better protect your privacy, we provide this privacy policy notice"))
        }

        @Test("shows contact information with email link")
        func showsContactInformationWithEmailLink() {
            let component = PrivacyPolicyComponent(companyName: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("If you have any questions about this Privacy Policy, please contact us at"))
            #expect(html.contains("<a href=\"mailto:support@test.com\">support@test.com</a>"))
        }
    }

    @Suite("Legal Sections", .serialized)
    struct LegalSectionsTests {

        @Test("includes collection of routine information section")
        func includesCollectionOfRoutineInformationSection() {
            let component = PrivacyPolicyComponent(companyName: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("<h2 class=\"subtitle\">Collection of Routine Information</h2>"))
            #expect(html.contains("This website tracks basic user information including IP addresses"))
            #expect(html.contains("None of this information can personally identify specific users"))
            #expect(html.contains("routine administration and maintenance purposes"))
        }

        @Test("includes cookies policy section")
        func includesCookiesPolicySection() {
            let component = PrivacyPolicyComponent(companyName: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("<h2 class=\"subtitle\">Cookies</h2>"))
            #expect(html.contains("this website uses cookies to store visitor preferences"))
            #expect(html.contains("better serve the user and/or present the user with customized content"))
        }

        @Test("includes third party links disclaimer")
        func includesThirdPartyLinksDisclaimer() {
            let component = PrivacyPolicyComponent(companyName: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("<h2 class=\"subtitle\">Links to Third Party Websites</h2>"))
            #expect(html.contains("We have included links on this site for your use and reference"))
            #expect(html.contains("We are not responsible for the privacy policies on these websites"))
            #expect(html.contains("privacy policies of these sites may differ from our own"))
        }

        @Test("includes security policy section")
        func includesSecurityPolicySection() {
            let component = PrivacyPolicyComponent(companyName: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("<h2 class=\"subtitle\">Security</h2>"))
            #expect(html.contains("The security of your personal information is important to us"))
            #expect(html.contains("no method of transmission over the Internet"))
            #expect(html.contains("commercially acceptable means to protect your personal information"))
        }

        @Test("includes policy changes section")
        func includesPolicyChangesSection() {
            let component = PrivacyPolicyComponent(companyName: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("<h2 class=\"subtitle\">Changes to this Privacy Policy</h2>"))
            #expect(html.contains("effective as of August 1, 2024"))
            #expect(html.contains("reserve the right to update or change our Privacy Policy"))
            #expect(html.contains("check this Privacy Policy periodically"))
        }

        @Test("includes jurisdiction section")
        func includesJurisdictionSection() {
            let component = PrivacyPolicyComponent(companyName: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("<h2 class=\"subtitle\">Jurisdiction</h2>"))
            #expect(html.contains("Test Company operates under the laws of the United States, State of Nevada"))
            #expect(html.contains("governed by Nevada state law and federal law"))
        }

        @Test("includes advertisement and third parties section")
        func includesAdvertisementAndThirdPartiesSection() {
            let component = PrivacyPolicyComponent(companyName: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("<h2 class=\"subtitle\">Advertisement and Other Third Parties</h2>"))
            #expect(html.contains("Advertising partners and other third parties may use cookies"))
            #expect(html.contains("This website has no access or control over these cookies"))
        }
    }

    @Suite("HTML Structure", .serialized)
    struct HTMLStructureTests {

        @Test("uses proper semantic HTML structure")
        func usesProperSemanticHTMLStructure() {
            let component = PrivacyPolicyComponent(companyName: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("<main>"))
            #expect(html.contains("<section class=\"section\">"))
            #expect(html.contains("</main>"))
            #expect(html.contains("</section>"))
        }

        @Test("applies correct CSS classes")
        func appliesCorrectCSSClasses() {
            let component = PrivacyPolicyComponent(companyName: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("class=\"section\""))
            #expect(html.contains("class=\"container\""))
            #expect(html.contains("class=\"content\""))
            #expect(html.contains("class=\"title\""))
            #expect(html.contains("class=\"subtitle\""))
        }

        @Test("uses paragraphs instead of lists for policy content")
        func usesParagraphsInsteadOfListsForPolicyContent() {
            let component = PrivacyPolicyComponent(companyName: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("<p>"))
            #expect(html.contains("</p>"))
            // Should not contain lists in legal sections
            #expect(!html.contains("<ul>"))
            #expect(!html.contains("<li>"))
        }
    }
}
