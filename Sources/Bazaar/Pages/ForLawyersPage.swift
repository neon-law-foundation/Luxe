import Dali
import Elementary
import TouchMenu
import VaporElementary

struct ForLawyersPage: HTMLDocument {
    let currentUser: User?

    init(currentUser: User? = nil) {
        self.currentUser = currentUser
    }

    var title: String { "AI-Powered Legal Services - Secure, Private, & Compliant | Sagebrush Services" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
        // Include Mermaid.js for diagram rendering
        script(.src("https://cdn.jsdelivr.net/npm/mermaid@10.6.1/dist/mermaid.min.js")) {}
        script {
            "mermaid.initialize({startOnLoad:true, theme:'default', flowchart:{useMaxWidth:true,htmlLabels:true}});"
        }
    }

    var body: some HTML {
        Navigation(currentUser: currentUser)
        heroSection
        securityRisksSection
        whyPrivateAWSSection
        architectureDiagramSection
        whiteLabeLSolutionSection
        complianceAdvantagesSection
        implementationProcessSection
        pricingSection
        callToActionSection
        FooterComponent.sagebrushFooter()
    }

    @HTMLBuilder
    var heroSection: some HTML {
        section(.class("hero is-primary is-large")) {
            div(.class("hero-body")) {
                div(.class("container has-text-centered")) {
                    h1(.class("title is-1 has-text-white")) {
                        "Private AI-Powered Legal Software Services"
                    }
                    h2(.class("subtitle is-3 has-text-white-bis")) {
                        "Your Own Secure AWS Infrastructure + White-Labeled Legal AI Platform"
                    }
                    p(.class("subtitle is-5 has-text-white-ter mb-6")) {
                        "Don't risk attorney-client privilege with public AI services. Get your own secure, private AWS account with a fully customized legal AI platform."
                    }
                    div(.class("buttons is-centered")) {
                        a(
                            .class("button is-warning is-large"),
                            .href("mailto:support@sagebrush.services?subject=Private Legal AI Consultation")
                        ) {
                            strong { "Schedule Private Consultation" }
                        }
                        a(.class("button is-light is-large"), .href("#security-risks")) {
                            "See Why Public AI Is Risky"
                        }
                    }
                }
            }
        }
    }

    @HTMLBuilder
    var securityRisksSection: some HTML {
        section(.id("security-risks"), .class("section has-background-danger-light")) {
            div(.class("container")) {
                div(.class("columns is-vcentered")) {
                    div(.class("column is-two-thirds")) {
                        h2(.class("title is-2 has-text-danger")) {
                            "⚠️ Public AI Services Put Your Legal Practice at Risk"
                        }
                        div(.class("content is-large")) {
                            p(.class("has-text-weight-bold")) {
                                "Using public AI services for legal work creates serious liability exposure:"
                            }

                            riskList([
                                (
                                    "🔓 Data Sharing",
                                    "Your client data trains their models and may be accessed by their staff"
                                ),
                                (
                                    "⚖️ Privilege Breach",
                                    "Attorney-client privilege may be waived when data leaves your control"
                                ),
                                (
                                    "📊 Audit Trail Gaps",
                                    "No comprehensive logging for compliance and malpractice defense"
                                ),
                                ("🎯 Targeted Attacks", "Shared infrastructure makes you vulnerable to data breaches"),
                                (
                                    "📋 Compliance Failures",
                                    "Most public services don't meet legal industry security standards"
                                ),
                                (
                                    "💸 Liability Exposure",
                                    "Malpractice insurance may not cover breaches from unapproved AI use"
                                ),
                            ])
                        }
                    }
                    div(.class("column is-one-third")) {
                        div(.class("notification is-danger")) {
                            h4(.class("title is-4 has-text-white")) { "Legal Industry Alert" }
                            p(.class("content has-text-white")) {
                                "Bar associations are increasingly warning about AI liability risks. Don't let convenience compromise your professional responsibility."
                            }
                        }
                    }
                }
            }
        }
    }

    @HTMLBuilder
    func riskList(_ risks: [(icon: String, description: String)]) -> some HTML {
        ul {
            for risk in risks {
                li(.class("mb-3")) {
                    strong { risk.icon + " " + risk.description }
                }
            }
        }
    }

