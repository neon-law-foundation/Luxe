import Bouncer
import Dali
import Elementary
import TouchMenu
import VaporElementary

struct AdminDashboardPage: HTMLDocument {
    let currentUser: User?

    var title: String { "Admin Dashboard - Sagebrush" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        heroSection
        adminSections
        FooterComponent.sagebrushFooter()
    }

    private var heroSection: some HTML {
        GradientHeroComponent(
            title: "Admin Dashboard",
            subtitle: "System Administration and Management"
        )
    }

    private var adminSections: some HTML {
        GradientSectionComponent(backgroundType: .transparent) {
            GradientFeatureGridComponent(features: [
                GradientFeatureGridComponent.Feature(
                    icon: "👥",
                    title: "User Management",
                    description: "Manage user accounts, roles, and permissions"
                ),
                GradientFeatureGridComponent.Feature(
                    icon: "👤",
                    title: "People Management",
                    description: "Manage person records and contact information"
                ),
                GradientFeatureGridComponent.Feature(
                    icon: "🏠",
                    title: "Address Management",
                    description: "Manage address records for entities and people"
                ),
                GradientFeatureGridComponent.Feature(
                    icon: "🏢",
                    title: "Entities Management",
                    description: "Manage legal entities and their types"
                ),
                GradientFeatureGridComponent.Feature(
                    icon: "🏪",
                    title: "Vendors Management",
                    description: "Manage accounting vendors and their references"
                ),
                GradientFeatureGridComponent.Feature(
                    icon: "📁",
                    title: "Projects Management",
                    description: "Manage projects and assigned notations"
                ),
                GradientFeatureGridComponent.Feature(
                    icon: "⚖️",
                    title: "Legal Jurisdictions",
                    description: "Manage legal jurisdictions and court information"
                ),
                GradientFeatureGridComponent.Feature(
                    icon: "❓",
                    title: "Questions Management",
                    description: "Manage standards questions and form templates"
                ),
                GradientFeatureGridComponent.Feature(
                    icon: "📧",
                    title: "Newsletter Management",
                    description: "Create, edit, and send newsletters to subscribers"
                ),
            ])
        }
    }

}
