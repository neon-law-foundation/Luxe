// HoshiHoshi - Cosmic Astrology Interactive Experience
document.addEventListener('DOMContentLoaded', function() {
    
    // Celestial interaction tracking
    function trackCosmicInteraction(action, element) {
        console.log(`Cosmic interaction: ${action} on ${element}`);
        // Could integrate with analytics for spiritual insights
        if (typeof gtag !== 'undefined') {
            gtag('event', 'cosmic_interaction', {
                'event_category': 'astrology',
                'event_label': `${action}_${element}`,
                'value': 1
            });
        }
    }
    
    // Enhanced Zodiac Sign Interactions
    const zodiacSigns = document.querySelectorAll('.zodiac-sign');
    const zodiacInfo = {
        aries: {
            dates: "March 21 - April 19",
            element: "Fire",
            ruler: "Mars",
            qualities: "Cardinal",
            essence: "The Pioneer - Courage to begin new adventures and lead with divine spark"
        },
        taurus: {
            dates: "April 20 - May 20", 
            element: "Earth",
            ruler: "Venus",
            qualities: "Fixed",
            essence: "The Builder - Grounding cosmic energy into material manifestation"
        },
        gemini: {
            dates: "May 21 - June 20",
            element: "Air", 
            ruler: "Mercury",
            qualities: "Mutable",
            essence: "The Communicator - Bridging realms through divine curiosity and connection"
        },
        cancer: {
            dates: "June 21 - July 22",
            element: "Water",
            ruler: "Moon", 
            qualities: "Cardinal",
            essence: "The Nurturer - Channeling lunar wisdom into emotional and spiritual care"
        },
        leo: {
            dates: "July 23 - August 22",
            element: "Fire",
            ruler: "Sun",
            qualities: "Fixed", 
            essence: "The Creator - Radiating solar consciousness through authentic self-expression"
        },
        virgo: {
            dates: "August 23 - September 22",
            element: "Earth",
            ruler: "Mercury",
            qualities: "Mutable",
            essence: "The Healer - Perfecting earthly service through divine discernment"
        },
        libra: {
            dates: "September 23 - October 22",
            element: "Air",
            ruler: "Venus", 
            qualities: "Cardinal",
            essence: "The Harmonizer - Balancing cosmic forces through beauty and justice"
        },
        scorpio: {
            dates: "October 23 - November 21",
            element: "Water",
            ruler: "Pluto",
            qualities: "Fixed",
            essence: "The Transformer - Diving deep into soul mysteries for spiritual rebirth"
        },
        sagittarius: {
            dates: "November 22 - December 21",
            element: "Fire", 
            ruler: "Jupiter",
            qualities: "Mutable",
            essence: "The Seeker - Expanding consciousness through philosophical exploration"
        },
        capricorn: {
            dates: "December 22 - January 19",
            element: "Earth",
            ruler: "Saturn",
            qualities: "Cardinal", 
            essence: "The Master - Climbing spiritual mountains through disciplined wisdom"
        },
        aquarius: {
            dates: "January 20 - February 18",
            element: "Air",
            ruler: "Uranus",
            qualities: "Fixed",
            essence: "The Visionary - Channeling cosmic innovation for humanity's evolution"
        },
        pisces: {
            dates: "February 19 - March 20",
            element: "Water", 
            ruler: "Neptune",
            qualities: "Mutable",
            essence: "The Mystic - Dissolving boundaries to merge with universal consciousness"
        }
    };
    
    zodiacSigns.forEach(sign => {
        sign.addEventListener('click', function() {
            const signName = this.dataset.sign;
            const info = zodiacInfo[signName];
            
            if (info) {
                trackCosmicInteraction('zodiac_click', signName);
                showZodiacModal(signName, info);
            }
        });
        
        // Add hover effects
        sign.addEventListener('mouseenter', function() {
            this.style.transform = 'scale(1.1) rotate(5deg)';
            this.style.boxShadow = '0 20px 40px rgba(168, 85, 247, 0.4)';
        });
        
        sign.addEventListener('mouseleave', function() {
            this.style.transform = 'scale(1) rotate(0deg)';
            this.style.boxShadow = 'none';
        });
    });
    
    function showZodiacModal(signName, info) {
        // Create modal overlay
        const modal = document.createElement('div');
        modal.style.cssText = `
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(10, 10, 26, 0.95);
            display: flex;
            align-items: center;
            justify-content: center;
            z-index: 10000;
            backdrop-filter: blur(10px);
        `;
        
        modal.innerHTML = `
            <div style="
                background: linear-gradient(135deg, #2d1b69 0%, #1e3a8a 100%);
                padding: 40px;
                border-radius: 20px;
                max-width: 500px;
                text-align: center;
                border: 2px solid #a855f7;
                box-shadow: 0 20px 60px rgba(168, 85, 247, 0.3);
                color: #f8fafc;
                position: relative;
            ">
                <div style="font-size: 4rem; margin-bottom: 20px;">
                    ${zodiacSigns.forEach(z => z.dataset.sign === signName ? z.querySelector('.sign-symbol').textContent : '')}
                </div>
                <h2 style="color: #fbbf24; font-size: 2.5rem; margin-bottom: 15px; text-transform: capitalize;">
                    ${signName}
                </h2>
                <p style="color: #a855f7; font-size: 1.2rem; margin-bottom: 20px; font-weight: bold;">
                    ${info.dates}
                </p>
                <div style="margin-bottom: 25px;">
                    <p><strong style="color: #fbbf24;">Element:</strong> ${info.element}</p>
                    <p><strong style="color: #fbbf24;">Ruling Planet:</strong> ${info.ruler}</p>
                    <p><strong style="color: #fbbf24;">Quality:</strong> ${info.qualities}</p>
                </div>
                <div style="
                    background: rgba(248, 250, 252, 0.1);
                    padding: 20px;
                    border-radius: 15px;
                    margin-bottom: 25px;
                    border: 1px solid rgba(168, 85, 247, 0.3);
                ">
                    <h3 style="color: #ec4899; margin-bottom: 10px;">Soul Essence</h3>
                    <p style="font-style: italic; line-height: 1.6;">${info.essence}</p>
                </div>
                <button onclick="this.closest('.modal-overlay').remove()" style="
                    background: linear-gradient(45deg, #a855f7, #ec4899);
                    color: white;
                    border: none;
                    padding: 15px 30px;
                    border-radius: 25px;
                    font-weight: bold;
                    cursor: pointer;
                    font-size: 1.1rem;
                ">✨ Close ✨</button>
            </div>
        `;
        
        modal.classList.add('modal-overlay');
        document.body.appendChild(modal);
        
        // Close on outside click
        modal.addEventListener('click', function(e) {
            if (e.target === modal) {
                modal.remove();
            }
        });
        
        // Auto-remove after 15 seconds
        setTimeout(() => {
            if (modal.parentElement) {
                modal.remove();
            }
        }, 15000);
    }
    
    // Smooth cosmic scrolling
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
                trackCosmicInteraction('navigation', targetId.replace('#', ''));
            }
        });
    });
    
    // Email click tracking
    const emailLinks = document.querySelectorAll('a[href^="mailto:team@hoshihoshi.app"]');
    emailLinks.forEach(link => {
        link.addEventListener('click', function() {
            const source = this.closest('.cosmic-hero') ? 'hero' :
                          this.closest('.cosmic-services') ? 'services' :
                          this.closest('.contact-section') ? 'contact' :
                          this.closest('.final-cosmic-cta') ? 'final_cta' :
                          this.closest('footer') ? 'footer' :
                          this.closest('nav') ? 'navigation' :
                          'unknown';
            trackCosmicInteraction('email_click', source);
        });
    });
    
    // Cosmic button hover effects
    const cosmicButtons = document.querySelectorAll('.cosmic-button');
    cosmicButtons.forEach(button => {
        button.addEventListener('mouseenter', function() {
            this.style.animation = 'cosmicPulse 0.6s ease-in-out';
        });
        
        button.addEventListener('animationend', function() {
            this.style.animation = '';
        });
        
        button.addEventListener('click', function() {
            // Create cosmic sparkle effect
            createSparkleEffect(this);
        });
    });
    
    function createSparkleEffect(element) {
        const rect = element.getBoundingClientRect();
        const sparkleCount = 12;
        
        for (let i = 0; i < sparkleCount; i++) {
            const sparkle = document.createElement('div');
            sparkle.style.cssText = `
                position: fixed;
                width: 4px;
                height: 4px;
                background: #fbbf24;
                border-radius: 50%;
                pointer-events: none;
                z-index: 10000;
                left: ${rect.left + rect.width / 2}px;
                top: ${rect.top + rect.height / 2}px;
                animation: sparkleOut 0.8s ease-out forwards;
            `;
            
            const angle = (i / sparkleCount) * 2 * Math.PI;
            const distance = 50 + Math.random() * 30;
            
            sparkle.style.setProperty('--end-x', `${Math.cos(angle) * distance}px`);
            sparkle.style.setProperty('--end-y', `${Math.sin(angle) * distance}px`);
            
            document.body.appendChild(sparkle);
            
            setTimeout(() => sparkle.remove(), 800);
        }
    }
    
    // Add sparkle animation CSS
    const sparkleStyle = document.createElement('style');
    sparkleStyle.textContent = `
        @keyframes cosmicPulse {
            0%, 100% { transform: scale(1); }
            50% { transform: scale(1.05); box-shadow: 0 0 30px rgba(168, 85, 247, 0.6); }
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
    
    // Cosmic scroll effects
    window.addEventListener('scroll', function() {
        const scrolled = window.pageYOffset;
        const rate = scrolled * -0.5;
        
        // Parallax effect for stars
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
        section.style.transform = 'translateY(50px)';
        section.style.transition = 'opacity 0.8s ease, transform 0.8s ease';
    });
    
    // Show first section immediately
    if (sections.length > 0) {
        sections[0].style.opacity = '1';
        sections[0].style.transform = 'translateY(0)';
    }
    
    // Cosmic birthday calculator (basic zodiac sign)
    function calculateZodiacSign(month, day) {
        const zodiacDates = [
            { sign: 'capricorn', start: [12, 22], end: [1, 19] },
            { sign: 'aquarius', start: [1, 20], end: [2, 18] },
            { sign: 'pisces', start: [2, 19], end: [3, 20] },
            { sign: 'aries', start: [3, 21], end: [4, 19] },
            { sign: 'taurus', start: [4, 20], end: [5, 20] },
            { sign: 'gemini', start: [5, 21], end: [6, 20] },
            { sign: 'cancer', start: [6, 21], end: [7, 22] },
            { sign: 'leo', start: [7, 23], end: [8, 22] },
            { sign: 'virgo', start: [8, 23], end: [9, 22] },
            { sign: 'libra', start: [9, 23], end: [10, 22] },
            { sign: 'scorpio', start: [10, 23], end: [11, 21] },
            { sign: 'sagittarius', start: [11, 22], end: [12, 21] }
        ];
        
        for (let zodiac of zodiacDates) {
            const [startMonth, startDay] = zodiac.start;
            const [endMonth, endDay] = zodiac.end;
            
            if (zodiac.sign === 'capricorn') {
                // Special case for Capricorn spanning year boundary
                if ((month === 12 && day >= startDay) || (month === 1 && day <= endDay)) {
                    return zodiac.sign;
                }
            } else {
                if ((month === startMonth && day >= startDay) || 
                    (month === endMonth && day <= endDay) ||
                    (month > startMonth && month < endMonth)) {
                    return zodiac.sign;
                }
            }
        }
        return null;
    }
    
    // Page visibility for cosmic timing
    document.addEventListener('visibilitychange', function() {
        if (document.visibilityState === 'visible') {
            console.log('Soul returned to cosmic journey');
            // Could track time spent contemplating cosmic wisdom
        }
    });
    
    // Add structured data for astrology services
    function addCosmicStructuredData() {
        const structuredData = {
            "@context": "https://schema.org",
            "@type": "Service",
            "name": "HoshiHoshi Astrology Readings",
            "description": "Discover where the stars were when you were born through personalized birth chart readings and cosmic guidance",
            "provider": {
                "@type": "Organization",
                "name": "HoshiHoshi",
                "url": "https://www.hoshihoshi.app"
            },
            "serviceType": ["Astrology Reading", "Birth Chart Analysis", "Compatibility Reading", "North Node Guidance"],
            "areaServed": "Worldwide",
            "hasOfferCatalog": {
                "@type": "OfferCatalog",
                "name": "Cosmic Guidance Services",
                "itemListElement": [
                    {
                        "@type": "Offer",
                        "itemOffered": {
                            "@type": "Service",
                            "name": "Birth Chart Reading",
                            "description": "Personalized natal chart analysis revealing your cosmic blueprint"
                        }
                    },
                    {
                        "@type": "Offer", 
                        "itemOffered": {
                            "@type": "Service",
                            "name": "Compatibility Analysis",
                            "description": "Explore cosmic connections between souls through chart comparison"
                        }
                    },
                    {
                        "@type": "Offer",
                        "itemOffered": {
                            "@type": "Service", 
                            "name": "North Node Journey",
                            "description": "Discover your soul's evolutionary path and highest purpose"
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
    
    // Initialize cosmic structured data
    addCosmicStructuredData();
    
    console.log('🌟 HoshiHoshi cosmic experience initialized - The stars are aligned! ✨');
});