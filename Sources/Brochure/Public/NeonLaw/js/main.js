/**
 * Neon Law Foundation - Interactive Features
 * Handles video gallery, navigation, and accessibility enhancements
 */

// Wait for DOM to be fully loaded
document.addEventListener('DOMContentLoaded', function() {
    initializeVideoGallery();
    initializeNavigation();
    initializeAccessibility();
    initializeAnimations();
});

/**
 * Video Gallery Functionality
 * Handles video placeholder interactions and modal display
 */
function initializeVideoGallery() {
    const videoItems = document.querySelectorAll('.video-placeholder');
    
    videoItems.forEach((item, index) => {
        item.addEventListener('click', function() {
            const videoNumber = this.dataset.video;
            handleVideoClick(videoNumber, index + 1);
        });
        
        // Add keyboard support
        item.addEventListener('keydown', function(e) {
            if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                const videoNumber = this.dataset.video;
                handleVideoClick(videoNumber, index + 1);
            }
        });
        
        // Make focusable for accessibility
        item.setAttribute('tabindex', '0');
        item.setAttribute('role', 'button');
        item.setAttribute('aria-label', `Play video ${index + 1}: ${getVideoTitle(index + 1)}`);
    });
}

/**
 * Handle video click events
 */
function handleVideoClick(videoNumber, displayNumber) {
    const videoTitle = getVideoTitle(displayNumber);
    
    // Create modal for video information
    showVideoModal(videoTitle, displayNumber);
    
    // Track video interaction (privacy-friendly)
    trackVideoInteraction(displayNumber);
}

/**
 * Get video title based on index
 */
function getVideoTitle(index) {
    const titles = [
        'Privacy Protection Fundamentals',
        'Digital Security Essentials', 
        'Right to be Forgotten',
        'Fair Justice Access',
        'Privacy Education'
    ];
    return titles[index - 1] || 'Educational Video';
}

/**
 * Show video information modal
 */
function showVideoModal(title, videoNumber) {
    const modal = document.createElement('div');
    modal.className = 'video-modal';
    modal.setAttribute('role', 'dialog');
    modal.setAttribute('aria-labelledby', 'modal-title');
    modal.setAttribute('aria-modal', 'true');
    
    modal.innerHTML = `
        <div class="modal-overlay" role="presentation"></div>
        <div class="modal-content">
            <div class="modal-header">
                <h2 id="modal-title">${title}</h2>
                <button class="modal-close" aria-label="Close video information">&times;</button>
            </div>
            <div class="modal-body">
                <div class="video-info">
                    <div class="video-poster">
                        <img src="images/video${videoNumber}-poster.jpg" alt="${title} preview" />
                        <div class="info-overlay">
                            <div class="info-icon">📹</div>
                        </div>
                    </div>
                    <div class="video-details">
                        <p><strong>Educational Content:</strong> ${title}</p>
                        <p>This video covers important privacy and civil rights topics as part of our educational mission.</p>
                        <p><strong>Contact for Access:</strong> For full video access and educational materials, please contact us at:</p>
                        <p class="contact-info">
                            <a href="mailto:support@neonlaw.org?subject=Video Access Request: ${title}">support@neonlaw.org</a>
                        </p>
                        <div class="action-buttons">
                            <a href="contact.html" class="cta-button secondary">Request Workshop</a>
                            <a href="our-mission.html" class="cta-button primary">Learn More</a>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    `;
    
    document.body.appendChild(modal);
    
    // Focus management
    const closeButton = modal.querySelector('.modal-close');
    closeButton.focus();
    
    // Close modal handlers
    closeButton.addEventListener('click', closeModal);
    modal.querySelector('.modal-overlay').addEventListener('click', closeModal);
    
    // Keyboard navigation
    modal.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            closeModal();
        }
        
        // Trap focus within modal
        trapFocus(modal, e);
    });
    
    // Add modal styles dynamically
    addModalStyles();
    
    function closeModal() {
        document.body.removeChild(modal);
        // Return focus to the video item that was clicked
        const originalVideoItem = document.querySelector(`[data-video="${videoNumber}"]`);
        if (originalVideoItem) {
            originalVideoItem.focus();
        }
    }
}

/**
 * Add modal styles dynamically
 */
