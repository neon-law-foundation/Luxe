// TarotSwift - Professional Astrology Interactive Experience
document.addEventListener('DOMContentLoaded', function() {
    
    // Professional astrology interaction tracking
    function trackAstrologyInteraction(action, element) {
        console.log(`Astrology interaction: ${action} on ${element}`);
        // Could integrate with analytics for professional insights
        if (typeof gtag !== 'undefined') {
            gtag('event', 'astrology_interaction', {
                'event_category': 'professional_astrology',
                'event_label': `${action}_${element}`,
                'value': 1
            });
        }
    }
    
    // Email click tracking for booking conversions
    const emailLinks = document.querySelectorAll('a[href^="mailto:team@tarotswift.me"]');
    emailLinks.forEach(link => {
        link.addEventListener('click', function() {
            const source = this.closest('.cosmic-hero') ? 'hero' :
                          this.closest('.cosmic-services') ? 'services' :
                          this.closest('.contact-section') ? 'contact' :
                          this.closest('.final-cosmic-cta') ? 'final_cta' :
                          this.closest('footer') ? 'footer' :
                          this.closest('nav') ? 'navigation' :
                          this.closest('.about-section') ? 'about' :
                          this.closest('.precision-section') ? 'precision' :
                          'unknown';
            trackAstrologyInteraction('email_click', source);
        });
    });
    
    // Professional button hover effects
    const cosmicButtons = document.querySelectorAll('.cosmic-button');
    cosmicButtons.forEach(button => {
        button.addEventListener('mouseenter', function() {
            this.style.animation = 'cosmicPulse 0.6s ease-in-out';
        });
        
        button.addEventListener('animationend', function() {
            this.style.animation = '';
        });
        
        button.addEventListener('click', function() {
            // Create professional sparkle effect
            createSparkleEffect(this);
            trackAstrologyInteraction('cta_click', this.textContent.trim().toLowerCase().replace(/\s+/g, '_'));
        });
    });
    
    function createSparkleEffect(element) {
        const rect = element.getBoundingClientRect();
        const sparkleCount = 8; // More subtle for professional setting
        
        for (let i = 0; i < sparkleCount; i++) {
            const sparkle = document.createElement('div');
            sparkle.style.cssText = `
                position: fixed;
                width: 3px;
                height: 3px;
                background: #f59e0b;
                border-radius: 50%;
                pointer-events: none;
                z-index: 10000;
                left: ${rect.left + rect.width / 2}px;
                top: ${rect.top + rect.height / 2}px;
                animation: sparkleOut 0.8s ease-out forwards;
            `;
            
            const angle = (i / sparkleCount) * 2 * Math.PI;
            const distance = 40 + Math.random() * 20;
            
            sparkle.style.setProperty('--end-x', `${Math.cos(angle) * distance}px`);
            sparkle.style.setProperty('--end-y', `${Math.sin(angle) * distance}px`);
            
            document.body.appendChild(sparkle);
            
            setTimeout(() => sparkle.remove(), 800);
        }
    }
    
    // Add sparkle animation CSS if not already present
    if (!document.querySelector('#sparkle-styles')) {
        const sparkleStyle = document.createElement('style');
        sparkleStyle.id = 'sparkle-styles';
        sparkleStyle.textContent = `
            @keyframes cosmicPulse {
                0%, 100% { transform: scale(1); }
                50% { transform: scale(1.05); box-shadow: 0 0 30px rgba(139, 92, 246, 0.6); }
            }
            
            @keyframes sparkleOut {
                0% {
                    transform: translate(0, 0) scale(1);
                    opacity: 1;
                }
                100% {
                    transform: translate(var(--end-x), var(--end-y)) scale(0);
                    opacity: 0;
                }
            }
        `;
        document.head.appendChild(sparkleStyle);
    }
    
    // Smooth scrolling for navigation
    const navLinks = document.querySelectorAll('nav a[href^="#"]');
    navLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            const targetId = this.getAttribute('href');
            const targetSection = document.querySelector(targetId);
            if (targetSection) {
                targetSection.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
                trackAstrologyInteraction('navigation', targetId.replace('#', ''));
            }
        });
    });
    
    // Professional scroll effects with parallax
    window.addEventListener('scroll', function() {
        const scrolled = window.pageYOffset;
        const rate = scrolled * -0.3; // Subtle parallax for professional feel
        
        // Parallax effect for stars background
        const starsBackgrounds = document.querySelectorAll('.stars-background');
        starsBackgrounds.forEach(stars => {
            stars.style.transform = `translateY(${rate}px)`;
        });
        
        // Fade in animations for sections
        const sections = document.querySelectorAll('section');
        sections.forEach(section => {
            const sectionTop = section.offsetTop;
            const sectionHeight = section.offsetHeight;
            const windowHeight = window.innerHeight;
            
            if (scrolled + windowHeight > sectionTop + 100) {
                section.style.opacity = '1';
                section.style.transform = 'translateY(0)';
            }
        });
    });
    
    // Initialize section animations
    const sections = document.querySelectorAll('section');
    sections.forEach(section => {
        section.style.opacity = '0';
        section.style.transform = 'translateY(30px)';
        section.style.transition = 'opacity 0.8s ease, transform 0.8s ease';
    });
    
    // Show first section immediately
    if (sections.length > 0) {
        sections[0].style.opacity = '1';
        sections[0].style.transform = 'translateY(0)';
    }
    
    // Professional form enhancement (if any forms are added later)
    const forms = document.querySelectorAll('form');
    forms.forEach(form => {
        form.addEventListener('submit', function(e) {
            trackAstrologyInteraction('form_submit', 'booking_form');
        });
    });
    
    // Page visibility tracking for engagement
    document.addEventListener('visibilitychange', function() {
        if (document.visibilityState === 'visible') {
            console.log('Client returned to astrology consultation page');
            trackAstrologyInteraction('page_return', document.title.toLowerCase().replace(/\s+/g, '_'));
        }
    });
    
    // Add structured data for astrology services
    function addAstrologyStructuredData() {
        // Only add if not already present
        if (document.querySelector('script[type="application/ld+json"]')) {
            return;
        }
        
        const structuredData = {
            "@context": "https://schema.org",
            "@type": "Service",
            "name": "TarotSwift Personal Astrology Readings",
            "description": "Professional multi-tradition astrology readings combining Western, Vedic, and Chinese astrology by certified astrologer Nick",
            "provider": {
                "@type": "Person",
                "name": "Nick",
                "memberOf": {
                    "@type": "Organization",
                    "name": "Sagebrush Services"
                }
            },
            "serviceType": [
                "Birth Chart Reading", 
                "Compatibility Analysis", 
                "Multi-Tradition Astrology", 
                "Professional Astrology Consultation"
            ],
            "areaServed": "Worldwide",
            "offers": {
                "@type": "Offer",
                "price": "444",
                "priceCurrency": "USD",
                "description": "2-hour personalized astrology reading including Western Placidus, Vedic Jyotish, and Chinese astrology analysis"
            },
            "hasOfferCatalog": {
                "@type": "OfferCatalog",
                "name": "Professional Astrology Services",
                "itemListElement": [
                    {
                        "@type": "Offer",
                        "itemOffered": {
                            "@type": "Service",
                            "name": "Birth Chart Reading",
                            "description": "Comprehensive natal chart analysis using Western, Vedic, and Chinese astrological traditions"
                        }
                    },
                    {
                        "@type": "Offer", 
                        "itemOffered": {
                            "@type": "Service",
                            "name": "Compatibility Reading",
                            "description": "Relationship analysis through multi-tradition chart comparison and synastry"
                        }
                    }
                ]
            }
        };
        
        const script = document.createElement('script');
        script.type = 'application/ld+json';
        script.textContent = JSON.stringify(structuredData);
        document.head.appendChild(script);
    }
    
    // Initialize structured data
    addAstrologyStructuredData();
    
    // Professional testimonial rotation (if testimonials section exists)
    const testimonials = document.querySelectorAll('.testimonial');
    if (testimonials.length > 1) {
        let currentTestimonial = 0;
        setInterval(() => {
            testimonials[currentTestimonial].style.opacity = '0';
            currentTestimonial = (currentTestimonial + 1) % testimonials.length;
            setTimeout(() => {
                testimonials.forEach(t => t.style.display = 'none');
                testimonials[currentTestimonial].style.display = 'block';
                testimonials[currentTestimonial].style.opacity = '1';
            }, 300);
        }, 8000); // Rotate every 8 seconds
    }
    
    // Enhanced accessibility for screen readers
    const buttons = document.querySelectorAll('.cosmic-button');
    buttons.forEach(button => {
        if (!button.getAttribute('aria-label')) {
            const text = button.textContent.trim();
            button.setAttribute('aria-label', `${text} - Professional astrology reading booking`);
        }
    });
    
    // Professional loading state for any future dynamic content
    function showLoadingState(element) {
        element.innerHTML = '<div style="text-align: center; padding: 20px;"><span style="color: var(--gold-star);">✨ Calculating cosmic insights...</span></div>';
    }
    
    // Price display enhancement
    const priceElements = document.querySelectorAll('.price');
    priceElements.forEach(price => {
        price.addEventListener('mouseenter', function() {
            this.style.textShadow = '0 0 20px rgba(245, 158, 11, 0.6)';
        });
        price.addEventListener('mouseleave', function() {
            this.style.textShadow = '0 0 20px rgba(245, 158, 11, 0.5)';
        });
    });
    
    console.log('🌟 TarotSwift professional astrology experience initialized - Your cosmic journey awaits! ✨');
});