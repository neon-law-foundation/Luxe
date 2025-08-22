import Dali
import Elementary
import TouchMenu
import VaporElementary

struct LawyerPage: HTMLDocument {
    let currentUser: User?

    init(currentUser: User? = nil) {
        self.currentUser = currentUser
    }

    var title: String { "Secure AI for Legal Professionals - Sagebrush Services" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        heroSection
        securityBenefitsSection
        bedrockSecuritySection
        comparisonTableSection
        pricingSection
        valuePropositionSection
        technicalArchitectureSection
        securityArchitectureDiagramSection
        contactFormSection
        testimonialsSection
        faqSection
        gettingStartedSection
        integrationCapabilitiesSection
        caseStudiesSection
        callToActionSection
        FooterComponent.sagebrushFooter()
    }

    @HTMLBuilder
    var heroSection: some HTML {
        section(.class("hero is-primary is-medium")) {
            div(.class("hero-body")) {
                div(.class("container has-text-centered")) {
                    h1(.class("title is-1")) { "Secure AI for Legal Professionals" }
                    h2(.class("subtitle is-3")) {
                        "Your Own Private AWS Account = Maximum Security for Client Data"
                    }
                    p(.class("subtitle is-5")) {
                        "Superior security over public cloud options with dedicated infrastructure, no data sharing, and full encryption control"
                    }
                    div(.class("buttons is-centered")) {
                        a(
                            .class("button is-info is-large"),
                            .href("mailto:support@sagebrush.services?subject=Lawyer AI Platform Inquiry")
                        ) {
                            "Start Consultation - Nevada Bar: $1,111"
                        }
                        a(.class("button is-light is-large"), .href("#security-benefits")) { "Learn About Security" }
                    }
                }
            }
        }
    }

    @HTMLBuilder
    var securityBenefitsSection: some HTML {
        section(.id("security-benefits"), .class("section")) {
            div(.class("container")) {
                div(.class("columns is-vcentered")) {
                    div(.class("column is-two-thirds")) {
                        h2(.class("title is-2 has-text-primary")) { "Your Own Private AWS Account = Maximum Security" }
                        div(.class("content is-large")) {
                            p {
                                "Unlike public cloud AI services that share infrastructure, your private AWS account provides unparalleled security for sensitive legal data."
                            }
                            ul {
                                li { "🏛️ Dedicated infrastructure - no shared resources with other tenants" }
                                li { "🔒 No data sharing with third parties or AI model providers" }
                                li { "🗝️ Full control over encryption keys with AWS CloudHSM" }
                                li { "⚖️ Compliance with legal industry standards (HIPAA, GDPR, NIST 800-171)" }
                                li { "🔐 VPC isolation and PrivateLink connectivity" }
                                li { "📋 Comprehensive audit trails for regulatory compliance" }
                            }
                        }
                    }
                    div(.class("column is-one-third")) {
                        div(.class("notification is-info is-light")) {
                            h4(.class("title is-4")) { "143 Security Standards" }
                            p(.class("content")) {
                                "AWS maintains compliance with 143 security standards and certifications, providing the strongest foundation for legal AI applications."
                            }
                        }
                    }
                }
            }
        }
    }

