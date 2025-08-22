import Foundation

/// Generates static HTML content for holiday pages.
///
/// ## Overview
/// This struct creates a professionally styled HTML page that informs visitors
/// that services are temporarily unavailable during holiday periods.
public struct HolidayHTMLGenerator {
    /// Generates the complete HTML content for holiday pages.
    ///
    /// ## Content
    /// The generated page includes:
    /// - Professional styling with responsive design
    /// - Holiday message
    /// - Information about the trifecta (Sagebrush Services, Neon Law, Neon Law Foundation)
    /// - Contact information (support@sagebrush.services)
    /// - Copyright notice with current year
    ///
    /// - Returns: Complete HTML document as a string
    public func generateHTML() -> String {
        let currentYear = Calendar.current.component(.year, from: Date())
        return """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>We are currently on holiday</title>
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                        line-height: 1.6;
                        color: #333;
                        max-width: 800px;
                        margin: 0 auto;
                        padding: 40px 20px;
                        background-color: #f5f5f5;
                    }
                    .container {
                        background-color: white;
                        border-radius: 8px;
                        padding: 40px;
                        box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                    }
                    h1 {
                        color: #2c3e50;
                        margin-bottom: 20px;
                    }
                    h2 {
                        color: #34495e;
                        margin-top: 30px;
                        margin-bottom: 15px;
                    }
                    .company {
                        margin-bottom: 25px;
                        padding: 20px;
                        background-color: #f8f9fa;
                        border-radius: 5px;
                    }
                    .company h3 {
                        color: #2c3e50;
                        margin-top: 0;
                    }
                    .contact {
                        background-color: #e8f4f8;
                        padding: 20px;
                        border-radius: 5px;
                        margin-top: 30px;
                        text-align: center;
                    }
                    .contact a {
                        color: #3498db;
                        text-decoration: none;
                        font-weight: bold;
                    }
                    .contact a:hover {
                        text-decoration: underline;
                    }
                    .emoji {
                        font-size: 48px;
                        text-align: center;
                        margin: 20px 0;
                    }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="emoji">🏖️</div>
                    <h1>We are currently on holiday</h1>

                    <p>Thank you for visiting. Our team is taking a well-deserved break to recharge and spend time with loved ones.</p>

                    <h2>About Our Organizations</h2>

                    <div class="company">
                        <h3>Neon Law</h3>
                        <p>Neon Law is a law firm PLLC in Nevada. Neon Law only sells bespoke legal services tailored to the needs of our clients. We choose matters that align with our mission to increase love and respect. Because Neon Law is a law firm only lawyers can participate in profit sharing.</p>
                    </div>

                    <div class="company">
                        <h3>Neon Law Foundation</h3>
                        <p>Neon Law Foundation is a 501(c)(3) non-profit. Our main deliverables are the OSS repository, Luxe, other open-source software development work to maintain our systems in perpetuity, and most importantly, building a community of people who believe in inclusion, privacy, and creating standards to advance access to justice.</p>
                    </div>

                    <div class="company">
                        <h3>Sagebrush Services</h3>
                        <p>Sagebrush Services is a Nevada corporation. Our goal is to be a trusted partner for all the boring but necessary tasks including:</p>
                        <ul>
                            <li>Mailroom: Send your mail here and we will scan it and upload it to our portal.</li>
                            <li>Entity Management: File and renew your Nevada and federal forms on time.</li>
                            <li>Cap Tables: Manage how to share the pie with teammates, advisors, and investors.</li>
                            <li>Personal Data: Protect your privacy by tracking who requests and retains your information.</li>
                        </ul>
                    </div>

                    <h2>How the trifecta works</h2>
                    <p>This repository is licensed from Neon Law Foundation, the act of writing software is also governed by the Foundation.</p>
                    <p>The operations of running the software are managed by Sagebrush Services. Continuous integration is NLF and continuous deployment is Sagebrush Services.</p>
                    <p>Sagebrush Services is where all non-legal-service work is billed from. Neon Law is where legal advice is billed from, such as contract review, estate plan creation, and bespoke litigation.</p>
                    <p>Sagebrush Services and Neon Law pledge 10% of gross revenue to the Neon Law Foundation.</p>
                    <p>Each entity has its own accounting ledger and bank accounts.</p>

                    <div class="contact">
                        <p><strong>Need assistance?</strong></p>
                        <p>Please contact us at <a href="mailto:support@sagebrush.services">support@sagebrush.services</a></p>
                        <p>We'll respond as soon as we return from holiday.</p>
                    </div>

                    <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 14px;">
                        <p>© \(currentYear) Neon Law. All rights reserved.</p>
                    </div>
                </div>
            </body>
            </html>
            """
    }
}
