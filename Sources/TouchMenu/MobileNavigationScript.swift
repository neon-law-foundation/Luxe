import Elementary

public struct MobileNavigationScript: HTML {
    public init() {}

    public var content: some HTML {
        script(.type("text/javascript")) {
            HTMLRaw(
                """
                function toggleMobileMenu() {
                    const burgerMenu = document.querySelector('.navbar-burger');
                    const navbarMenu = document.querySelector('.navbar-menu');

                    if (burgerMenu && navbarMenu) {
                        // Toggle the 'is-active' class on both burger and menu
                        burgerMenu.classList.toggle('is-active');
                        navbarMenu.classList.toggle('is-active');

                        // Update aria-expanded for accessibility
                        const isExpanded = burgerMenu.classList.contains('is-active');
                        burgerMenu.setAttribute('aria-expanded', isExpanded.toString());
                    }
                }

                // Setup mobile navigation on page load
                document.addEventListener('DOMContentLoaded', function() {
                    const burgerMenu = document.querySelector('.navbar-burger');
                    const navbarMenu = document.querySelector('.navbar-menu');

                    if (burgerMenu && navbarMenu) {
                        // Add required attributes
                        burgerMenu.setAttribute('aria-label', 'menu');
                        burgerMenu.setAttribute('aria-expanded', 'false');
                        burgerMenu.setAttribute('data-target', 'navbarMenu');

                        // Add click handler
                        burgerMenu.addEventListener('click', function(event) {
                            event.preventDefault();
                            toggleMobileMenu();
                        });

                        // Add keyboard support
                        burgerMenu.addEventListener('keydown', function(event) {
                            // Toggle on Enter or Space key
                            if (event.key === 'Enter' || event.key === ' ') {
                                event.preventDefault();
                                toggleMobileMenu();
                            }
                        });

                        // Add aria-hidden to burger spans
                        const spans = burgerMenu.querySelectorAll('span');
                        spans.forEach(span => {
                            span.setAttribute('aria-hidden', 'true');
                        });
                    }
                });

                // Close mobile menu when clicking outside of it
                document.addEventListener('click', function(event) {
                    const navbar = document.querySelector('.navbar');
                    const burgerMenu = document.querySelector('.navbar-burger');
                    const navbarMenu = document.querySelector('.navbar-menu');

                    if (navbar && burgerMenu && navbarMenu) {
                        const isClickInsideNavbar = navbar.contains(event.target);
                        const isMenuOpen = navbarMenu.classList.contains('is-active');

                        if (!isClickInsideNavbar \u{26}\u{26} isMenuOpen) {
                            burgerMenu.classList.remove('is-active');
                            navbarMenu.classList.remove('is-active');
                            burgerMenu.setAttribute('aria-expanded', 'false');
                        }
                    }
                });

                // Close mobile menu on window resize to desktop size
                window.addEventListener('resize', function() {
                    const burgerMenu = document.querySelector('.navbar-burger');
                    const navbarMenu = document.querySelector('.navbar-menu');

                    if (burgerMenu && navbarMenu && window.innerWidth >= 1024) {
                        burgerMenu.classList.remove('is-active');
                        navbarMenu.classList.remove('is-active');
                        burgerMenu.setAttribute('aria-expanded', 'false');
                    }
                });
                """
            )
        }
    }
}