function addModalStyles() {
    if (document.getElementById('modal-styles')) return;
    
    const styles = document.createElement('style');
    styles.id = 'modal-styles';
    styles.textContent = `
        .video-modal {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            z-index: 10000;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        
        .modal-overlay {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0, 0, 0, 0.8);
            backdrop-filter: blur(4px);
        }
        
        .modal-content {
            position: relative;
            background: var(--white);
            border-radius: 12px;
            max-width: 600px;
            width: 100%;
            max-height: 90vh;
            overflow-y: auto;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            animation: modalSlideIn 0.3s ease-out;
        }
        
        @keyframes modalSlideIn {
            from {
                opacity: 0;
                transform: translateY(-20px) scale(0.95);
            }
            to {
                opacity: 1;
                transform: translateY(0) scale(1);
            }
        }
        
        .modal-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 1.5rem;
            border-bottom: 1px solid rgba(0, 0, 0, 0.1);
        }
        
        .modal-header h2 {
            margin: 0;
            color: var(--deep-navy);
            font-size: 1.5rem;
        }
        
        .modal-close {
            background: none;
            border: none;
            font-size: 1.5rem;
            cursor: pointer;
            padding: 0.5rem;
            border-radius: 6px;
            color: var(--text-medium);
            transition: all 0.2s ease;
        }
        
        .modal-close:hover {
            background: var(--soft-gray);
            color: var(--text-dark);
        }
        
        .modal-body {
            padding: 2rem;
        }
        
        .video-info {
            display: flex;
            gap: 1.5rem;
            flex-wrap: wrap;
        }
        
        .video-poster {
            position: relative;
            flex: 0 0 200px;
            aspect-ratio: 16/9;
            border-radius: 8px;
            overflow: hidden;
        }
        
        .video-poster img {
            width: 100%;
            height: 100%;
            object-fit: cover;
        }
        
        .info-overlay {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(0, 102, 204, 0.8);
            display: flex;
            align-items: center;
            justify-content: center;
        }
        
        .info-icon {
            font-size: 2rem;
            color: white;
        }
        
        .video-details {
            flex: 1;
            min-width: 250px;
        }
        
        .video-details p {
            margin-bottom: 1rem;
            line-height: 1.6;
        }
        
        .contact-info a {
            color: var(--neon-blue);
            text-decoration: none;
            font-weight: 600;
        }
        
        .contact-info a:hover {
            text-decoration: underline;
        }
        
        .action-buttons {
            display: flex;
            gap: 1rem;
            margin-top: 1.5rem;
            flex-wrap: wrap;
        }
        
        .action-buttons .cta-button {
            padding: 0.75rem 1.5rem;
            font-size: 0.95rem;
        }
        
        @media (max-width: 600px) {
            .video-info {
                flex-direction: column;
            }
            
            .video-poster {
                flex: none;
                width: 100%;
            }
            
            .action-buttons {
                flex-direction: column;
            }
        }
    `;
    
    document.head.appendChild(styles);
}

/**
 * Trap focus within modal for accessibility
 */
function trapFocus(modal, e) {
    const focusableElements = modal.querySelectorAll(
        'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    );
    const firstElement = focusableElements[0];
    const lastElement = focusableElements[focusableElements.length - 1];
    
    if (e.key === 'Tab') {
        if (e.shiftKey) {
            if (document.activeElement === firstElement) {
                e.preventDefault();
                lastElement.focus();
            }
        } else {
            if (document.activeElement === lastElement) {
                e.preventDefault();
                firstElement.focus();
            }
        }
    }
}

/**
 * Navigation enhancements
 */
function initializeNavigation() {
    // Handle dropdown menus
    const dropdowns = document.querySelectorAll('.dropdown');
    
    dropdowns.forEach(dropdown => {
        const toggle = dropdown.querySelector('.dropdown-toggle');
        const menu = dropdown.querySelector('.dropdown-menu');
        
        if (toggle && menu) {
            // Keyboard navigation
            toggle.addEventListener('keydown', function(e) {
                if (e.key === 'ArrowDown') {
                    e.preventDefault();
                    const firstItem = menu.querySelector('a');
                    if (firstItem) firstItem.focus();
                }
            });
            
            // Menu item navigation
            const menuItems = menu.querySelectorAll('a');
            menuItems.forEach((item, index) => {
                item.addEventListener('keydown', function(e) {
                    if (e.key === 'ArrowDown') {
                        e.preventDefault();
                        const nextItem = menuItems[index + 1] || menuItems[0];
                        nextItem.focus();
                    } else if (e.key === 'ArrowUp') {
                        e.preventDefault();
                        const prevItem = menuItems[index - 1] || menuItems[menuItems.length - 1];
                        prevItem.focus();
                    } else if (e.key === 'Escape') {
                        toggle.focus();
                    }
                });
            });
        }
    });
    
    // Smooth scrolling for anchor links
    const anchorLinks = document.querySelectorAll('a[href^="#"]');
    anchorLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            const targetId = this.getAttribute('href').substring(1);
            const targetElement = document.getElementById(targetId);
            
            if (targetElement) {
                e.preventDefault();
                targetElement.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
                
                // Update focus for accessibility
                targetElement.setAttribute('tabindex', '-1');
                targetElement.focus();
            }
        });
    });
}

