import Elementary
import VaporElementary

public struct BreadcrumbItem: Sendable {
    public let title: String
    public let url: String?

    public init(title: String, url: String?) {
        self.title = title
        self.url = url
    }
}

public struct BreadcrumbComponent: HTML, Sendable {
    public let items: [BreadcrumbItem]

    public init(items: [BreadcrumbItem]) {
        self.items = items
    }

    public var content: some HTML {
        nav(.class("breadcrumb")) {
            ul {
                breadcrumbItems
            }
        }
    }

    private var breadcrumbItems: some HTML {
        let itemsArray = items
        return ForEach(Array(itemsArray.enumerated())) { index, item in
            let isLast = index == itemsArray.count - 1

            li(.class(isLast ? "is-active" : "")) {
                if item.url == nil {
                    span { item.title }
                } else {
                    a(.href(item.url!)) { item.title }
                }
            }
        }
    }
}

// Convenience initializers for admin navigation
extension BreadcrumbComponent {
    public static func adminUsers() -> BreadcrumbComponent {
        BreadcrumbComponent(items: [
            BreadcrumbItem(title: "Admin", url: "/admin"),
            BreadcrumbItem(title: "Users", url: nil),
        ])
    }

    public static func adminPeople() -> BreadcrumbComponent {
        BreadcrumbComponent(items: [
            BreadcrumbItem(title: "Admin", url: "/admin"),
            BreadcrumbItem(title: "People", url: nil),
        ])
    }

    public static func adminLegalJurisdictions() -> BreadcrumbComponent {
        BreadcrumbComponent(items: [
            BreadcrumbItem(title: "Admin", url: "/admin"),
            BreadcrumbItem(title: "Legal Jurisdictions", url: nil),
        ])
    }

    public static func adminQuestions() -> BreadcrumbComponent {
        BreadcrumbComponent(items: [
            BreadcrumbItem(title: "Admin", url: "/admin"),
            BreadcrumbItem(title: "Questions", url: nil),
        ])
    }

    public static func adminQuestionDetail(questionPrompt: String) -> BreadcrumbComponent {
        BreadcrumbComponent(items: [
            BreadcrumbItem(title: "Admin", url: "/admin"),
            BreadcrumbItem(title: "Questions", url: "/admin/questions"),
            BreadcrumbItem(title: questionPrompt, url: nil),
        ])
    }

    public static func adminProjects() -> BreadcrumbComponent {
        BreadcrumbComponent(items: [
            BreadcrumbItem(title: "Admin", url: "/admin"),
            BreadcrumbItem(title: "Projects", url: nil),
        ])
    }

    public static func adminProjectDetail(projectCodename: String) -> BreadcrumbComponent {
        BreadcrumbComponent(items: [
            BreadcrumbItem(title: "Admin", url: "/admin"),
            BreadcrumbItem(title: "Projects", url: "/admin/projects"),
            BreadcrumbItem(title: projectCodename, url: nil),
        ])
    }

    public static func adminProjectNew() -> BreadcrumbComponent {
        BreadcrumbComponent(items: [
            BreadcrumbItem(title: "Admin", url: "/admin"),
            BreadcrumbItem(title: "Projects", url: "/admin/projects"),
            BreadcrumbItem(title: "New Project", url: nil),
        ])
    }

    public static func adminProjectEdit(projectCodename: String, projectId: String) -> BreadcrumbComponent {
        BreadcrumbComponent(items: [
            BreadcrumbItem(title: "Admin", url: "/admin"),
            BreadcrumbItem(title: "Projects", url: "/admin/projects"),
            BreadcrumbItem(title: projectCodename, url: "/admin/projects/\(projectId)"),
            BreadcrumbItem(title: "Edit", url: nil),
        ])
    }

