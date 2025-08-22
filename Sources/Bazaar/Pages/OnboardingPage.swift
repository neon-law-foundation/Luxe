import Elementary
import TouchMenu
import VaporElementary

struct OnboardingPage: HTMLDocument {
    var title: String { "Complete Business Setup Services - Sagebrush" }

    var head: some HTML {
        HeaderComponent.sagebrushTheme()
        Elementary.title { title }
    }

    var body: some HTML {
        Navigation()
        HeroSection()
        TrademarkSearchSection()
        VirtualMailboxSection()
        ContactSection()
        FooterComponent.sagebrushFooter()
        TrademarkSearchScript()
    }
}

struct HeroSection: HTML {
    var content: some HTML {
        section(.class("hero is-primary")) {
            div(.class("hero-body")) {
                div(.class("container has-text-centered")) {
                    h1(.class("title is-1")) { "Complete Business Setup Services" }
                    h2(.class("subtitle is-3")) { "Nevada address, trademark search & filing, all in one place" }
                }
            }
        }
    }
}

struct TrademarkSearchSection: HTML {
    var content: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-primary has-text-centered")) { "Trademark Search & Filing" }

                div(.class("columns")) {
                    TrademarkSearchCard()
                    TrademarkBenefitsCard()
                }
            }
        }
    }
}

struct TrademarkSearchCard: HTML {
    var content: some HTML {
        div(.class("column is-8")) {
            div(.class("card")) {
                div(.class("card-content")) {
                    h3(.class("title is-3")) { "Free Trademark Name Search" }
                    p {
                        "Search the USPTO database to check if your trademark name is available. Professional Trademark Filing - $499 per class through our partner Neon Law."
                    }

                    TrademarkSearchForm()

                    div(.id("search-results"), .style("margin-top: 1rem;")) {
                        // Results will be populated here
                    }
                }
            }
        }
    }
}

struct TrademarkSearchForm: HTML {
    var content: some HTML {
        div(.class("field has-addons")) {
            div(.class("control is-expanded")) {
                input(
                    .class("input"),
                    .type(.text),
                    .id("trademark-search-input"),
                    .placeholder("Enter trademark name to search")
                )
            }
            div(.class("control")) {
                button(.class("button is-primary is-rounded"), .id("trademark-search-button")) { "Search" }
            }
        }
    }
}

struct TrademarkBenefitsCard: HTML {
    var content: some HTML {
        div(.class("column is-4")) {
            div(.class("card")) {
                div(.class("card-content")) {
                    h4(.class("title is-4")) { "Why Trademark Protection?" }
                    div(.class("content")) {
                        p { strong { "Exclusive Rights" } }
                        p { "Protect your brand name from competitors" }
                        p { strong { "Asset Value" } }
                        p { "Build valuable intellectual property" }
                        p { strong { "Legal Protection" } }
                        p { "Enforce your rights in court if needed" }
                    }
                }
            }
        }
    }
}

struct VirtualMailboxSection: HTML {
    var content: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-primary has-text-centered")) { "Physical Address Setup" }
                h3(.class("subtitle is-4 has-text-centered")) { "Get Your Nevada Address in 5 Simple Steps" }