/**
 * Accessibility enhancements
 */
function initializeAccessibility() {
    // Skip to main content link
    const skipLink = document.createElement('a');
    skipLink.href = '#main-content';
    skipLink.textContent = 'Skip to main content';
    skipLink.className = 'skip-link';
    skipLink.style.cssText = `
        position: absolute;
        top: -40px;
        left: 6px;
        background: var(--neon-blue);
        color: white;
        padding: 8px;
        text-decoration: none;
        border-radius: 4px;
        z-index: 1000;
        transition: top 0.2s ease;
    `;
    
    skipLink.addEventListener('focus', function() {
        this.style.top = '6px';
    });
    
    skipLink.addEventListener('blur', function() {
        this.style.top = '-40px';
    });
    
    document.body.insertBefore(skipLink, document.body.firstChild);
    
    // Add main content ID if it doesn't exist
    const mainContent = document.querySelector('main') || document.querySelector('.hero-section');
    if (mainContent && !mainContent.id) {
        mainContent.id = 'main-content';
    }
    
    // Enhance focus visibility
    const focusStyle = document.createElement('style');
    focusStyle.textContent = `
        .video-placeholder:focus {
            outline: 3px solid var(--bright-cyan);
            outline-offset: 2px;
        }
        
        .skip-link:focus {
            top: 6px !important;
        }
    `;
    document.head.appendChild(focusStyle);
}

/**
 * Scroll-based animations
 */
function initializeAnimations() {
    // Intersection Observer for fade-in animations
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    };
    
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('animate-in');
            }
        });
    }, observerOptions);
    
    // Observe elements for animation
    const animateElements = document.querySelectorAll(
        '.focus-item, .news-item, .video-item, .who-content'
    );
    
    animateElements.forEach(el => {
        el.classList.add('animate-on-scroll');
        observer.observe(el);
    });
    
    // Add animation styles
    const animationStyles = document.createElement('style');
    animationStyles.textContent = `
        .animate-on-scroll {
            opacity: 0;
            transform: translateY(20px);
            transition: opacity 0.6s ease, transform 0.6s ease;
        }
        
        .animate-on-scroll.animate-in {
            opacity: 1;
            transform: translateY(0);
        }
        
        @media (prefers-reduced-motion: reduce) {
            .animate-on-scroll {
                opacity: 1;
                transform: none;
                transition: none;
            }
        }
    `;
    document.head.appendChild(animationStyles);
}

/**
 * Privacy-friendly analytics tracking
 */
function trackVideoInteraction(videoNumber) {
    // Only track basic interaction without personal data
    if (typeof gtag !== 'undefined') {
        gtag('event', 'video_interaction', {
            'video_number': videoNumber,
            'event_category': 'engagement'
        });
    }
    
    // Console log for development
    console.log(`Video ${videoNumber} interaction tracked`);
}

/**
 * Utility functions
 */

// Debounce function for performance
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Simple polyfill for older browsers
if (!Element.prototype.closest) {
    Element.prototype.closest = function(selector) {
        let element = this;
        while (element && element.nodeType === 1) {
            if (element.matches(selector)) {
                return element;
            }
            element = element.parentNode;
        }
        return null;
    };
}

// Error handling
window.addEventListener('error', function(e) {
    console.warn('Non-critical error:', e.message);
    // Continue gracefully without disrupting user experience
});

// Initialization complete
console.log('Neon Law Foundation website initialized successfully');