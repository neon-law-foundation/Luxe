import Elementary
import TouchMenu
import VaporElementary

struct PrivacyPolicyPage: HTMLDocument {
    var title: String { "Privacy Policy - Sagebrush Services" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation()
        PrivacyPolicyComponent(companyName: "Sagebrush Services LLC", supportEmail: "support@sagebrush.services")
        FooterComponent.sagebrushFooter()
    }
}
