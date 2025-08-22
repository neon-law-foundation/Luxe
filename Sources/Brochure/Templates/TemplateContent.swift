import Foundation

/// Contains the actual template content strings for all built-in templates.
public enum TemplateContent {

    // MARK: - Common Files

    public static let gitignore = """
        # Dependencies
        node_modules/
        vendor/

        # Build output
        dist/
        build/
        *.min.js
        *.min.css

        # IDE
        .vscode/
        .idea/
        *.swp
        *.swo
        .DS_Store

        # Environment
        .env
        .env.local

        # Logs
        *.log
        npm-debug.log*

        # Cache
        .cache/
        .tmp/
        """

    public static let robotsTxt = """
        User-agent: *
        Allow: /

        Sitemap: /sitemap.xml
        """

    public static let readmeMD = """
        # {{projectName}}

        {{description}}

        ## Overview

        This project was generated with [Brochure CLI](https://github.com/neon-law/Luxe) using the Landing Page template.

        ## Project Structure

        ```
        {{projectName}}/
        ├── src/              # Source files
        │   ├── index.html    # Main HTML file
        │   ├── styles/       # CSS files
        │   ├── scripts/      # JavaScript files
        │   └── assets/       # Images and other assets
        ├── dist/             # Build output (generated)
        └── README.md         # This file
        ```

        ## Getting Started

        ### Development

        1. Open `src/index.html` in your browser
        2. Edit the HTML, CSS, and JavaScript files in the `src` directory
        3. Refresh your browser to see changes

        ### Local Preview

        You can use Python's built-in server for local development:

        ```bash
        cd src
        python3 -m http.server 8000
        ```

        Then visit http://localhost:8000

        ## Deployment

        ### Using Brochure CLI

        ```bash
        brochure upload {{projectName}}
        ```

        This will upload your site to AWS S3 and make it available via CloudFront.

        ### Manual Deployment

        1. Build your site (if using a build process)
        2. Upload the contents of `dist/` or `src/` to your web server
        3. Configure your web server to serve `index.html` as the default page

        ## Customization

        ### Colors and Styling

        Edit `src/styles/main.css` to customize the appearance of your site.

        ### Content

        Update the content in `src/index.html` with your own text and images.

        ### Analytics

        {{#if analytics}}
        Analytics is configured with ID: {{analyticsId}}

        To change the analytics ID, update the Google Analytics script in `src/index.html`.
        {{/if}}

        ## Author

        {{author}}{{#if email}} - {{email}}{{/if}}

        ## License

        All rights reserved.

        ---

        Generated with ❤️ by [Brochure CLI](https://github.com/neon-law/Luxe)
        """

    // MARK: - Landing Page Template

