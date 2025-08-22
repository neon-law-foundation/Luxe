import Elementary
import VaporElementary

// MARK: - Global Style Component
public struct StyleComponent: HTML {
    public init() {}

    public var content: some HTML {
        style {
            """
            /* Dazzler Signature Rounded Corner Styles */
            :root {
                --primary-color: #4169E1;
                --primary-light: #6B8FFF;
                --primary-dark: #2E4DBF;
                --text-on-primary: #FFFFFF;
                --background: #FFFFFF;
                --surface: #F8F9FA;
                --text: #1A1A1A;
                --text-muted: #6C757D;
                --border-radius: 8px;
                --border-radius-large: 12px;
                --border-radius-small: 6px;
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
                border-radius: var(--border-radius) !important;
            }

            /* Large rounded corners for prominent elements */
            .button.is-large,
            .hero .button,
            .card.hero-card {
                border-radius: var(--border-radius-large) !important;
            }

            /* Small rounded corners for compact elements */
            .button.is-small,
            .tag.is-small,
            .pagination-link.is-small {
                border-radius: var(--border-radius-small) !important;
            }

            /* Enhanced Button Gradients with Rounded Corners */
            .button.is-primary {
                background: linear-gradient(135deg,
                    var(--primary-color) 0%,
                    var(--primary-light) 100%);
                border: none;
                color: var(--text-on-primary);
                position: relative;
                overflow: hidden;
                transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            }

            .button.is-primary::before {
                content: '';
                position: absolute;
                top: 0;
                left: -100%;
                width: 100%;
                height: 100%;
                background: linear-gradient(90deg,
                    transparent,
                    rgba(255, 255, 255, 0.2),
                    transparent);
                transition: left 0.5s ease;
            }

            .button.is-primary:hover::before {
                left: 100%;
            }

            .button.is-primary:hover {
                transform: translateY(-2px);
                box-shadow: 0 10px 30px rgba(65, 105, 225, 0.3);
            }

            /* Info Button Gradient */
            .button.is-info {
                background: linear-gradient(135deg,
                    #3298dc 0%,
                    #5bc0de 100%);
                border: none;
                color: white;
            }

            .button.is-info:hover {
                transform: translateY(-2px);
                box-shadow: 0 8px 25px rgba(50, 152, 220, 0.3);
            }

            /* Smooth Hover Effects */
            .smooth-hover {
                transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            }

            .smooth-hover:hover {
                transform: translateY(-2px);
                box-shadow: 0 8px 25px rgba(0, 0, 0, 0.15);
            }

            /* Card Enhancements with Rounded Corners */
            .card {
                transition: all 0.3s ease;
                border: 1px solid rgba(219, 219, 219, 0.3);
            }

            .card:hover {
                transform: translateY(-4px);
                box-shadow: 0 15px 40px rgba(0, 0, 0, 0.1);
            }

            /* Special Card Types */
            .feature-card {
                background: linear-gradient(180deg,
                    rgba(255, 255, 255, 0.95) 0%,
                    rgba(248, 249, 250, 0.95) 100%);
                backdrop-filter: blur(10px);
            }

            .pricing-card {
                background: linear-gradient(135deg,
                    var(--primary-color) 0%,
                    var(--primary-light) 100%);
                color: white;
            }

            .pricing-card .title,
            .pricing-card .content {
                color: white;
            }

            .service-card {
                border: 2px solid transparent;
                background: linear-gradient(white, white) padding-box,
                            linear-gradient(135deg,
                                var(--primary-color),
                                var(--primary-light)) border-box;
            }

            /* Hero Section Enhancements */
            .hero.is-primary {
                background: linear-gradient(135deg,
                    var(--primary-color) 0%,
                    var(--primary-light) 100%);
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
                background: radial-gradient(
                    circle,
                    rgba(255, 255, 255, 0.1) 0%,
                    transparent 70%
                );
                animation: float 20s infinite ease-in-out;
            }

            @keyframes float {
                0%, 100% { transform: translate(0, 0) rotate(0deg); }
                50% { transform: translate(-20px, -20px) rotate(180deg); }
            }

            /* Input Field Rounded Corners */
            .field .control .input,
            .field .control .textarea,
            .field .control .select select {
                border-radius: var(--border-radius);
                border: 1px solid #dbdbdb;
                transition: border-color 0.3s ease;
            }

            .field .control .input:focus,
            .field .control .textarea:focus,
            .field .control .select select:focus {
                border-color: var(--primary-color);
                box-shadow: 0 0 0 0.125em rgba(65, 105, 225, 0.25);
            }

            /* Modal Rounded Corners */
            .modal-card {
                border-radius: var(--border-radius-large);
            }

            .modal-card-head,
            .modal-card-foot {
                border-radius: var(--border-radius-large) var(--border-radius-large) 0 0;
            }

            .modal-card-foot {
                border-radius: 0 0 var(--border-radius-large) var(--border-radius-large);
            }

            /* Notification Rounded Corners */
            .notification {
                border-radius: var(--border-radius);
            }

            /* Touch-Optimized Design */
            .touch-target {
                min-height: 44px;
                min-width: 44px;
                display: flex;
                align-items: center;
                justify-content: center;
                border-radius: var(--border-radius);
            }

            /* Button Group Spacing */
            .buttons .button {
                margin-right: 0.5rem;
                margin-bottom: 0.5rem;
            }

            .buttons .button:last-child {
                margin-right: 0;
            }

            /* Responsive Adjustments */
            @media screen and (max-width: 768px) {
                .button.is-fullwidth-mobile {
                    width: 100%;
                    margin-bottom: 0.75rem;
                }

                .buttons.is-centered .button {
                    margin: 0.25rem;
                }
            }

            /* Focus States for Accessibility */
            .button:focus,
            .card:focus,
            .input:focus,
            .textarea:focus,
            .select select:focus {
                outline: 2px solid var(--primary-color);
                outline-offset: 2px;
                border-radius: var(--border-radius);
            }

            /* Loading States */
            .button.is-loading::after {
                border-radius: 50%;
            }
            """
        }
    }
}