    public static func adminProjectDelete(projectCodename: String, projectId: String) -> BreadcrumbComponent {
        BreadcrumbComponent(items: [
            BreadcrumbItem(title: "Admin", url: "/admin"),
            BreadcrumbItem(title: "Projects", url: "/admin/projects"),
            BreadcrumbItem(title: projectCodename, url: "/admin/projects/\(projectId)"),
            BreadcrumbItem(title: "Delete", url: nil),
        ])
    }

    public static func adminEntities() -> BreadcrumbComponent {
        BreadcrumbComponent(items: [
            BreadcrumbItem(title: "Admin", url: "/admin"),
            BreadcrumbItem(title: "Entities", url: nil),
        ])
    }

    public static func adminEntityDetail(entityName: String) -> BreadcrumbComponent {
        BreadcrumbComponent(items: [
            BreadcrumbItem(title: "Admin", url: "/admin"),
            BreadcrumbItem(title: "Entities", url: "/admin/entities"),
            BreadcrumbItem(title: entityName, url: nil),
        ])
    }

    public static func adminEntityNew() -> BreadcrumbComponent {
        BreadcrumbComponent(items: [
            BreadcrumbItem(title: "Admin", url: "/admin"),
            BreadcrumbItem(title: "Entities", url: "/admin/entities"),
            BreadcrumbItem(title: "New Entity", url: nil),
        ])
    }

    public static func adminEntityEdit(entityName: String, entityId: String) -> BreadcrumbComponent {
        BreadcrumbComponent(items: [
            BreadcrumbItem(title: "Admin", url: "/admin"),
            BreadcrumbItem(title: "Entities", url: "/admin/entities"),
            BreadcrumbItem(title: entityName, url: "/admin/entities/\(entityId)"),
            BreadcrumbItem(title: "Edit", url: nil),
        ])
    }

    public static func adminEntityDelete(entityName: String, entityId: String) -> BreadcrumbComponent {
        BreadcrumbComponent(items: [
            BreadcrumbItem(title: "Admin", url: "/admin"),
            BreadcrumbItem(title: "Entities", url: "/admin/entities"),
            BreadcrumbItem(title: entityName, url: "/admin/entities/\(entityId)"),
            BreadcrumbItem(title: "Delete", url: nil),
        ])
    }

    public static func adminVendors() -> BreadcrumbComponent {
        BreadcrumbComponent(items: [
            BreadcrumbItem(title: "Admin", url: "/admin"),
            BreadcrumbItem(title: "Vendors", url: nil),
        ])
    }

    public static func adminVendorDetail(vendorName: String) -> BreadcrumbComponent {
        BreadcrumbComponent(items: [
            BreadcrumbItem(title: "Admin", url: "/admin"),
            BreadcrumbItem(title: "Vendors", url: "/admin/vendors"),
            BreadcrumbItem(title: vendorName, url: nil),
        ])
    }

    public static func adminVendorNew() -> BreadcrumbComponent {
        BreadcrumbComponent(items: [
            BreadcrumbItem(title: "Admin", url: "/admin"),
            BreadcrumbItem(title: "Vendors", url: "/admin/vendors"),
            BreadcrumbItem(title: "New Vendor", url: nil),
        ])
    }

    public static func adminVendorEdit(vendorName: String, vendorId: String) -> BreadcrumbComponent {
        BreadcrumbComponent(items: [
            BreadcrumbItem(title: "Admin", url: "/admin"),
            BreadcrumbItem(title: "Vendors", url: "/admin/vendors"),
            BreadcrumbItem(title: vendorName, url: "/admin/vendors/\(vendorId)"),
            BreadcrumbItem(title: "Edit", url: nil),
        ])
    }

    public static func adminVendorDelete(vendorName: String, vendorId: String) -> BreadcrumbComponent {
        BreadcrumbComponent(items: [
            BreadcrumbItem(title: "Admin", url: "/admin"),
            BreadcrumbItem(title: "Vendors", url: "/admin/vendors"),
            BreadcrumbItem(title: vendorName, url: "/admin/vendors/\(vendorId)"),
            BreadcrumbItem(title: "Delete", url: nil),
        ])
    }
}