    public static let landingPageHTML = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>{{projectName}}{{#if tagline}} - {{tagline}}{{/if}}</title>
            <meta name="description" content="{{description}}">

            {{#if seoEnabled}}
            <!-- SEO Meta Tags -->
            <meta property="og:title" content="{{projectName}}">
            <meta property="og:description" content="{{description}}">
            <meta property="og:type" content="website">
            <meta property="og:url" content="{{website|default:#}}">
            <meta name="twitter:card" content="summary_large_image">
            <meta name="twitter:title" content="{{projectName}}">
            <meta name="twitter:description" content="{{description}}">
            {{/if}}

            <link rel="stylesheet" href="styles/main.css">

            {{#if analytics}}
            <!-- Google Analytics -->
            <script async src="https://www.googletagmanager.com/gtag/js?id={{analyticsId}}"></script>
            <script>
                window.dataLayer = window.dataLayer || [];
                function gtag(){dataLayer.push(arguments);}
                gtag('js', new Date());
                gtag('config', '{{analyticsId}}');
            </script>
            {{/if}}
        </head>
        <body>
            <!-- Navigation -->
            <nav class="navbar">
                <div class="container">
                    <div class="navbar-brand">
                        <a href="/" class="logo">{{projectName}}</a>
                    </div>
                    <div class="navbar-menu">
                        <a href="#features" class="navbar-item">Features</a>
                        <a href="#about" class="navbar-item">About</a>
                        <a href="#contact" class="navbar-item">Contact</a>
                    </div>
                </div>
            </nav>

            <!-- Hero Section -->
            <section class="hero">
                <div class="container">
                    <div class="hero-content">
                        <h1 class="hero-title">{{projectName}}</h1>
                        <p class="hero-subtitle">{{description}}</p>
                        <div class="hero-actions">
                            <a href="#" class="btn btn-primary">Get Started</a>
                            <a href="#features" class="btn btn-secondary">Learn More</a>
                        </div>
                    </div>
                </div>
            </section>

            <!-- Features Section -->
            <section id="features" class="features">
                <div class="container">
                    <h2 class="section-title">Features</h2>
                    <div class="features-grid">
                        <div class="feature">
                            <div class="feature-icon">🚀</div>
                            <h3>Fast & Reliable</h3>
                            <p>Lightning-fast performance with 99.9% uptime guarantee.</p>
                        </div>
                        <div class="feature">
                            <div class="feature-icon">🔒</div>
                            <h3>Secure</h3>
                            <p>Enterprise-grade security to protect your data.</p>
                        </div>
                        <div class="feature">
                            <div class="feature-icon">📱</div>
                            <h3>Responsive</h3>
                            <p>Works perfectly on all devices and screen sizes.</p>
                        </div>
                    </div>
                </div>
            </section>

            <!-- About Section -->
            <section id="about" class="about">
                <div class="container">
                    <h2 class="section-title">About</h2>
                    <p>{{description}}</p>
                </div>
            </section>

            <!-- Contact Section -->
            <section id="contact" class="contact">
                <div class="container">
                    <h2 class="section-title">Contact</h2>
                    <p>Get in touch with us</p>
                    {{#if email}}
                    <p><a href="mailto:{{email}}" class="btn btn-primary">Send Email</a></p>
                    {{/if}}
                </div>
            </section>

            <!-- Footer -->
            <footer class="footer">
                <div class="container">
                    <p>&copy; {{currentYear}} {{projectName}}. All rights reserved.</p>
                    <p>Created by {{author}}</p>
                </div>
            </footer>

            <script src="scripts/main.js"></script>
        </body>
        </html>
        """

    public static let landingPageCSS = """
        /* Reset and Base Styles */
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        :root {
            --primary-color: #007bff;
            --secondary-color: #6c757d;
            --dark-color: #333;
            --light-color: #f8f9fa;
            --text-color: #212529;
            --border-radius: 8px;
            --transition: all 0.3s ease;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: var(--text-color);
            background-color: #fff;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 0 20px;
        }

        /* Navigation */
        .navbar {
            background-color: #fff;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            padding: 1rem 0;
            position: sticky;
            top: 0;
            z-index: 1000;
        }

        .navbar .container {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }

        .navbar-brand .logo {
            font-size: 1.5rem;
            font-weight: bold;
            color: var(--primary-color);
            text-decoration: none;
        }

        .navbar-menu {
            display: flex;
            gap: 2rem;
        }

        .navbar-item {
            color: var(--text-color);
            text-decoration: none;
            transition: var(--transition);
        }

        .navbar-item:hover {
            color: var(--primary-color);
        }

        /* Hero Section */
        .hero {
            background: linear-gradient(135deg, var(--primary-color), #0056b3);
            color: white;
            padding: 100px 0;
            text-align: center;
        }

        .hero-title {
            font-size: 3rem;
            margin-bottom: 1rem;
        }

        .hero-subtitle {
            font-size: 1.25rem;
            margin-bottom: 2rem;
            opacity: 0.9;
        }

        .hero-actions {
            display: flex;
            gap: 1rem;
            justify-content: center;
        }

        /* Buttons */
        .btn {
            display: inline-block;
            padding: 12px 30px;
            border-radius: var(--border-radius);
            text-decoration: none;
            font-weight: 500;
            transition: var(--transition);
            cursor: pointer;
        }

        .btn-primary {
            background-color: white;
            color: var(--primary-color);
        }

        .btn-primary:hover {
            background-color: var(--light-color);
        }

        .btn-secondary {
            background-color: transparent;
            color: white;
            border: 2px solid white;
        }

        .btn-secondary:hover {
            background-color: white;
            color: var(--primary-color);
        }

        /* Features Section */
        .features {
            padding: 80px 0;
            background-color: var(--light-color);
        }

        .section-title {
            font-size: 2.5rem;
            text-align: center;
            margin-bottom: 3rem;
            color: var(--dark-color);
        }

        .features-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 2rem;
        }

        .feature {
            background: white;
            padding: 2rem;
            border-radius: var(--border-radius);
            text-align: center;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
            transition: var(--transition);
        }

        .feature:hover {
            transform: translateY(-5px);
            box-shadow: 0 4px 16px rgba(0,0,0,0.15);
        }

        .feature-icon {
            font-size: 3rem;
            margin-bottom: 1rem;
        }

        .feature h3 {
            margin-bottom: 1rem;
            color: var(--dark-color);
        }

        /* About Section */
        .about {
            padding: 80px 0;
        }

        .about p {
            font-size: 1.125rem;
            max-width: 800px;
            margin: 0 auto;
            text-align: center;
        }

        /* Contact Section */
        .contact {
            padding: 80px 0;
            background-color: var(--light-color);
            text-align: center;
        }

        /* Footer */
        .footer {
            background-color: var(--dark-color);
            color: white;
            padding: 2rem 0;
            text-align: center;
        }

        .footer p {
            margin: 0.5rem 0;
        }

        /* Responsive Design */
        @media (max-width: 768px) {
            .navbar-menu {
                display: none;
            }

            .hero-title {
                font-size: 2rem;
            }

            .hero-subtitle {
                font-size: 1rem;
            }

            .hero-actions {
                flex-direction: column;
                align-items: center;
            }

            .features-grid {
                grid-template-columns: 1fr;
            }
        }
        """

    public static let landingPageJS = """
        // Smooth scrolling for navigation links
        document.querySelectorAll('a[href^="#"]').forEach(anchor => {
            anchor.addEventListener('click', function (e) {
                e.preventDefault();
                const target = document.querySelector(this.getAttribute('href'));
                if (target) {
                    target.scrollIntoView({
                        behavior: 'smooth',
                        block: 'start'
                    });
                }
            });
        });

        // Add active class to navigation items on scroll
        window.addEventListener('scroll', () => {
            const sections = document.querySelectorAll('section[id]');
            const scrollY = window.pageYOffset;

            sections.forEach(section => {
                const sectionHeight = section.offsetHeight;
                const sectionTop = section.offsetTop - 100;
                const sectionId = section.getAttribute('id');
                const navItem = document.querySelector(`.navbar-item[href="#${sectionId}"]`);

                if (navItem) {
                    if (scrollY > sectionTop && scrollY <= sectionTop + sectionHeight) {
                        navItem.classList.add('active');
                    } else {
                        navItem.classList.remove('active');
                    }
                }
            });
        });

        // Mobile menu toggle (if needed)
        const createMobileMenu = () => {
            const navbar = document.querySelector('.navbar');
            const navbarMenu = document.querySelector('.navbar-menu');

            if (window.innerWidth <= 768) {
                // Add mobile menu functionality here if needed
            }
        };

        window.addEventListener('resize', createMobileMenu);
        window.addEventListener('load', createMobileMenu);

        // Initialize any animations or interactions
        document.addEventListener('DOMContentLoaded', () => {
            console.log('{{projectName}} website loaded successfully!');
        });
        """

    // MARK: - Blog Template (simplified for brevity)

    public static let blogIndexHTML = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>{{blogTitle|default:projectName}}</title>
            <meta name="description" content="{{blogDescription|default:description}}">
            <link rel="stylesheet" href="styles/blog.css">
            {{#if rssEnabled}}<link rel="alternate" type="application/rss+xml" title="RSS" href="/rss.xml">{{/if}}
        </head>
        <body>
            <header class="header">
                <div class="container">
                    <h1>{{blogTitle|default:projectName}}</h1>
                    <p>{{blogDescription|default:description}}</p>
                </div>
            </header>

            <main class="container">
                <article class="post">
                    <h2><a href="posts/welcome.html">Welcome to Your Blog</a></h2>
                    <time>{{generatedDate}}</time>
                    <p>This is your first blog post. Edit or delete it, then start writing!</p>
                    <a href="posts/welcome.html" class="read-more">Read more →</a>
                </article>
            </main>

            <footer class="footer">
                <div class="container">
                    <p>&copy; {{currentYear}} {{blogTitle|default:projectName}}. Created by {{author}}.</p>
                </div>
            </footer>
        </body>
        </html>
        """

    public static let blogCSS = """
        /* Blog styles */
        body {
            font-family: Georgia, serif;
            line-height: 1.8;
            color: #333;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }

        .header {
            text-align: center;
            padding: 2rem 0;
            border-bottom: 1px solid #eee;
            margin-bottom: 2rem;
        }

        .post {
            margin-bottom: 3rem;
        }

        .post h2 {
            margin-bottom: 0.5rem;
        }

        .post time {
            color: #666;
            font-size: 0.9rem;
        }

        .read-more {
            color: #007bff;
            text-decoration: none;
        }

        .footer {
            margin-top: 4rem;
            padding-top: 2rem;
            border-top: 1px solid #eee;
            text-align: center;
            color: #666;
        }
        """

    public static let blogJS = """
        // Blog JavaScript
        console.log('Blog initialized');
        """

    public static let blogPostTemplate = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>{{postTitle}} - {{blogTitle}}</title>
            <link rel="stylesheet" href="../styles/blog.css">
        </head>
        <body>
            <header>
                <h1>{{postTitle}}</h1>
                <time>{{postDate}}</time>
            </header>

            <main>
                {{postContent}}
            </main>

            <footer>
                <a href="/">← Back to Blog</a>
            </footer>
        </body>
        </html>
        """

    public static let welcomePostMD = """
        # Welcome to Your Blog

        This is your first blog post created with Brochure CLI.

        ## Getting Started

        1. Edit this post or create new ones in the `src/posts` directory
        2. Use Markdown for formatting
        3. Deploy with `brochure upload {{projectName}}`

        Happy blogging!
        """

    public static let blogReadmeMD = """
        # {{blogTitle|default:projectName}}

        {{blogDescription|default:description}}

        ## About This Blog

        This blog was created with Brochure CLI using the Blog template.

        ## Features

        - Markdown support for posts
        - RSS feed generation
        - Responsive design
        - Categories and tags
        - Search functionality

        ## Writing Posts

        Create new posts in the `src/posts` directory as Markdown files.

        ## Deployment

        ```bash
        brochure upload {{projectName}}
        ```

        ---
        Generated with [Brochure CLI](https://github.com/neon-law/Luxe)
        """

    // MARK: - Other Templates (abbreviated for space)

    public static let aboutPageHTML = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>About - {{projectName}}</title>
        </head>
        <body>
            <h1>About</h1>
            <p>{{description}}</p>
            <p>Created by {{author}}</p>
        </body>
        </html>
        """

    public static let portfolioIndexHTML = landingPageHTML  // Reuse with modifications
    public static let portfolioCSS = landingPageCSS
    public static let portfolioJS = landingPageJS
    public static let portfolioAboutHTML = aboutPageHTML
    public static let portfolioReadmeMD = readmeMD

    public static let contactPageHTML = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Contact - {{projectName}}</title>
        </head>
        <body>
            <h1>Contact</h1>
            <p>Get in touch with {{author}}</p>
            {{#if email}}<p>Email: <a href="mailto:{{email}}">{{email}}</a></p>{{/if}}
        </body>
        </html>
        """

    public static let projectTemplateHTML = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <title>{{projectTitle}} - {{portfolioOwner}}</title>
        </head>
        <body>
            <h1>{{projectTitle}}</h1>
            <p>{{projectDescription}}</p>
        </body>
        </html>
        """

    public static let docsIndexHTML = blogIndexHTML  // Similar structure
    public static let docsCSS = blogCSS
    public static let docsJS = blogJS
    public static let docsReadmeMD = readmeMD
    public static let gettingStartedMD = welcomePostMD

    public static let ecommerceIndexHTML = landingPageHTML
    public static let storeCSS = landingPageCSS
    public static let storeJS = landingPageJS
    public static let ecommerceReadmeMD = readmeMD
    public static let productTemplateHTML = projectTemplateHTML
    public static let cartPageHTML = contactPageHTML
    public static let checkoutPageHTML = contactPageHTML
}
