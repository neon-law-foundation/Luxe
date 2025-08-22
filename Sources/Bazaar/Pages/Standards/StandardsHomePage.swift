import Elementary
import TouchMenu

struct StandardsHomePage: HTML {
    var content: some HTML {
        // Existing HTML content from the Standards App.swift file
        HTMLRaw(
            """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <title>Sagebrush Standards - Computable Document Workflows</title>
                <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bulma@0.9.4/css/bulma.min.css">
                <style>
                    :root {
                        --primary-color: #663399;
                        --secondary-color: #FFB6C1;
                    }
                    .hero.is-primary {
                        background-color: var(--primary-color) !important;
                    }
                    .button.is-primary {
                        background-color: var(--primary-color) !important;
                        border-color: var(--primary-color) !important;
                    }
                    .button.is-info {
                        background-color: var(--secondary-color) !important;
                        border-color: var(--secondary-color) !important;
                        color: #363636 !important;
                    }
                    .navbar.is-primary {
                        background-color: var(--primary-color) !important;
                    }
                    .has-text-primary {
                        color: var(--primary-color) !important;
                    }
                    .has-background-primary {
                        background-color: var(--primary-color) !important;
                    }
                    .card-header {
                        background-color: var(--secondary-color);
                    }
                    .pricing-card {
                        border: 3px solid var(--secondary-color);
                    }
                    .step-card {
                        border-left: 4px solid var(--secondary-color);
                    }
                    .feature-card {
                        border: 3px solid var(--secondary-color);
                    }
                    .standards-card {
                        border-left: 4px solid var(--secondary-color);
                    }
                    a {
                        cursor: pointer;
                    }
                </style>
            </head>
            <body>
                <nav class="navbar is-primary" role="navigation">
                    <div class="navbar-brand">
                        <a class="navbar-item" href="/standards">
                            <strong>Sagebrush Standards</strong>
                        </a>
                    </div>
                    <div class="navbar-menu">
                        <div class="navbar-start">
                            <a class="navbar-item" href="/standards">Home</a>
                            <a class="navbar-item" href="/standards/spec">Specification</a>
                            <a class="navbar-item" href="/standards/notations">Notations</a>
                        </div>
                        <div class="navbar-end">
                            <div class="navbar-item">
                                <div class="buttons">
                                    <a class="button is-light is-rounded" href="/">Back to Sagebrush</a>
                                    <a class="button is-light is-rounded" href="mailto:standards@sagebrush.services">Contact</a>
                                </div>
                            </div>
                        </div>
                    </div>
                </nav>

                <section class="hero is-primary is-medium">
                    <div class="hero-body">
                        <div class="container has-text-centered">
                            <h1 class="title is-1">Sagebrush Standards</h1>
                            <h2 class="subtitle is-3">Computable document workflows for modern organizations</h2>
                            <div class="buttons is-centered">
                                <a class="button is-info is-large is-rounded" href="/standards/spec">Read the Specification</a>
                                <a class="button is-light is-large is-rounded" href="/standards/notations">View Notations</a>
                            </div>
                        </div>
                    </div>
                </section>

                <section class="section">
                    <div class="container">
                        <div class="columns is-vcentered">
                            <div class="column is-half">
                                <h2 class="title is-2 has-text-primary">What are Sagebrush Standards?</h2>
                                <div class="content is-large">
                                    <p>Sagebrush Standards are computable document workflows that combine documents, questionnaires, and automated workflows to create a seamless experience for organizations.</p>
                                    <ul>
                                        <li>📋 <strong>Alignments</strong> - Staff review and verification questionnaires</li>
                                        <li>🔄 <strong>Flows</strong> - Client-filled questionnaires and workflows</li>
                                        <li>❓ <strong>Questions</strong> - Structured data collection components</li>
                                        <li>📄 <strong>PDF Overlays</strong> - Precise document mapping with coordinate dictionaries</li>
                                        <li>🔧 <strong>Notations</strong> - Reusable document generation patterns</li>
                                    </ul>
                                </div>
                            </div>
                            <div class="column is-half">
                                <figure class="image">
                                    <div class="has-background-light" style="height: 300px; display: flex; align-items: center; justify-content: center;">
                                        <span class="has-text-grey">Workflow Diagram Placeholder</span>
                                    </div>
                                </figure>
                            </div>
                        </div>
                    </div>
                </section>

                <section class="section has-background-light">
                    <div class="container">
                        <h2 class="title is-2 has-text-primary has-text-centered">Core Components</h2>
                        <div class="columns">
                            <div class="column">
                                <div class="card feature-card">
                                    <div class="card-header">
                                        <p class="card-header-title">🔄 Flows</p>
                                    </div>
                                    <div class="card-content">
                                        <div class="content">
                                            <p>Client-facing questionnaires that guide users through data collection workflows. Flows automate the gathering of required information for document generation.</p>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            <div class="column">
                                <div class="card feature-card">
                                    <div class="card-header">
                                        <p class="card-header-title">📋 Alignments</p>
                                    </div>
                                    <div class="card-content">
                                        <div class="content">
                                            <p>Staff review questionnaires that enable human-in-the-loop verification. Alignments ensure quality control and compliance before document finalization.</p>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            <div class="column">
                                <div class="card feature-card">
                                    <div class="card-header">
                                        <p class="card-header-title">❓ Questions</p>
                                    </div>
                                    <div class="card-content">
                                        <div class="content">
                                            <p>Structured data collection components that capture specific information types. Questions form the building blocks of flows and alignments.</p>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </section>

                <section class="section">
                    <div class="container has-text-centered">
                        <h2 class="title is-2 has-text-primary">Ready to Implement Standards?</h2>
                        <p class="subtitle">Join organizations using Sagebrush Standards for efficient document workflows</p>
                        <div class="buttons is-centered">
                            <a class="button is-primary is-large is-rounded" href="/standards/spec">Read the Specification</a>
                            <a class="button is-light is-large is-rounded" href="mailto:standards@sagebrush.services">Contact Us</a>
                        </div>
                    </div>
                </section>

                <footer class="footer has-background-dark has-text-light">
                    <div class="container">
                        <div class="columns">
                            <div class="column is-half">
                                <h4 class="title is-5 has-text-light">Our Network</h4>
                                <div class="content">
                                    <ul>
                                        <li><a class="has-text-light" href="https://www.neonlaw.com" target="_blank">Neon Law</a></li>
                                        <li><a class="has-text-light" href="https://www.neonlaw.org" target="_blank">Neon Law Foundation</a></li>
                                        <li><a class="has-text-light" href="https://www.sagebrush.services" target="_blank">Sagebrush Services</a></li>
                                        <li><a class="has-text-light" href="https://standards.sagebrush.services" target="_blank">Sagebrush Standards</a></li>
                                    </ul>
                                </div>
                            </div>
                            <div class="column is-half">
                                <h4 class="title is-5 has-text-light">Contact</h4>
                                <div class="content">
                                    <p>Support: <a class="has-text-light" href="mailto:support@sagebrush.services">support@sagebrush.services</a></p>
                                </div>
                            </div>
                        </div>
                        <hr class="has-background-grey">
                        <div class="has-text-centered">
                            <p class="has-text-grey-light">© 2025 Sagebrush. All rights reserved.</p>
                        </div>
                    </div>
                </footer>
            </body>
            </html>
            """
        )
    }
}
