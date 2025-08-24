import Elementary
import Testing

@testable import TouchMenu

@Suite("Footer Component", .serialized)
struct FooterComponentTests {

    @Suite("Network Links", .serialized)
    struct NetworkLinksTests {

        @Test("includes Neon Law link")
        func includesNeonLawLink() {
            let component = FooterComponent(company: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(
                html.contains(
                    "<a class=\"has-text-light\" href=\"https://www.neonlaw.com\" target=\"_blank\">Neon Law®</a>"
                )
            )
        }

        @Test("includes Neon Law Foundation link")
        func includesNeonLawFoundationLink() {
            let component = FooterComponent(company: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(
                html.contains(
                    "<a class=\"has-text-light\" href=\"https://www.neonlaw.org\" target=\"_blank\">Neon Law Foundation</a>"
                )
            )
        }

        @Test("includes Sagebrush Services link")
        func includesSagebrushServicesLink() {
            let component = FooterComponent(company: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(
                html.contains(
                    "<a class=\"has-text-light\" href=\"https://www.sagebrush.services\" target=\"_blank\">Sagebrush Services™</a>"
                )
            )
        }

        @Test("includes Sagebrush Standards link with correct URL")
        func includesSagebrushStandardsLinkWithCorrectURL() {
            let component = FooterComponent(company: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(
                html.contains(
                    "<a class=\"has-text-light\" href=\"https://www.sagebrush.services/standards\" target=\"_blank\">Sagebrush Standards</a>"
                )
            )
        }

        @Test("all network links open in new tab")
        func allNetworkLinksOpenInNewTab() {
            let component = FooterComponent(company: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            let networkLinks = [
                "https://www.neonlaw.com",
                "https://www.neonlaw.org",
                "https://www.sagebrush.services",
                "https://www.sagebrush.services/standards",
            ]

            for link in networkLinks {
                #expect(html.contains("href=\"\(link)\" target=\"_blank\""))
            }
        }
    }

    @Suite("Contact Information", .serialized)
    struct ContactInformationTests {

        @Test("displays support email link")
        func displaysSupportEmailLink() {
            let component = FooterComponent(company: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("<a class=\"has-text-light\" href=\"mailto:support@test.com\">support@test.com</a>"))
        }

        @Test("includes privacy policy link")
        func includesPrivacyPolicyLink() {
            let component = FooterComponent(company: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("<a class=\"has-text-light\" href=\"/privacy\">Privacy Policy</a>"))
        }

        @Test("contact section has proper structure")
        func contactSectionHasProperStructure() {
            let component = FooterComponent(company: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("<h4 class=\"title is-5 has-text-light\">Contact</h4>"))
            #expect(html.contains("Support: "))
        }
    }

    @Suite("Company Information", .serialized)
    struct CompanyInformationTests {

        @Test("displays company name in copyright")
        func displaysCompanyNameInCopyright() {
            let component = FooterComponent(company: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("© 2025 Test Company. All rights reserved."))
        }

        @Test("includes legal disclaimer")
        func includesLegalDisclaimer() {
            let component = FooterComponent(company: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("Nothing here is legal advice."))
        }

        @Test("copyright uses current year")
        func copyrightUsesCurrentYear() {
            let component = FooterComponent(company: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("© 2025"))
        }
    }

    @Suite("HTML Structure", .serialized)
    struct HTMLStructureTests {

        @Test("uses proper semantic HTML structure")
        func usesProperSemanticHTMLStructure() {
            let component = FooterComponent(company: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("<footer class=\"footer has-background-dark has-text-light\""))
            #expect(html.contains("<div class=\"container\">"))
            #expect(html.contains("<div class=\"columns\">"))
            #expect(html.contains("</footer>"))
        }

        @Test("applies correct CSS classes")
        func appliesCorrectCSSClasses() {
            let component = FooterComponent(company: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("class=\"footer has-background-dark has-text-light\""))
            #expect(html.contains("class=\"container\""))
            #expect(html.contains("class=\"columns\""))
            #expect(html.contains("class=\"column is-one-third\""))
            #expect(html.contains("class=\"title is-5 has-text-light\""))
            #expect(html.contains("class=\"content\""))
            #expect(html.contains("class=\"has-text-light\""))
        }

        @Test("includes horizontal rule separator")
        func includesHorizontalRuleSeparator() {
            let component = FooterComponent(company: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("<hr class=\"has-background-grey\">"))
        }

        @Test("has centered bottom section")
        func hasCenteredBottomSection() {
            let component = FooterComponent(company: "Test Company", supportEmail: "support@test.com")
            let html = component.render()

            #expect(html.contains("<div class=\"has-text-centered\">"))
            #expect(html.contains("class=\"has-text-grey-light\""))
        }
    }

    @Suite("Convenience Initializers", .serialized)
    struct ConvenienceInitializersTests {

        @Test("sagebrush footer has correct company and email")
        func sagebrushFooterHasCorrectCompanyAndEmail() {
            let component = FooterComponent.sagebrushFooter()
            let html = component.render()

            #expect(html.contains("© 2025 Sagebrush. All rights reserved."))
            #expect(html.contains("mailto:support@sagebrush.services"))
        }

        @Test("neon law footer has correct company and email")
        func neonLawFooterHasCorrectCompanyAndEmail() {
            let component = FooterComponent.neonLawFooter()
            let html = component.render()

            #expect(html.contains("© 2025 Neon Law. All rights reserved."))
            #expect(html.contains("mailto:support@neonlaw.com"))
        }
    }
}
