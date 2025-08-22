import Elementary
import VaporElementary

public struct HeaderComponent: HTML {
    public let primaryColor: String
    public let secondaryColor: String

    public init(primaryColor: String, secondaryColor: String) {
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
    }

    public var content: some HTML {
        meta(.charset(.utf8))
        meta(.name(.viewport), .content("width=device-width, initial-scale=1"))
        link(.rel(.icon), .href("/favicon.ico"))
        link(.rel(.stylesheet), .href("https://cdn.jsdelivr.net/npm/bulma@0.9.4/css/bulma.min.css"))
        style {
            """
            :root {
                --primary-color: \(primaryColor);
                --secondary-color: \(secondaryColor);
                --primary-light: #228B22;
                --primary-dark: #004000;
                --secondary-light: #FFD700;
                --secondary-dark: #B8860B;
                --text-on-primary: #FFFFFF;
                --surface: #F8F9FA;
                --gradient-primary: linear-gradient(135deg, var(--primary-color) 0%, var(--primary-light) 100%);
                --gradient-secondary: linear-gradient(135deg, var(--secondary-color) 0%, var(--secondary-light) 100%);
                --gradient-hero: linear-gradient(135deg, var(--primary-color) 0%, var(--primary-light) 50%, var(--secondary-color) 100%);
                --font-family: "Helvetica", sans-serif;
                --font-family-monospace: "Monaco", monospace;
            }

            /* Global Font Stack - Helvetica as Primary */
            body,
            html,
            .button,
            .input,
            .textarea,
            .select select,
            .navbar,
            .hero,
            .title,
            .subtitle,
            .content,
            .card,
            .notification {
                font-family: var(--font-family);
            }

            /* Monospace Font for Code Elements */
            code,
            pre,
            .code,
            .language-yaml,
            .language-json,
            .language-sql,
            .language-swift,
            kbd,
            samp,
            var {
                font-family: var(--font-family-monospace);
            }

            /* Hero Gradients */
            .hero.is-primary {
                background: var(--gradient-hero) !important;
                position: relative;
                overflow: hidden;
            }

            .hero.is-primary::before {
                content: '';
                position: absolute;
                top: -50%;
                right: -50%;
                width: 200%;
                height: 200%;
                background: radial-gradient(circle, rgba(255, 255, 255, 0.1) 0%, transparent 70%);
                animation: float 20s infinite ease-in-out;
                pointer-events: none;
            }

            @keyframes float {
                0%, 100% { transform: translate(0, 0) rotate(0deg); }
                50% { transform: translate(-20px, -20px) rotate(180deg); }
            }

            /* Navigation Gradients */
            .navbar.is-primary {
                background: var(--gradient-primary) !important;
                box-shadow: 0 2px 10px rgba(0, 100, 0, 0.2);
            }

            /* Global Rounded Corner Enforcement */
            .button,
            .card,
            .box,
            .notification,
            .input,
            .textarea,
            .select select,
            .file-cta,
            .file-name,
            .pagination-previous,
            .pagination-next,
            .pagination-link,
            .tag {
                border-radius: 8px !important;
            }

            /* Large rounded corners for prominent elements */
            .button.is-large,
            .hero .button,
            .card.hero-card {
                border-radius: 12px !important;
            }

            /* Small rounded corners for compact elements */
            .button.is-small,
            .tag.is-small,
            .pagination-link.is-small {
                border-radius: 6px !important;
            }

            /* Button Gradients */
            .button.is-primary {
                background: var(--gradient-primary) !important;
                border: none !important;
                color: var(--text-on-primary) !important;
                box-shadow: 0 4px 15px rgba(0, 100, 0, 0.3);
                transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
                position: relative;
                overflow: hidden;
                border-radius: 8px !important;
            }

            .button.is-primary::before {
                content: '';
                position: absolute;
                top: 0;
                left: -100%;
                width: 100%;
                height: 100%;
                background: linear-gradient(90deg, transparent, rgba(255, 255, 255, 0.2), transparent);
                transition: left 0.5s ease;
            }

            .button.is-primary:hover::before {
                left: 100%;
            }

            .button.is-primary:hover {
                transform: translateY(-2px);
                box-shadow: 0 6px 20px rgba(0, 100, 0, 0.4);
            }

            .button.is-info {
                background: var(--gradient-secondary) !important;
                border: none !important;
                color: #2C3E50 !important;
                font-weight: 600;
                box-shadow: 0 4px 15px rgba(218, 165, 32, 0.3);
                transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
                border-radius: 8px !important;
            }

            .button.is-info:hover {
                transform: translateY(-2px);
                box-shadow: 0 6px 20px rgba(218, 165, 32, 0.4);
            }

            /* Text Gradients */
            .has-text-primary {
                background: var(--gradient-primary);
                -webkit-background-clip: text;
                -webkit-text-fill-color: transparent;
                background-clip: text;
                font-weight: 700;
            }

            .title.has-text-primary {
                background: var(--gradient-primary);
                -webkit-background-clip: text;
                -webkit-text-fill-color: transparent;
                background-clip: text;
            }

            .has-background-primary {
                background: var(--gradient-primary) !important;
            }
            /* Card Gradient Styles */
            .card {
                background: linear-gradient(180deg, rgba(255, 255, 255, 0.95) 0%, rgba(248, 249, 250, 0.95) 100%);
                backdrop-filter: blur(10px);
                border-radius: 12px;
                box-shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
                transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            }

            .card:hover {
                transform: translateY(-5px);
                box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);
            }

            .card-header {
                background: var(--gradient-secondary);
                color: #2C3E50;
                font-weight: 600;
                border-radius: 12px 12px 0 0;
            }

            .pricing-card {
                border: 2px solid transparent;
                background: linear-gradient(white, white) padding-box,
                           var(--gradient-secondary) border-box;
                border-radius: 16px;
                box-shadow: 0 15px 35px rgba(218, 165, 32, 0.2);
            }

            .step-card {
                border-left: 6px solid transparent;
                background: linear-gradient(white, white) padding-box,
                           var(--gradient-secondary) border-box;
                background-clip: padding-box, border-box;
                padding-left: 24px;
            }

            .feature-card {
                border: 2px solid transparent;
                background: linear-gradient(rgba(255, 255, 255, 0.9), rgba(248, 249, 250, 0.9)) padding-box,
                           var(--gradient-primary) border-box;
                border-radius: 16px;
                box-shadow: 0 15px 35px rgba(0, 100, 0, 0.15);
            }

            .standards-card {
                border-left: 6px solid transparent;
                background: linear-gradient(white, white) padding-box,
                           var(--gradient-primary) border-box;
                background-clip: padding-box, border-box;
                padding-left: 24px;
            }

            .service-card {
                border: 2px solid transparent;
                background: linear-gradient(rgba(255, 255, 255, 0.95), rgba(248, 249, 250, 0.95)) padding-box,
                           var(--gradient-secondary) border-box;
                transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
                border-radius: 16px;
            }

            .service-card:hover {
                transform: translateY(-8px);
                box-shadow: 0 25px 50px rgba(218, 165, 32, 0.3);
            }

            .contact-card {
                border: 2px solid transparent;
                background: linear-gradient(white, white) padding-box,
                           var(--gradient-primary) border-box;
                border-radius: 16px;
            }
            /* Section Background Gradients */
            .has-background-light {
                background: linear-gradient(135deg, #F8F9FA 0%, #E9ECEF 100%) !important;
            }

            .has-background-primary-light {
                background: linear-gradient(135deg, rgba(0, 100, 0, 0.1) 0%, rgba(218, 165, 32, 0.1) 100%) !important;
            }

            /* Notification Gradient Styles */
            .notification.is-info {
                background: var(--gradient-secondary) !important;
                color: #2C3E50 !important;
                border: none;
                box-shadow: 0 10px 25px rgba(218, 165, 32, 0.2);
            }

            .notification.is-info.is-light {
                background: linear-gradient(135deg, rgba(218, 165, 32, 0.1) 0%, rgba(255, 215, 0, 0.1) 100%) !important;
                border: 2px solid rgba(218, 165, 32, 0.3);
                color: #2C3E50;
            }

            /* Enhanced Typography */
            .title {
                font-weight: 700;
                letter-spacing: -0.02em;
            }

            .subtitle {
                font-weight: 400;
                opacity: 0.9;
            }

            /* Smooth Animations */
            .smooth-hover {
                transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            }

            .smooth-hover:hover {
                transform: translateY(-2px);
            }

            /* Focus States */
            *:focus {
                outline: 2px solid var(--secondary-color);
                outline-offset: 2px;
                border-radius: 4px;
            }

            /* Responsive Adjustments */
            @media screen and (max-width: 768px) {
                .hero.is-primary::before {
                    animation-duration: 30s;
                }

                .card:hover {
                    transform: translateY(-3px);
                }

                .service-card:hover {
                    transform: translateY(-3px);
                }
            }

            a {
                cursor: pointer;
            }

            /* Mobile Navigation Styles */
            @media screen and (max-width: 1023px) {
                .navbar-menu {
                    display: none;
                }

                .navbar-menu.is-active {
                    display: block;
                    box-shadow: 0 8px 16px rgba(10, 10, 10, 0.1);
                }

                .navbar-burger {
                    color: white;
                    cursor: pointer;
                    display: block;
                    height: 3.25rem;
                    position: relative;
                    width: 3.25rem;
                    margin-left: auto;
                }

                .navbar-burger span {
                    background-color: currentColor;
                    display: block;
                    height: 1px;
                    left: calc(50% - 8px);
                    position: absolute;
                    transform-origin: center;
                    transition-duration: 86ms;
                    transition-property: background-color, opacity, transform;
                    transition-timing-function: ease-out;
                    width: 16px;
                }

                .navbar-burger span:nth-child(1) {
                    top: calc(50% - 6px);
                }

                .navbar-burger span:nth-child(2) {
                    top: calc(50% - 1px);
                }

                .navbar-burger span:nth-child(3) {
                    top: calc(50% + 4px);
                }

                .navbar-burger span:nth-child(4) {
                    top: calc(50% + 9px);
                }

                .navbar-burger:hover {
                    background-color: rgba(0, 0, 0, 0.05);
                }

                .navbar-burger.is-active span:nth-child(1) {
                    transform: translateY(5px) rotate(45deg);
                }

                .navbar-burger.is-active span:nth-child(2) {
                    opacity: 0;
                }

                .navbar-burger.is-active span:nth-child(3) {
                    transform: translateY(-5px) rotate(-45deg);
                }

                .navbar-burger.is-active span:nth-child(4) {
                    opacity: 0;
                }
            }

            @media screen and (min-width: 1024px) {
                .navbar-burger {
                    display: none;
                }

                .navbar-menu {
                    display: flex;
                }
            }
            """
        }
        MobileNavigationScript()
    }
}

// Convenience initializers for specific color schemes
extension HeaderComponent {
    public static func sagebrushTheme() -> HeaderComponent {
        HeaderComponent(primaryColor: "#006400", secondaryColor: "#DAA520")
    }

    public static func standardsTheme() -> HeaderComponent {
        HeaderComponent(primaryColor: "#663399", secondaryColor: "#FFB6C1")
    }

    public static func neonLawTheme() -> HeaderComponent {
        HeaderComponent(primaryColor: "#4169E1", secondaryColor: "#E19741")
    }
}