    @HTMLBuilder
    var whyPrivateAWSSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-primary has-text-centered mb-6")) {
                    "Why Your Law Firm Needs Its Own AWS Account"
                }

                div(.class("columns is-multiline")) {
                    benefitCard(
                        icon: "🏛️",
                        title: "Complete Data Sovereignty",
                        description:
                            "Your client data never leaves your control. It lives entirely within your private AWS infrastructure, not shared servers.",
                        benefits: [
                            "Dedicated hardware with no shared tenancy",
                            "You control your own encryption keys",
                            "Full audit trail of every data access",
                            "Immediate compliance with Bar ethics rules",
                        ]
                    )

                    benefitCard(
                        icon: "🔒",
                        title: "Attorney-Client Privilege Protection",
                        description:
                            "Maintain absolute privilege protection with infrastructure designed for legal confidentiality.",
                        benefits: [
                            "No third-party AI provider access to your data",
                            "VPC isolation prevents external network access",
                            "Encrypted data processing within your environment",
                            "Legally defensible security architecture",
                        ]
                    )

                    benefitCard(
                        icon: "📋",
                        title: "Professional Compliance",
                        description:
                            "Meet and exceed bar association requirements with enterprise-grade security standards.",
                        benefits: [
                            "HIPAA, GDPR, and SOC 2 compliance built-in",
                            "Ability to easily obtain other security certifications",
                            "Detailed audit logs for malpractice defense",
                            "Regular compliance reporting",
                        ]
                    )

                    benefitCard(
                        icon: "🛡️",
                        title: "Risk Mitigation",
                        description:
                            "Eliminate the legal and financial risks of using public AI services for sensitive legal work.",
                        benefits: [
                            "Professional liability insurance compatibility",
                            "No data sharing with AI model providers",
                            "Controlled AI model versions for consistency",
                            "Complete breach prevention architecture",
                        ]
                    )
                }
            }
        }
    }

    @HTMLBuilder
    func benefitCard(icon: String, title: String, description: String, benefits: [String]) -> some HTML {
        div(.class("column is-half")) {
            div(.class("card")) {
                div(.class("card-header")) {
                    p(.class("card-header-title")) {
                        span(.class("icon is-medium")) { icon }
                        span { title }
                    }
                }
                div(.class("card-content")) {
                    p(.class("content")) { description }
                    ul {
                        for benefit in benefits {
                            li { benefit }
                        }
                    }
                }
            }
        }
    }

    @HTMLBuilder
    var architectureDiagramSection: some HTML {
        section(.class("section has-background-light")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-primary has-text-centered mb-6")) {
                    "Secure VPC Architecture for Legal AI"
                }

                div(.class("box")) {
                    p(.class("content has-text-centered is-size-5 mb-5")) {
                        "This diagram shows how your private AWS infrastructure keeps client data completely isolated while providing powerful AI capabilities:"
                    }

                    div(.class("mermaid")) {
                        """
                        flowchart TD
                            subgraph "Your Law Firm"
                                LF[👥 Legal Staff]
                                LF --> |"🔐 MFA + VPN"| VPN[VPN Gateway]
                            end

                            subgraph "Your Private AWS Account"
                                subgraph "Private VPC (Isolated Network)"
                                    VPN --> |"Encrypted Transit"| LB[🔒 Load Balancer]
                                    LB --> WEB[🌐 White-Labeled Legal Portal]

                                    subgraph "AI Processing Zone"
                                        WEB --> |"VPC Endpoints Only"| BEDROCK[🤖 AWS Bedrock AI]
                                        BEDROCK --> |"Internal Processing"| MODELS[🧠 Legal AI Models]
                                    end

                                    subgraph "Secure Data Storage"
                                        WEB --> |"PrivateLink"| S3[📁 S3 Document Storage]
                                        S3 --> |"Your Keys"| KMS[🗝️ AWS CloudHSM]
                                        BEDROCK --> RDS[(🛢️ Case Database)]
                                        RDS --> |"Encryption at Rest"| KMS
                                    end

                                    subgraph "Compliance & Monitoring"
                                        TRAIL[📊 CloudTrail Logging]
                                        GUARD[🛡️ GuardDuty Security]
                                        CONFIG[📋 Config Compliance]

                                        WEB -.->|"Audit All Actions"| TRAIL
                                        S3 -.->|"Monitor Access"| GUARD
                                        RDS -.->|"Compliance Check"| CONFIG
                                    end
                                end
                            end

                            subgraph "External (BLOCKED)"
                                PUB[❌ Public Internet]
                                AI[❌ Public AI Services]
                                THIRD[❌ Third-Party Access]
                            end

                            VPC -.->|"NO DIRECT ACCESS"| PUB
                            BEDROCK -.->|"NO DATA SHARING"| AI
                            S3 -.->|"NO EXTERNAL ACCESS"| THIRD

                            classDef privateZone fill:#e1f5fe,stroke:#0277bd,stroke-width:2px
                            classDef blockedZone fill:#ffebee,stroke:#d32f2f,stroke-width:2px
                            classDef securityZone fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px

                            class VPC,LB,WEB,BEDROCK,MODELS,S3,RDS,KMS privateZone
                            class PUB,AI,THIRD blockedZone
                            class TRAIL,GUARD,CONFIG securityZone
                        """
                    }

                    div(.class("content has-text-centered mt-5")) {
                        h4(.class("title is-4 has-text-primary")) { "Key Security Features:" }
                        div(.class("columns")) {
                            div(.class("column")) {
                                span(.class("icon has-text-success")) { "✅" }
                                span { " Zero external data access" }
                            }
                            div(.class("column")) {
                                span(.class("icon has-text-success")) { "✅" }
                                span { " Complete audit trail" }
                            }
                            div(.class("column")) {
                                span(.class("icon has-text-success")) { "✅" }
                                span { " Your encryption keys" }
                            }
                            div(.class("column")) {
                                span(.class("icon has-text-success")) { "✅" }
                                span { " VPC endpoint isolation" }
                            }
                        }
                    }
                }
            }
        }
    }

    @HTMLBuilder
    var whiteLabeLSolutionSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-primary has-text-centered mb-6")) {
                    "Your Own White-Labeled Legal AI Platform"
                }

                div(.class("columns is-vcentered")) {
                    div(.class("column is-two-thirds")) {
                        h3(.class("title is-3 has-text-info")) { "Sagebrush Deploys Your Custom Legal Portal" }
                        div(.class("content is-large")) {
                            p {
                                "We don't just set up your AWS infrastructure—we deploy a complete, white-labeled version of our legal AI platform directly inside YOUR AWS account. This means:"
                            }

                            ul {
                                li {
                                    "🎨 "
                                    strong { "Branded with your law firm's identity" }
                                    " - logo, colors, and messaging"
                                }
                                li {
                                    "🔧 "
                                    strong { "Customized workflows" }
                                    " for your practice areas and client needs"
                                }
                                li {
                                    "📱 "
                                    strong { "Modern, responsive interface" }
                                    " that your staff will actually want to use"
                                }
                                li {
                                    "🔄 "
                                    strong { "Seamless integrations" }
                                    " with your existing legal software"
                                }
                                li {
                                    "📊 "
                                    strong { "Built-in analytics" }
                                    " to track productivity improvements"
                                }
                                li {
                                    "🛠️ "
                                    strong { "Ongoing updates" }
                                    " deployed securely without accessing your data"
                                }
                            }
                        }
                    }
                    div(.class("column is-one-third")) {
                        div(.class("notification is-info")) {
                            h4(.class("title is-4 has-text-white")) { "Complete Solution" }
                            div(.class("content has-text-white")) {
                                p { "AWS Infrastructure" }
                                p { "+ White-Labeled Software" }
                                p { "+ Ongoing Support" }
                                hr(.class("has-background-white"))
                                p(.class("has-text-weight-bold")) { "= Your Own Legal AI Platform" }
                            }
                        }
                    }
                }

                div(.class("columns is-multiline mt-6")) {
                    featureHighlight(
                        icon: "🎯",
                        title: "Legal-Specific AI Features",
                        items: [
                            "Contract analysis with clause extraction",
                            "Legal research with case law citations",
                            "Document drafting with style consistency",
                            "Discovery review with privilege screening",
                            "Compliance monitoring with alerts",
                        ]
                    )

                    featureHighlight(
                        icon: "🔄",
                        title: "Workflow Integration",
                        items: [
                            "Matter management with AI insights",
                            "Time tracking with automated suggestions",
                            "Client communication with AI drafting",
                            "Billing optimization with usage analytics",
                            "Calendar integration with deadline tracking",
                        ]
                    )

                    featureHighlight(
                        icon: "👥",
                        title: "Multi-User Management",
                        items: [
                            "Role-based access control (partner, associate, paralegal)",
                            "Client portal with secure document sharing",
                            "Staff training resources and best practices",
                            "Usage monitoring and productivity reports",
                            "Collaborative workflows with approval processes",
                        ]
                    )

                    featureHighlight(
                        icon: "🔧",
                        title: "Maintenance & Updates",
                        items: [
                            "Software updates without data access",
                            "New AI models as they become available",
                            "Security patches and compliance updates",
                            "Feature additions based on legal trends",
                            "24/7 monitoring and support",
                        ]
                    )
                }
            }
        }
    }

    @HTMLBuilder
    func featureHighlight(icon: String, title: String, items: [String]) -> some HTML {
        div(.class("column is-half")) {
            div(.class("box has-ribbon")) {
                h4(.class("title is-4")) {
                    span { icon }
                    span(.class("has-text-primary")) { " " + title }
                }
                ul {
                    for item in items {
                        li(.class("mb-2")) { item }
                    }
                }
            }
        }
    }

    @HTMLBuilder
    var complianceAdvantagesSection: some HTML {
        section(.class("section has-background-primary-light")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-primary has-text-centered mb-6")) {
                    "Bar Association Compliance Made Simple"
                }

                div(.class("notification is-warning mb-6")) {
                    div(.class("content has-text-centered")) {
                        h4(.class("title is-4")) { "⚖️ Professional Responsibility Alert" }
                        p(.class("is-size-5")) {
                            "Model Rule 1.6 requires lawyers to make reasonable efforts to prevent unauthorized disclosure of client information. Using public AI services may violate this duty."
                        }
                    }
                }

                div(.class("columns is-multiline")) {
                    complianceCard(
                        title: "ABA Model Rule 1.6 Compliance",
                        description: "Confidentiality of Information",
                        requirements: [
                            "✅ Reasonable efforts to prevent disclosure",
                            "✅ Informed consent not required for secure systems",
                            "✅ Technical safeguards properly implemented",
                            "✅ Vendor agreements ensure confidentiality",
                        ]
                    )

                    complianceCard(
                        title: "ABA Model Rule 1.1 Compliance",
                        description: "Competent Representation",
                        requirements: [
                            "✅ Understanding of technology benefits and risks",
                            "✅ Reasonable security measures implemented",
                            "✅ Staff training on proper AI usage",
                            "✅ Regular security updates and monitoring",
                        ]
                    )

                    complianceCard(
                        title: "ABA Model Rule 5.3 Compliance",
                        description: "Responsibilities Regarding Nonlawyer Assistants",
                        requirements: [
                            "✅ Clear policies for AI tool usage",
                            "✅ Supervision of AI-assisted work product",
                            "✅ Training on confidentiality requirements",
                            "✅ Regular compliance monitoring",
                        ]
                    )

                    complianceCard(
                        title: "State Bar Specific Requirements",
                        description: "Varying State Requirements",
                        requirements: [
                            "✅ California: SB-327 IoT Security Law compliance",
                            "✅ New York: SHIELD Act data protection",
                            "✅ Illinois: Personal Information Protection Act",
                            "✅ Texas: Identity Theft Enforcement and Protection Act",
                        ]
                    )
                }
            }
        }
    }

    @HTMLBuilder
    func complianceCard(title: String, description: String, requirements: [String]) -> some HTML {
        div(.class("column is-half")) {
            div(.class("card")) {
                div(.class("card-header has-background-success")) {
                    p(.class("card-header-title has-text-white")) {
                        title
                    }
                }
                div(.class("card-content")) {
                    p(.class("content has-text-weight-semibold mb-3")) { description }
                    ul {
                        for requirement in requirements {
                            li { requirement }
                        }
                    }
                }
            }
        }
    }

    @HTMLBuilder
    var implementationProcessSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-primary has-text-centered mb-6")) {
                    "Implementation Process: 30 Days to Secure Legal AI"
                }

                div(.class("timeline")) {
                    processStep(
                        week: "Week 1",
                        title: "Consultation & Planning",
                        icon: "📋",
                        tasks: [
                            "Comprehensive security and compliance assessment",
                            "Legal practice workflow analysis",
                            "AWS account setup and initial configuration",
                            "Custom portal design and branding requirements",
                            "Staff training schedule and requirements planning",
                        ],
                        deliverable: "Detailed implementation plan and timeline"
                    )

                    processStep(
                        week: "Week 2",
                        title: "AWS Infrastructure Setup",
                        icon: "☁️",
                        tasks: [
                            "Private VPC creation with strict network isolation",
                            "AWS Bedrock deployment and AI model configuration",
                            "S3 bucket setup with client-controlled encryption",
                            "CloudTrail, GuardDuty, and Config compliance setup",
                            "IAM roles and policies for least-privilege access",
                        ],
                        deliverable: "Fully secured AWS environment ready for legal data"
                    )

                    processStep(
                        week: "Week 3",
                        title: "White-Label Portal Deployment",
                        icon: "🎨",
                        tasks: [
                            "Custom legal portal deployment in your AWS account",
                            "Branding application (logo, colors, messaging)",
                            "Legal workflow configuration and customization",
                            "Integration setup with existing legal software",
                            "Security testing and vulnerability assessment",
                        ],
                        deliverable: "Branded legal AI platform ready for testing"
                    )

                    processStep(
                        week: "Week 4",
                        title: "Training & Go-Live",
                        icon: "🚀",
                        tasks: [
                            "Staff training sessions for all user roles",
                            "Best practices documentation and guidelines",
                            "Trial runs with non-sensitive test cases",
                            "Final security validation and compliance check",
                            "Go-live support and monitoring setup",
                        ],
                        deliverable: "Fully operational secure legal AI platform"
                    )
                }
            }
        }
    }

    @HTMLBuilder
    func processStep(week: String, title: String, icon: String, tasks: [String], deliverable: String) -> some HTML {
        div(.class("timeline-item")) {
            div(.class("timeline-marker is-icon is-success")) {
                i(.class("fa fa-check")) {}
            }
            div(.class("timeline-content")) {
                p(.class("heading")) { week }
                h3(.class("title is-4")) {
                    span(.class("icon is-medium")) { icon }
                    span { title }
                }
                div(.class("content")) {
                    ul {
                        for task in tasks {
                            li { task }
                        }
                    }
                    div(.class("notification is-info is-light")) {
                        strong { "Week " + week.replacingOccurrences(of: "Week ", with: "") + " Deliverable: " }
                        span { deliverable }
                    }
                }
            }
        }
    }

    @HTMLBuilder
    var pricingSection: some HTML {
        section(.class("section has-background-light")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-primary has-text-centered mb-6")) {
                    "Investment in Your Firm's Security & Efficiency"
                }

                div(.class("columns is-centered")) {
                    div(.class("column is-8")) {
                        div(.class("pricing-table")) {
                            pricingTier(
                                name: "Complete Legal AI Platform",
                                price: "$4,999",
                                period: "one-time setup",
                                monthlyFee: "$499/month",
                                description: "Everything you need for secure legal AI",
                                includes: [
                                    "Private AWS account setup and configuration",
                                    "White-labeled legal AI portal deployment",
                                    "AWS Bedrock AI service integration",
                                    "Complete security and compliance setup",
                                    "Staff training and onboarding (up to 20 users)",
                                    "30 days of go-live support",
                                    "Ongoing software updates and maintenance",
                                    "24/7 infrastructure monitoring",
                                    "Monthly compliance reporting",
                                ],
                                highlight: true
                            )
                        }

                        div(.class("notification is-warning mt-5")) {
                            h4(.class("title is-4")) { "💰 AWS Infrastructure Costs" }
                            p {
                                "AWS costs are separate but typically range from $300-1,200/month depending on usage. We optimize your infrastructure to minimize costs while maintaining security. Compare this to the $2,000-5,000/month you might pay for traditional case management software with less secure AI capabilities."
                            }
                        }

                        div(.class("notification is-success mt-3")) {
                            h4(.class("title is-4")) { "📊 ROI Analysis" }
                            p {
                                "Most law firms see 25-40% productivity improvements within 90 days. For a small firm billing $500K annually, this represents $125K+ in additional revenue—paying for the entire system multiple times over."
                            }
                        }
                    }
                }
            }
        }
    }

    @HTMLBuilder
    func pricingTier(
        name: String,
        price: String,
        period: String,
        monthlyFee: String,
        description: String,
        includes: [String],
        highlight: Bool = false
    ) -> some HTML {
        div(.class("column")) {
            div(.class(highlight ? "card has-border-primary" : "card")) {
                div(.class(highlight ? "card-header has-background-primary" : "card-header")) {
                    p(
                        .class(
                            highlight
                                ? "card-header-title has-text-white has-text-centered is-size-4"
                                : "card-header-title has-text-centered is-size-4"
                        )
                    ) {
                        name
                    }
                }
                div(.class("card-content has-text-centered")) {
                    p(.class("title is-1 has-text-primary")) { price }
                    p(.class("subtitle")) { period }
                    p(.class("title is-3 has-text-info")) { monthlyFee }
                    p(.class("subtitle")) { "ongoing" }
                    p(.class("content")) { description }

                    h5(.class("title is-5 has-text-left")) { "Includes:" }
                    div(.class("content has-text-left")) {
                        ul {
                            for include in includes {
                                li { include }
                            }
                        }
                    }
                }
                footer(.class("card-footer")) {
                    a(
                        .class("card-footer-item button is-primary is-large"),
                        .href("mailto:support@sagebrush.services?subject=Legal AI Platform Setup - " + name)
                    ) {
                        "Schedule Consultation"
                    }
                }
            }
        }
    }

    @HTMLBuilder
    var callToActionSection: some HTML {
        section(.class("section has-background-primary")) {
            div(.class("container has-text-centered")) {
                h2(.class("title is-2 has-text-white mb-4")) {
                    "Don't Risk Your Practice with Insecure AI"
                }
                p(.class("subtitle is-4 has-text-white-bis mb-6")) {
                    "Join the law firms who prioritize client confidentiality with truly private AI infrastructure"
                }

                div(.class("columns is-centered")) {
                    div(.class("column is-8")) {
                        div(.class("box")) {
                            h3(.class("title is-4")) { "Ready to Protect Your Clients and Boost Your Practice?" }
                            p(.class("content")) {
                                "Schedule a confidential consultation to discuss your firm's AI needs and security requirements. We'll show you exactly how your private AWS infrastructure will work."
                            }
                            div(.class("buttons is-centered")) {
                                a(
                                    .class("button is-primary is-large"),
                                    .href(
                                        "mailto:support@sagebrush.services?subject=Private Legal AI Consultation&body=I'm interested in learning more about setting up a private AWS infrastructure for our law firm. Please schedule a consultation to discuss our needs.%0A%0AFirm Name:%0AContact Name:%0APhone Number:%0ABest Time to Call:"
                                    )
                                ) {
                                    "Schedule Private Consultation"
                                }
                                a(
                                    .class("button is-info is-large"),
                                    .href("tel:+1-510-800-2080")
                                ) {
                                    "Call Now: 510-800-2080"
                                }
                            }
                        }
                    }
                }

                div(.class("columns is-centered mt-6")) {
                    div(.class("column is-4")) {
                        div(.class("notification is-info is-light")) {
                            h5(.class("title is-5")) { "⚡ Quick Response" }
                            p { "Initial consultation within 24 hours" }
                        }
                    }
                    div(.class("column is-4")) {
                        div(.class("notification is-success is-light")) {
                            h5(.class("title is-5")) { "🔒 Confidential" }
                            p { "All discussions protected by NDA" }
                        }
                    }
                    div(.class("column is-4")) {
                        div(.class("notification is-warning is-light")) {
                            h5(.class("title is-5")) { "💯 No Commitment" }
                            p { "Free consultation with no pressure" }
                        }
                    }
                }
            }
        }
    }
}