                div(.class("columns")) {
                    div(.class("column is-8")) {
                        h2(.class("title is-2 has-text-primary")) { "Required Documents" }
                        div(.class("notification is-info is-light")) {
                            h4(.class("title is-4")) { "📋 What You'll Need" }
                            ul {
                                li {
                                    "USPS Form 1583 (Application for Delivery of Mail Through Agent) - April 2023 version"
                                }
                                li { "Photo ID (driver's license, passport, or state-issued ID)" }
                                li {
                                    "Address verification document (utility bill, voter registration, or vehicle registration)"
                                }
                            }
                        }

                        h2(.class("title is-2 has-text-primary")) { "Step-by-Step Process" }

                        OnboardingStep(
                            number: "1",
                            title: "📄 Download and Complete USPS Form 1583",
                            description:
                                "Download the latest version (April 2023) from the USPS website, fill out all required fields accurately, and sign the form."
                        )

                        OnboardingStep(
                            number: "2",
                            title: "📝 Get Form Notarized",
                            description: "Choose from three options:",
                            details: [
                                "In-Person: Visit a local notary at banks, courthouses, or UPS stores (under $20)",
                                "Online: Use an online notary service (approximately $25)",
                                "Local Office: Visit our office at 405 Mae Anne Ave, Suite 450, Reno, NV",
                            ]
                        )

                        OnboardingStep(
                            number: "3",
                            title: "📁 Gather Required Documentation",
                            description:
                                "Prepare clear, legible copies of your photo ID and address verification document."
                        )

                        OnboardingStep(
                            number: "4",
                            title: "📧 Submit Documentation",
                            description:
                                "Email all completed forms and documentation to support@sagebrush.services with your contact information and preferred mailing address."
                        )

                        OnboardingStep(
                            number: "5",
                            title: "💳 Payment Processing",
                            description:
                                "We'll invoice you through Xero for setup fees and first month's service. Payment must be received before mail forwarding begins."
                        )
                    }

                    div(.class("column is-4")) {
                        div(.class("card")) {
                            div(.class("card-content")) {
                                h3(.class("title is-3 has-text-primary")) { "Quick Start" }
                                div(.class("content")) {
                                    p(.class("has-text-weight-bold")) { "Ready to begin?" }
                                    p {
                                        "Contact our support team to get started with your physical address setup today."
                                    }
                                }
                                a(
                                    .class("button is-primary is-large is-fullwidth is-rounded"),
                                    .href("mailto:support@sagebrush.services")
                                ) { "Get Started" }
                            }
                        }

                        div(.class("card")) {
                            div(.class("card-content")) {
                                h4(.class("title is-4 has-text-primary")) { "⏱️ Timeline" }
                                div(.class("content")) {
                                    p {
                                        "Processing Time: 2-3 business days after receiving all documentation and payment"
                                    }
                                    p { "Mail forwarding begins immediately after account activation" }
                                }
                            }
                        }

                        div(.class("card")) {
                            div(.class("card-content")) {
                                h4(.class("title is-4 has-text-primary")) { "🎯 Our Guarantee" }
                                div(.class("content")) {
                                    p(.class("has-text-weight-bold")) { "✅ One business day response time" }
                                    p(.class("has-text-weight-bold")) { "✅ One business day mail delivery via email" }
                                    p(.class("has-text-weight-bold")) { "✅ Professional customer support" }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ContactSection: HTML {
    var content: some HTML {
        section(.class("section has-background-light")) {
            div(.class("container has-text-centered")) {
                h2(.class("title is-2 has-text-primary")) { "Questions About Onboarding?" }
                p(.class("subtitle")) { "Our support team is here to help you through every step" }
                div(.class("buttons is-centered")) {
                    a(.class("button is-primary is-large is-rounded"), .href("mailto:support@sagebrush.services")) {
                        "Contact Support"
                    }
                    a(.class("button is-light is-large is-rounded"), .href("/virtual-mailbox")) { "Learn More" }
                }
            }
        }
    }
}

struct TrademarkSearchScript: HTML {
    var content: some HTML {
        script {
            """
            document.addEventListener('DOMContentLoaded', function() {
                const searchButton = document.getElementById('trademark-search-button');
                const searchInput = document.getElementById('trademark-search-input');

                if (searchButton) {
                    searchButton.addEventListener('click', searchTrademark);
                }

                if (searchInput) {
                    searchInput.addEventListener('keypress', function(e) {
                        if (e.key === 'Enter') {
                            searchTrademark();
                        }
                    });
                }
            });

            async function searchTrademark() {
                const input = document.getElementById('trademark-search-input');
                const resultsDiv = document.getElementById('search-results');
                const searchTerm = input.value.trim();

                if (!searchTerm) {
                    resultsDiv.innerHTML = '<div class="notification is-warning">Please enter a trademark name to search.</div>';
                    return;
                }

                resultsDiv.innerHTML = '<div class="notification is-info">Searching...</div>';

                try {
                    const response = await fetch('/api/trademark/search', {
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                        },
                        body: JSON.stringify({
                            searchTerm: searchTerm,
                            exactMatch: false
                        })
                    });

                    if (!response.ok) {
                        throw new Error(`HTTP error! status: ${response.status}`);
                    }

                    const data = await response.json();

                    let resultsHtml = '<div class="card"><div class="card-content">';
                    resultsHtml += `<h4 class="title is-4">Search Results for "${searchTerm}"</h4>`;
                    resultsHtml += `<p><strong>Total Results:</strong> ${data.totalResults}</p>`;

                    if (data.results && data.results.length > 0) {
                        resultsHtml += '<div class="content"><h5>Similar Trademarks Found:</h5><ul>';
                        data.results.forEach(result => {
                            resultsHtml += `<li><strong>${result.markText}</strong> - Status: ${result.status} (Serial: ${result.serialNumber})</li>`;
                        });
                        resultsHtml += '</ul></div>';
                    } else {
                        resultsHtml += '<div class="notification is-success">No similar trademarks found! This name appears to be available.</div>';
                    }

                    if (data.neonLawConsultation && data.neonLawConsultation.available) {
                        resultsHtml += `<div class="notification is-info">
                            <strong>Professional Filing Available</strong><br>
                            Price per class: $${data.neonLawConsultation.pricePerClass}<br>
                            Contact: ${data.neonLawConsultation.contactEmail}
                        </div>`;
                    }

                    resultsHtml += '</div></div>';
                    resultsDiv.innerHTML = resultsHtml;

                } catch (error) {
                    console.error('Error searching trademarks:', error);
                    resultsDiv.innerHTML = '<div class="notification is-danger">Error performing search. Please try again.</div>';
                }
            }
            """
        }
    }
}

struct OnboardingStep: HTML {
    let number: String
    let title: String
    let description: String
    let details: [String]?

    init(number: String, title: String, description: String, details: [String]? = nil) {
        self.number = number
        self.title = title
        self.description = description
        self.details = details
    }

    var content: some HTML {
        div(.class("card step-card"), .style("margin-bottom: 1.5rem;")) {
            div(.class("card-content")) {
                div(.class("media")) {
                    div(.class("media-left")) {
                        span(.class("tag is-primary is-large")) { number }
                    }
                    div(.class("media-content")) {
                        h4(.class("title is-4")) { title }
                        p { description }
                        if let details = details {
                            ul {
                                for detail in details {
                                    li { detail }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
