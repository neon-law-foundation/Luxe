import Elementary
import VaporElementary

public struct PrivacyPolicyComponent: HTML {
    public let companyName: String
    public let supportEmail: String

    public init(companyName: String, supportEmail: String) {
        self.companyName = companyName
        self.supportEmail = supportEmail
    }

    public var content: some HTML {
        main {
            section(.class("section")) {
                div(.class("container")) {
                    div(.class("content")) {
                        h1(.class("title")) { "Privacy Policy" }

                        p {
                            "\(companyName) takes your privacy seriously. To better protect your privacy, we provide this privacy policy notice explaining the way your personal information is collected and used."
                        }

                        h2(.class("subtitle")) { "Email Communication" }
                        p {
                            "We assume you have one email address. We will only interact with you through one email address. If you need to change your primary email address, please contact our support team."
                        }

                        h2(.class("subtitle")) { "Collection of Routine Information" }
                        p {
                            "This website tracks basic user information including IP addresses, browser details, timestamps, and referring pages. None of this information can personally identify specific users to the website. The information is tracked for routine administration and maintenance purposes."
                        }

                        h2(.class("subtitle")) { "Cookies" }
                        p {
                            "Where necessary, this website uses cookies to store visitor preferences and history in order to better serve the user and/or present the user with customized content."
                        }

                        h2(.class("subtitle")) { "Advertisement and Other Third Parties" }
                        p {
                            "Advertising partners and other third parties may use cookies, scripts and/or web beacons to track visitors to our site in order to display advertisements and other useful information. Such tracking is done directly by the third parties through their own servers and is subject to their own privacy policies. This website has no access or control over these cookies, scripts and/or web beacons that may be used by third parties."
                        }

                        h2(.class("subtitle")) { "Links to Third Party Websites" }
                        p {
                            "We have included links on this site for your use and reference. We are not responsible for the privacy policies on these websites. You should be aware that the privacy policies of these sites may differ from our own."
                        }

                        h2(.class("subtitle")) { "Security" }
                        p {
                            "The security of your personal information is important to us, but remember that no method of transmission over the Internet, or method of electronic storage, is one hundred percent secure. While we strive to use commercially acceptable means to protect your personal information, we cannot guarantee its absolute security."
                        }

                        h2(.class("subtitle")) { "Jurisdiction" }
                        p {
                            "\(companyName) operates under the laws of the United States, State of Nevada. Any disputes arising from the use of this website or services shall be governed by Nevada state law and federal law as applicable."
                        }

                        h2(.class("subtitle")) { "Changes to this Privacy Policy" }
                        p {
                            "This Privacy Policy is effective as of August 1, 2024 and will remain in effect except with respect to any changes in its provisions in the future, which will be in effect immediately after being posted on this page. We reserve the right to update or change our Privacy Policy at any time and you should check this Privacy Policy periodically. Your continued use of the Service after we post any modifications to the Privacy Policy on this page will constitute your acknowledgment of the modifications and your consent to abide and be bound by the modified Privacy Policy."
                        }

                        h2(.class("subtitle")) { "Contact Information" }
                        p {
                            "If you have any questions about this Privacy Policy, please contact us at "
                            a(.href("mailto:\(supportEmail)")) { supportEmail }
                            "."
                        }
                    }
                }
            }
        }
    }
}