    @HTMLBuilder
    var bedrockSecuritySection: some HTML {
        section(.class("section has-background-light")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-primary has-text-centered")) {
                    "AWS Bedrock: AI Security Built for Legal"
                }
                div(.class("columns is-multiline")) {
                    bedrockFeatureBox(
                        title: "🔐 Data Never Leaves Your Environment",
                        description:
                            "All AI processing happens within your private AWS account. Your client data never touches shared infrastructure or external AI providers.",
                        features: [
                            "Data encrypted in transit and at rest",
                            "FedRAMP High authorization",
                            "ISO compliance certifications",
                            "VPC-only deployment options",
                        ]
                    )
                    bedrockFeatureBox(
                        title: "⚡ Legal-Specific AI Capabilities",
                        description:
                            "Process hundreds of contract pages in seconds while maintaining absolute client confidentiality.",
                        features: [
                            "Contract analysis and review",
                            "Legal document drafting assistance",
                            "Case research and discovery",
                            "Compliance monitoring",
                        ]
                    )
                    bedrockFeatureBox(
                        title: "🛡️ Advanced Safety Guardrails",
                        description: "Built-in protection ensures reliable, accurate outputs for legal work.",
                        features: [
                            "Blocks 88% of harmful content",
                            "Filters 75% of hallucinations",
                            "Customizable guardrails for legal standards",
                            "Comprehensive audit logging",
                        ]
                    )
                    bedrockFeatureBox(
                        title: "📊 Complete Audit Trail",
                        description:
                            "Every AI interaction is logged and auditable for regulatory compliance and client transparency.",
                        features: [
                            "Detailed activity logging",
                            "Compliance reporting",
                            "Data access tracking",
                            "Retention policy management",
                        ]
                    )
                }
            }
        }
    }

    @HTMLBuilder
    func bedrockFeatureBox(title: String, description: String, features: [String]) -> some HTML {
        div(.class("column is-half")) {
            div(.class("box")) {
                h3(.class("title is-4 has-text-primary")) { title }
                div(.class("content")) {
                    p { description }
                    ul {
                        for feature in features {
                            li { feature }
                        }
                    }
                }
            }
        }
    }

    @HTMLBuilder
    var comparisonTableSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-primary has-text-centered")) {
                    "Public Cloud AI vs Your Private AWS Account"
                }
                div(.class("table-container")) {
                    table(.class("table is-fullwidth is-striped")) {
                        thead {
                            tr {
                                th { "Security Feature" }
                                th(.class("has-text-danger")) { "Public Cloud AI" }
                                th(.class("has-text-success")) { "Your Private AWS Account" }
                            }
                        }
                        tbody {
                            comparisonRow(
                                feature: "Data Control",
                                public: "❌ Shared with AI providers",
                                private: "✅ Stays in your private account"
                            )
                            comparisonRow(
                                feature: "Infrastructure",
                                public: "❌ Multi-tenant shared resources",
                                private: "✅ Dedicated hardware options"
                            )
                            comparisonRow(
                                feature: "Encryption Keys",
                                public: "❌ Provider-managed",
                                private: "✅ Your AWS CloudHSM control"
                            )
                            comparisonRow(
                                feature: "Compliance",
                                public: "❌ Limited audit capabilities",
                                private: "✅ 143 AWS security standards"
                            )
                            comparisonRow(
                                feature: "Cost Predictability",
                                public: "❌ Usage-based surprises",
                                private: "✅ Managed with optimization"
                            )
                        }
                    }
                }
            }
        }
    }

    @HTMLBuilder
    func comparisonRow(feature: String, public publicValue: String, private privateValue: String) -> some HTML {
        tr {
            td(.class("has-text-weight-bold")) { feature }
            td(.class("has-text-danger")) { publicValue }
            td(.class("has-text-success")) { privateValue }
        }
    }

    @HTMLBuilder
    var pricingSection: some HTML {
        section(.class("section has-background-primary-light")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-primary has-text-centered")) { "Simple, Transparent Pricing" }
                div(.class("columns is-centered")) {
                    pricingCard(
                        title: "Standard Setup",
                        price: "$3,333",
                        subtitle: "one-time setup fee",
                        description: "Plus $333/month subscription",
                        buttonText: "Get Started",
                        buttonHref: "mailto:support@sagebrush.services?subject=Standard Lawyer AI Setup",
                        isHighlighted: false
                    )
                    pricingCard(
                        title: "Nevada Bar Member",
                        price: "$1,111",
                        subtitle: "one-time setup fee",
                        description: "Plus $333/month subscription",
                        buttonText: "Nevada Bar Special",
                        buttonHref: "mailto:support@sagebrush.services?subject=Nevada Bar Lawyer AI Setup",
                        isHighlighted: true,
                        highlightText: "67% off setup fee!"
                    )
                }
                div(.class("notification is-info")) {
                    p(.class("has-text-weight-bold")) { "Important: AWS Infrastructure Costs" }
                    p {
                        "AWS infrastructure costs are separate but managed with cost optimization best practices. Typical monthly AWS costs range from $200-800 depending on usage, significantly less than traditional case management software."
                    }
                }
            }
        }
    }

    @HTMLBuilder
    func pricingCard(
        title: String,
        price: String,
        subtitle: String,
        description: String,
        buttonText: String,
        buttonHref: String,
        isHighlighted: Bool,
        highlightText: String? = nil
    ) -> some HTML {
        div(.class("column is-4")) {
            div(.class(isHighlighted ? "card has-border-info" : "card")) {
                div(.class(isHighlighted ? "card-header has-background-info" : "card-header")) {
                    p(
                        .class(
                            isHighlighted
                                ? "card-header-title is-centered has-text-white" : "card-header-title is-centered"
                        )
                    ) { title }
                }
                div(.class("card-content has-text-centered")) {
                    h3(.class("title is-1 has-text-primary")) { price }
                    p(.class("subtitle")) { subtitle }
                    p { description }
                    if let highlightText = highlightText {
                        p(.class("has-text-info has-text-weight-bold")) { highlightText }
                    }
                }
                footer(.class("card-footer")) {
                    a(
                        .class(
                            isHighlighted ? "card-footer-item button is-info" : "card-footer-item button is-primary"
                        ),
                        .href(buttonHref)
                    ) {
                        buttonText
                    }
                }
            }
        }
    }

    @HTMLBuilder
    var valuePropositionSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-primary has-text-centered")) { "What's Included in Your $333/Month" }
                div(.class("columns is-multiline")) {
                    valueBox(
                        icon: "🔐",
                        title: "Secure Legal Portal",
                        items: [
                            "Case management dashboard",
                            "Client data organization",
                            "Document security controls",
                            "Access audit logging",
                        ]
                    )
                    valueBox(
                        icon: "🤖",
                        title: "Private LLM Access",
                        items: [
                            "Contract analysis and review",
                            "Legal research assistance",
                            "Document drafting support",
                            "Case discovery tools",
                        ]
                    )
                    valueBox(
                        icon: "🛠️",
                        title: "AWS Infrastructure Management",
                        items: [
                            "Cost optimization best practices",
                            "Security configuration maintenance",
                            "Performance monitoring",
                            "Backup and disaster recovery",
                        ]
                    )
                    valueBox(
                        icon: "🔧",
                        title: "Write-Only Access Model",
                        items: [
                            "We can update software without accessing data",
                            "Your data remains private always",
                            "Secure deployment processes",
                            "Infrastructure-as-code updates",
                        ]
                    )
                }
            }
        }
    }

    @HTMLBuilder
    func valueBox(icon: String, title: String, items: [String]) -> some HTML {
        div(.class("column is-half")) {
            div(.class("box")) {
                h3(.class("title is-4 has-text-primary")) { "\(icon) \(title)" }
                ul {
                    for item in items {
                        li { item }
                    }
                }
            }
        }
    }

    @HTMLBuilder
    var technicalArchitectureSection: some HTML {
        section(.class("section has-background-light")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-primary has-text-centered")) { "AWS Well-Architected for Legal" }
                div(.class("columns")) {
                    architecturePillar(
                        icon: "🔧",
                        title: "Operational Excellence",
                        items: [
                            "Automated monitoring and alerting",
                            "Infrastructure-as-code deployment",
                            "Continuous integration pipelines",
                        ]
                    )
                    architecturePillar(
                        icon: "🛡️",
                        title: "Security",
                        items: [
                            "Defense-in-depth strategies",
                            "Zero-trust network architecture",
                            "Multi-factor authentication",
                        ]
                    )
                    architecturePillar(
                        icon: "📈",
                        title: "Reliability",
                        items: [
                            "Multi-AZ deployments",
                            "Automated backup systems",
                            "Disaster recovery planning",
                        ]
                    )
                    architecturePillar(
                        icon: "💰",
                        title: "Cost Optimization",
                        items: [
                            "Right-sized resource allocation",
                            "Automated scaling policies",
                            "Comprehensive resource tagging",
                        ]
                    )
                }
            }
        }
    }

    @HTMLBuilder
    func architecturePillar(icon: String, title: String, items: [String]) -> some HTML {
        div(.class("column")) {
            h3(.class("title is-4 has-text-primary")) { "\(icon) \(title)" }
            ul {
                for item in items {
                    li { item }
                }
            }
        }
    }

    @HTMLBuilder
    var securityArchitectureDiagramSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-primary has-text-centered")) { "Security Architecture Overview" }
                div(.class("box has-background-light")) {
                    div(.class("content has-text-centered")) {
                        p(.class("subtitle is-5")) {
                            "Your private AWS account creates complete data isolation for legal AI processing"
                        }
                    }
                    securityFlowDiagram
                    securityKeyFeatures
                }
            }
        }
    }

    @HTMLBuilder
    var securityFlowDiagram: some HTML {
        div {
            div(.class("columns is-vcentered")) {
                securityBox(
                    icon: "🏢",
                    title: "Your Law Firm",
                    items: [
                        "Secure user authentication",
                        "Encrypted connections only",
                        "Multi-factor authentication",
                    ],
                    colorClass: "is-info"
                )
                flowArrow(label: "Encrypted Transit")
                securityBox(
                    icon: "🔒",
                    title: "Private VPC",
                    items: [
                        "Isolated network environment",
                        "No internet gateway access",
                        "AWS PrivateLink connectivity",
                    ],
                    colorClass: "is-primary"
                )
            }
            div(.class("columns is-vcentered mt-4")) {
                securityBox(
                    icon: "🤖",
                    title: "AWS Bedrock",
                    items: [
                        "AI processing in your account",
                        "No data leaves your VPC",
                        "Model isolation guaranteed",
                    ],
                    colorClass: "is-warning"
                )
                flowArrow(label: "Internal Only", isExchange: true)
                securityBox(
                    icon: "💾",
                    title: "Your Data Storage",
                    items: [
                        "Encrypted at rest (AES-256)",
                        "Your CloudHSM keys",
                        "Automated backups",
                    ],
                    colorClass: "is-success"
                )
            }
            complianceLayer
        }
    }

    @HTMLBuilder
    func securityBox(icon: String, title: String, items: [String], colorClass: String) -> some HTML {
        div(.class("column")) {
            div(.class("notification \(colorClass)")) {
                h4(.class("title is-5 \(colorClass.contains("warning") ? "" : "has-text-white")")) {
                    "\(icon) \(title)"
                }
                div(.class("content \(colorClass.contains("warning") ? "" : "has-text-white")")) {
                    ul {
                        for item in items {
                            li { item }
                        }
                    }
                }
            }
        }
    }

    @HTMLBuilder
    func flowArrow(label: String, isExchange: Bool = false) -> some HTML {
        div(.class("column is-narrow has-text-centered")) {
            span(.class("icon is-large")) {
                i(.class("fas fa-\(isExchange ? "exchange-alt" : "long-arrow-alt-right") fa-3x has-text-primary")) {}
            }
            p(.class("has-text-weight-bold")) { label }
        }
    }

    @HTMLBuilder
    var complianceLayer: some HTML {
        div(.class("columns is-centered mt-4")) {
            div(.class("column is-8")) {
                div(.class("notification is-danger is-light")) {
                    h4(.class("title is-5 has-text-centered")) { "📊 Compliance & Audit Layer" }
                    div(.class("content")) {
                        div(.class("columns has-text-centered")) {
                            div(.class("column")) {
                                p(.class("has-text-weight-bold")) { "CloudTrail" }
                                p { "All API calls logged" }
                            }
                            div(.class("column")) {
                                p(.class("has-text-weight-bold")) { "GuardDuty" }
                                p { "Threat detection" }
                            }
                            div(.class("column")) {
                                p(.class("has-text-weight-bold")) { "Config" }
                                p { "Compliance tracking" }
                            }
                        }
                    }
                }
            }
        }
    }

    @HTMLBuilder
    var securityKeyFeatures: some HTML {
        div(.class("content has-text-centered mt-5")) {
            p(.class("has-text-weight-bold is-size-5")) {
                "Key Security Features of This Architecture:"
            }
            div(.class("columns")) {
                div(.class("column")) {
                    p { "✅ Client data never leaves your AWS account" }
                }
                div(.class("column")) {
                    p { "✅ Complete audit trail for compliance" }
                }
                div(.class("column")) {
                    p { "✅ You control all encryption keys" }
                }
                div(.class("column")) {
                    p { "✅ Zero third-party data access" }
                }
            }
        }
    }

    @HTMLBuilder
    var contactFormSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-primary has-text-centered")) { "Schedule Your Consultation" }
                div(.class("columns is-centered")) {
                    div(.class("column is-8")) {
                        div(.class("box")) {
                            form(.method(.post), .action("/lawyers/contact")) {
                                contactFormFields
                            }
                        }
                    }
                }
            }
        }
    }

    @HTMLBuilder
    var contactFormFields: some HTML {
        div(.class("field")) {
            label(.class("label")) { "Law Firm Name *" }
            div(.class("control")) {
                input(
                    .class("input"),
                    .type(.text),
                    .name("firm_name"),
                    .required,
                    .placeholder("Your Law Firm Name")
                )
            }
        }
        div(.class("columns")) {
            div(.class("column")) {
                div(.class("field")) {
                    label(.class("label")) { "Contact Name *" }
                    div(.class("control")) {
                        input(
                            .class("input"),
                            .type(.text),
                            .name("contact_name"),
                            .required,
                            .placeholder("Your Name")
                        )
                    }
                }
            }
            div(.class("column")) {
                div(.class("field")) {
                    label(.class("label")) { "Email Address *" }
                    div(.class("control")) {
                        input(
                            .class("input"),
                            .type(.email),
                            .name("email"),
                            .required,
                            .placeholder("contact@lawfirm.com")
                        )
                    }
                }
            }
        }
        contactFormSelectFields
        contactFormSubmitButton
    }

    @HTMLBuilder
    var contactFormSelectFields: some HTML {
        div(.class("field")) {
            label(.class("label")) { "Nevada Bar Member?" }
            div(.class("control")) {
                div(.class("select is-fullwidth")) {
                    select(.name("nevada_bar_member")) {
                        option(.value("yes")) { "Yes - Nevada Bar Member (67% off setup!)" }
                        option(.value("no")) { "No - Not a Nevada Bar Member" }
                        option(.value("considering")) { "Considering Nevada Admission" }
                    }
                }
            }
        }
        div(.class("field")) {
            label(.class("label")) { "Current Case Management Software" }
            div(.class("control")) {
                input(
                    .class("input"),
                    .type(.text),
                    .name("current_software"),
                    .placeholder("Clio, MyCase, PracticePanther, etc.")
                )
            }
        }
        div(.class("field")) {
            label(.class("label")) { "AI Use Case Interests" }
            div(.class("control")) {
                textarea(
                    .class("textarea"),
                    .name("use_cases"),
                    .placeholder("Contract analysis, legal research, document drafting, case discovery, etc.")
                ) {
                    ""
                }
            }
        }
    }

    @HTMLBuilder
    var contactFormSubmitButton: some HTML {
        div(.class("field")) {
            div(.class("control")) {
                button(.class("button is-primary is-large is-fullwidth"), .type(.submit)) {
                    "Schedule Consultation"
                }
            }
        }
    }

    @HTMLBuilder
    var testimonialsSection: some HTML {
        section(.class("section has-background-light")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-primary has-text-centered")) { "What Legal Security Experts Say" }
                div(.class("columns")) {
                    testimonialBox(
                        quote:
                            "Private cloud infrastructure is essential for maintaining client confidentiality and meeting regulatory compliance requirements in the legal industry. Public cloud AI services simply cannot provide the level of data isolation that law firms need.",
                        attribution: "Legal Technology Security Expert"
                    )
                    testimonialBox(
                        quote:
                            "The Robin AI case study demonstrates how AWS Bedrock enables legal AI applications with enterprise-grade security. The ability to process sensitive legal documents without data sharing is a game-changer for the industry.",
                        attribution: "Cloud Security Analyst"
                    )
                    testimonialBox(
                        quote:
                            "Law firms handling sensitive client data need dedicated infrastructure and encryption key control. AWS private accounts provide the only viable solution for AI-powered legal work.",
                        attribution: "Legal Compliance Officer"
                    )
                }
            }
        }
    }

    @HTMLBuilder
    func testimonialBox(quote: String, attribution: String) -> some HTML {
        div(.class("column")) {
            div(.class("box")) {
                blockquote(.class("content")) {
                    p { "\"\(quote)\"" }
                }
                footer(.class("has-text-right")) {
                    cite { "- \(attribution)" }
                }
            }
        }
    }

    @HTMLBuilder
    var faqSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-primary has-text-centered")) { "Frequently Asked Questions" }
                div(.class("columns is-multiline")) {
                    faqBox(
                        question: "How is data privacy maintained?",
                        answer:
                            "All client data remains in your private AWS account with dedicated infrastructure. We never access, store, or share your data. Our write-only access model ensures complete privacy."
                    )
                    faqBox(
                        question: "What compliance certifications are included?",
                        answer:
                            "Your private AWS account includes 143 security standards: HIPAA, GDPR, NIST 800-171, FedRAMP High, ISO 27001, SOC 2, and many others required for legal industry compliance."
                    )
                    faqBox(
                        question: "How does cost compare to existing solutions?",
                        answer:
                            "At $333/month plus AWS costs ($200-800), you get secure AI capabilities for less than most case management software, while maintaining superior security and compliance."
                    )
                    faqBox(
                        question: "What happens to data if we cancel?",
                        answer:
                            "Your AWS account belongs to you entirely. If you cancel, you retain full control and ownership of all data, infrastructure, and AI models. No vendor lock-in."
                    )
                    faqBox(
                        question: "How quickly can the system be deployed?",
                        answer:
                            "Initial consultation and needs assessment (1 week), AWS account setup and security configuration (1-2 weeks), Bedrock deployment and testing (1 week), staff training (1 week). Total: 4-5 weeks."
                    )
                    faqBox(
                        question: "What ongoing support is provided?",
                        answer:
                            "24/7 infrastructure monitoring, AWS cost optimization, security updates, staff training, and dedicated support for all legal AI use cases. Complete peace of mind."
                    )
                }
            }
        }
    }

    @HTMLBuilder
    func faqBox(question: String, answer: String) -> some HTML {
        div(.class("column is-half")) {
            div(.class("box")) {
                h4(.class("title is-5 has-text-primary")) { question }
                p(.class("content")) { answer }
            }
        }
    }

    @HTMLBuilder
    var gettingStartedSection: some HTML {
        section(.class("section has-background-primary-light")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-primary has-text-centered")) {
                    "Getting Started with Your Legal AI Platform"
                }
                div(.class("columns is-multiline")) {
                    phaseBox(
                        phase: 1,
                        icon: "📋",
                        title: "Consultation & Assessment",
                        timeline: "1 week",
                        items: [
                            "Initial consultation and needs assessment",
                            "Security requirements analysis",
                            "AI use case identification and prioritization",
                            "Cost estimation and AWS resource planning",
                            "Project timeline and milestone definition",
                        ]
                    )
                    phaseBox(
                        phase: 2,
                        icon: "⚙️",
                        title: "AWS Setup & Configuration",
                        timeline: "1-2 weeks",
                        items: [
                            "Private AWS account creation and setup",
                            "VPC and security configuration",
                            "IAM roles and policies implementation",
                            "Encryption and CloudHSM configuration",
                            "Compliance and audit logging setup",
                        ]
                    )
                    phaseBox(
                        phase: 3,
                        icon: "🤖",
                        title: "Bedrock Deployment & Testing",
                        timeline: "1 week",
                        items: [
                            "AWS Bedrock service deployment",
                            "AI model configuration and testing",
                            "Legal-specific guardrails implementation",
                            "Performance optimization and tuning",
                            "Security validation and compliance testing",
                        ]
                    )
                    phaseBox(
                        phase: 4,
                        icon: "🎓",
                        title: "Training & Portal Access",
                        timeline: "1 week",
                        items: [
                            "Staff training and onboarding sessions",
                            "Secure portal setup and access provisioning",
                            "Workflow integration and customization",
                            "Documentation and best practices review",
                            "Go-live support and monitoring",
                        ]
                    )
                }
                div(.class("notification is-info")) {
                    p(.class("has-text-weight-bold")) { "Total Implementation Timeline: 4-5 Weeks" }
                    p {
                        "Our systematic approach ensures secure, compliant deployment of your legal AI platform with minimal disruption to your current operations."
                    }
                }
            }
        }
    }

    @HTMLBuilder
    func phaseBox(phase: Int, icon: String, title: String, timeline: String, items: [String]) -> some HTML {
        div(.class("column is-6")) {
            div(.class("box")) {
                h3(.class("title is-4 has-text-primary")) { "\(icon) Phase \(phase): \(title)" }
                p(.class("subtitle is-6")) { "Timeline: \(timeline)" }
                div(.class("content")) {
                    ul {
                        for item in items {
                            li { item }
                        }
                    }
                }
            }
        }
    }

    @HTMLBuilder
    var integrationCapabilitiesSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-primary has-text-centered")) { "Enterprise Integration Capabilities" }
                div(.class("columns is-multiline")) {
                    integrationBox(
                        icon: "📁",
                        title: "Document Management Systems",
                        items: [
                            "NetDocuments, iManage, SharePoint integration",
                            "Secure document upload and analysis",
                            "Version control and audit trail maintenance",
                            "Automated document classification and tagging",
                        ]
                    )
                    integrationBox(
                        icon: "💰",
                        title: "Billing & Time Tracking",
                        items: [
                            "Clio, TimeSolv, ProLaw billing integration",
                            "AI-assisted time entry and matter tracking",
                            "Automated billing code suggestions",
                            "Cost analysis and reporting automation",
                        ]
                    )
                    integrationBox(
                        icon: "⚖️",
                        title: "Court Filing Systems",
                        items: [
                            "E-filing system integration (PACER, state courts)",
                            "Document preparation and formatting automation",
                            "Deadline tracking and calendar integration",
                            "Compliance verification and validation",
                        ]
                    )
                    integrationBox(
                        icon: "📞",
                        title: "Client Communication",
                        items: [
                            "CRM integration (Salesforce, HubSpot)",
                            "Client portal and secure messaging",
                            "Automated status updates and notifications",
                            "API-first architecture for custom integrations",
                        ]
                    )
                }
            }
        }
    }

    @HTMLBuilder
    func integrationBox(icon: String, title: String, items: [String]) -> some HTML {
        div(.class("column is-6")) {
            div(.class("box")) {
                h3(.class("title is-4 has-text-primary")) { "\(icon) \(title)" }
                div(.class("content")) {
                    ul {
                        for item in items {
                            li { item }
                        }
                    }
                }
            }
        }
    }

    @HTMLBuilder
    var caseStudiesSection: some HTML {
        section(.class("section has-background-light")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-primary has-text-centered")) { "Legal AI Use Cases & Results" }
                div(.class("columns is-multiline")) {
                    caseStudyBox(
                        icon: "📋",
                        title: "Contract Analysis & Review",
                        results: "75% time reduction, 95% accuracy improvement",
                        features: [
                            "Automated clause identification and analysis",
                            "Risk assessment and flagging",
                            "Compliance verification across jurisdictions",
                            "Redlining and revision suggestions",
                        ]
                    )
                    caseStudyBox(
                        icon: "🔍",
                        title: "Legal Research & Discovery",
                        results: "60% faster research, 300% more citations found",
                        features: [
                            "Case law research and citation analysis",
                            "Precedent identification and comparison",
                            "Document review and privilege analysis",
                            "Evidence organization and summarization",
                        ]
                    )
                    caseStudyBox(
                        icon: "✍️",
                        title: "Document Drafting Assistance",
                        results: "50% faster drafting, consistent quality",
                        features: [
                            "Template generation and customization",
                            "Language optimization and clarity improvement",
                            "Citation verification and formatting",
                            "Style guide compliance and proofreading",
                        ]
                    )
                    caseStudyBox(
                        icon: "📊",
                        title: "Compliance Monitoring",
                        results: "90% reduction in compliance issues",
                        features: [
                            "Regulatory change tracking and analysis",
                            "Policy compliance verification",
                            "Deadline monitoring and alerts",
                            "Audit trail generation and reporting",
                        ]
                    )
                }
            }
        }
    }

    @HTMLBuilder
    func caseStudyBox(icon: String, title: String, results: String, features: [String]) -> some HTML {
        div(.class("column is-6")) {
            div(.class("box")) {
                h3(.class("title is-4 has-text-primary")) { "\(icon) \(title)" }
                div(.class("content")) {
                    p(.class("has-text-weight-bold")) { "Results: \(results)" }
                    ul {
                        for feature in features {
                            li { feature }
                        }
                    }
                }
            }
        }
    }

    @HTMLBuilder
    var callToActionSection: some HTML {
        section(.class("section has-background-primary")) {
            div(.class("container has-text-centered")) {
                h2(.class("title is-2 has-text-white")) { "Ready to Secure Your Legal AI?" }
                p(.class("subtitle is-4 has-text-white")) {
                    "Join the future of legal technology with maximum security and client confidentiality"
                }
                div(.class("buttons is-centered")) {
                    a(
                        .class("button is-info is-large"),
                        .href("mailto:support@sagebrush.services?subject=Lawyer AI Platform Consultation")
                    ) {
                        "Schedule Consultation"
                    }
                    a(.class("button is-light is-large"), .href("#security-benefits")) {
                        "Learn More About Security"
                    }
                }
            }
        }
    }
}
