import Elementary
import TouchMenu
import VaporElementary

struct HomePage: HTMLDocument {
    var title: String { "Destined - Astrocartography Vacation Planning | Find Your Power Places" }

    var head: some HTML {
        HeaderComponent(primaryColor: "#1e3a8a", secondaryColor: "#10b981").content
        Elementary.title { title }
        meta(
            .name(.description),
            .content(
                "Discover where in the world you are most vibrational through astrocartography. Plan transformative vacations aligned with your birth chart."
            )
        )
        // Leaflet CSS
        link(
            .rel(.stylesheet),
            .href("https://unpkg.com/leaflet@1.9.4/dist/leaflet.css")
        )

        style {
            """
            .hero.is-mystical {
                background: linear-gradient(135deg, #1e3a8a 0%, #1e40af 50%, #3b82f6 100%);
            }
            .has-text-mystical {
                color: #10b981;
            }
            .button.is-mystical {
                background-color: #10b981;
                color: white;
                border-color: transparent;
            }
            .button.is-mystical:hover {
                background-color: #059669;
            }
            #world-map {
                width: 100%;
                height: 500px;
                border-radius: 8px;
                margin: 2rem 0;
                box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
                z-index: 1;
            }
            .leaflet-container {
                background: #dbeafe;
            }
            .power-marker {
                background: radial-gradient(circle, rgba(16, 185, 129, 0.8), rgba(16, 185, 129, 0.2));
                border: 2px solid #10b981;
                border-radius: 50%;
                width: 20px;
                height: 20px;
                animation: pulse 2s infinite;
            }
            @keyframes pulse {
                0% {
                    box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7);
                }
                70% {
                    box-shadow: 0 0 0 10px rgba(16, 185, 129, 0);
                }
                100% {
                    box-shadow: 0 0 0 0 rgba(16, 185, 129, 0);
                }
            }
            .pricing-card {
                transition: transform 0.3s ease;
            }
            .pricing-card:hover {
                transform: translateY(-5px);
            }
            """
        }

        // Leaflet JavaScript
        script(.src("https://unpkg.com/leaflet@1.9.4/dist/leaflet.js")) {}

        // Initialize OpenStreetMap with Leaflet
        script {
            """
            window.addEventListener('load', function() {
                // Initialize the map
                var map = L.map('world-map', {
                    center: [20, 0],
                    zoom: 2,
                    minZoom: 2,
                    maxZoom: 10,
                    worldCopyJump: true
                });

                // Add OpenStreetMap tiles
                L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                    attribution: 'OpenStreetMap contributors',
                    noWrap: false
                }).addTo(map);

                // Power places with mystical energy
                var powerPlaces = [
                    { lat: 27.9881, lng: 86.9250, name: 'Mount Everest', energy: 'Spiritual Elevation' },
                    { lat: -13.1631, lng: -72.5450, name: 'Machu Picchu', energy: 'Ancient Wisdom' },
                    { lat: 20.6597, lng: -87.0798, name: 'Tulum', energy: 'Transformation' },
                    { lat: 27.1751, lng: 78.0421, name: 'Taj Mahal', energy: 'Love and Beauty' },
                    { lat: -25.3444, lng: 131.0369, name: 'Uluru', energy: 'Grounding Force' },
                    { lat: 51.1789, lng: -1.8262, name: 'Stonehenge', energy: 'Cosmic Connection' },
                    { lat: 30.3285, lng: 35.4444, name: 'Petra', energy: 'Hidden Power' },
                    { lat: 64.0000, lng: -21.0000, name: 'Iceland', energy: 'Pure Creation' },
                    { lat: -8.3405, lng: 115.0920, name: 'Bali', energy: 'Sacred Balance' },
                    { lat: 36.2048, lng: 138.2529, name: 'Mount Fuji', energy: 'Inner Peace' }
                ];

                // Custom icon for power places
                var powerIcon = L.divIcon({
                    className: 'power-marker',
                    iconSize: [20, 20],
                    iconAnchor: [10, 10],
                    popupAnchor: [0, -10]
                });

                // Add markers for power places
                powerPlaces.forEach(function(place) {
                    var popupContent = '<div style="text-align: center; padding: 10px;">' +
                        '<strong style="color: #1e3a8a; font-size: 16px;">' + place.name + '</strong><br>' +
                        '<em style="color: #10b981;">' + place.energy + '</em><br>' +
                        '<small>High vibrational location</small>' +
                        '</div>';

                    var marker = L.marker([place.lat, place.lng], { icon: powerIcon })
                        .addTo(map)
                        .bindPopup(popupContent);

                    // Add hover effect
                    marker.on('mouseover', function() {
                        this.openPopup();
                    });
                });

                // Add a custom control showing this is a demo
                var info = L.control({ position: 'topright' });
                info.onAdd = function() {
                    var div = L.DomUtil.create('div', 'info');
                    div.style.background = 'rgba(255, 255, 255, 0.9)';
                    div.style.padding = '10px';
                    div.style.borderRadius = '5px';
                    div.style.boxShadow = '0 0 10px rgba(0,0,0,0.2)';

                    var title = document.createElement('strong');
                    title.style.color = '#1e3a8a';
                    title.textContent = 'Power Places Demo';

                    var subtitle = document.createElement('small');
                    var line1 = document.createTextNode('Your personalized map will show');
                    var line2 = document.createTextNode('locations aligned with YOUR birth chart');
                    subtitle.appendChild(line1);
                    subtitle.appendChild(document.createElement('br'));
                    subtitle.appendChild(line2);

                    div.appendChild(title);
                    div.appendChild(document.createElement('br'));
                    div.appendChild(subtitle);

                    return div;
                };
                info.addTo(map);

                // Add click event to show coordinate info
                map.on('click', function(e) {
                    var lat = e.latlng.lat.toFixed(4);
                    var lng = e.latlng.lng.toFixed(4);
                    var popupContent = '<div style="text-align: center;">' +
                        '<strong>Explore this location</strong><br>' +
                        'Coordinates: ' + lat + ', ' + lng + '<br>' +
                        '<small style="color: #10b981;">Click "Plan Your Vibrational Year"<br>to discover YOUR power places</small>' +
                        '</div>';
                    L.popup()
                        .setLatLng(e.latlng)
                        .setContent(popupContent)
                        .openOn(map);
                });
            });
            """
        }
    }

    var body: some HTML {
        DestinedNavigation().body
        heroSection
        worldMapSection
        serviceDescriptionSection
        howItWorksSection
        pricingSection
        additionalServicesSection
        ctaSection
        customFooter
    }

    private var heroSection: some HTML {
        section(.class("hero is-mystical is-large")) {
            div(.class("hero-body")) {
                div(.class("container has-text-centered")) {
                    h1(.class("title is-1 has-text-black")) {
                        "Where in the World Are You Most Vibrational?"
                    }
                    h2(.class("subtitle is-3 has-text-grey-light mt-4")) {
                        "Discover your power places through astrocartography and plan transformative vacations aligned with your birth chart around the world 🌍"
                    }
                    div(.class("buttons is-centered mt-6")) {
                        a(
                            .class("button is-mystical is-large"),
                            .href("mailto:team@destined.app?subject=Astrocartography%20Consultation")
                        ) {
                            span(.class("icon")) {
                                "⭐"
                            }
                            span { "Plan Your Vibrational Year - $1,111 🌍" }
                        }
                    }
                }
            }
        }
    }

    private var worldMapSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                div(.class("has-text-centered mb-6")) {
                    h2(.class("title is-2 has-text-mystical")) { "Your Global Power Map Awaits 🌍" }
                    p(.class("subtitle")) {
                        "Every location on Earth 🌍 holds unique energy for you. We'll help you find where you shine brightest."
                    }
                }
                div(.id("world-map")) {
                    // Leaflet map will be initialized here by JavaScript
                }
            }
        }
    }

    private var serviceDescriptionSection: some HTML {
        section(.class("section has-background-light")) {
            div(.class("container")) {
                div(.class("columns is-vcentered")) {
                    div(.class("column is-half")) {
                        h2(.class("title is-2 has-text-mystical")) { "What is Astrocartography?" }
                        div(.class("content is-large")) {
                            p {
                                "Destined is a Nevada company that helps people plan their vacations using astrocartography and current planetary transits. We analyze your birth chart to discover where in the world 🌍 you're most vibrational and help you plan wonderful trips."
                            }
                            p {
                                "Our service combines ancient astrological wisdom with modern travel planning to create transformative vacation experiences aligned with your highest chakras and vibrations."
                            }
                        }
                    }
                    div(.class("column is-half")) {
                        div(.class("box")) {
                            h3(.class("title is-4")) { "What We Need From You 🌍" }
                            ul(.class("is-size-5")) {
                                li { "📅 Your exact birth date" }
                                li { "⏰ Your birth time (as precise as possible)" }
                                li { "📍 Your birth location (city and country)" }
                                li { "📝 Complete our style questionnaire" }
                                li { "✨ Your openness to transformation" }
                            }
                        }
                    }
                }
            }
        }
    }

    private var howItWorksSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-centered has-text-mystical mb-6")) { "How It Works" }
                div(.class("columns is-multiline")) {
                    div(.class("column is-half")) {
                        div(.class("box has-text-centered")) {
                            span(.class("icon is-large has-text-mystical")) {
                                "👤"
                            }
                            h3(.class("title is-4 mt-4")) { "Step 1: Share Your Birth Details" }
                            p { "Provide your birth date, time, and location for accurate chart analysis" }
                        }
                    }
                    div(.class("column is-half")) {
                        div(.class("box has-text-centered")) {
                            span(.class("icon is-large has-text-mystical")) {
                                "📞"
                            }
                            h3(.class("title is-4 mt-4")) { "Step 2: Two Consultations 🌍" }
                            p { "Initial intake consultation and follow-up session to review your personalized plan" }
                        }
                    }
                    div(.class("column is-half")) {
                        div(.class("box has-text-centered")) {
                            span(.class("icon is-large has-text-mystical")) {
                                "🗺️"
                            }
                            h3(.class("title is-4 mt-4")) { "Step 3: Receive Your Plan" }
                            p { "Get a personalized year-long vacation plan to your power places" }
                        }
                    }
                    div(.class("column is-half")) {
                        div(.class("box has-text-centered")) {
                            span(.class("icon is-large has-text-mystical")) {
                                "✈️"
                            }
                            h3(.class("title is-4 mt-4")) { "Step 4: Transform Through Travel" }
                            p { "Visit your high-vibrational locations with confidence" }
                        }
                    }
                }
            }
        }
    }

    private var pricingSection: some HTML {
        section(.class("section has-background-light")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-centered has-text-mystical mb-6")) { "Investment in Your Journey" }
                div(.class("columns is-centered")) {
                    div(.class("column is-4")) {
                        div(.class("card pricing-card")) {
                            div(.class("card-content has-text-centered")) {
                                h3(.class("title is-3 has-text-mystical")) { "$1,111" }
                                p(.class("subtitle")) { "per year" }
                                hr()
                                div(.class("content")) {
                                    h4(.class("title is-5")) { "Your Vibrational Year Includes:" }
                                    ul(.class("has-text-left")) {
                                        li { "Complete birth chart analysis" }
                                        li { "Astrocartography mapping" }
                                        li { "12 months of vacation recommendations" }
                                        li { "Best price guarantee or money back" }
                                        li { "Up to 4 people per vacation plan" }
                                        li { "Two consultations: initial intake + follow-up 🌍" }
                                        li { "Personalized style questionnaire 🌍" }
                                        li { "Birth details analysis for accuracy 🌍" }
                                        li { "Alignment with highest chakras" }
                                    }
                                    p(.class("has-text-centered mt-5")) {
                                        a(
                                            .class("button is-mystical is-fullwidth"),
                                            .href("mailto:team@destined.app?subject=Astrocartography%20Consultation")
                                        ) {
                                            "Begin Your Journey"
                                        }
                                    }
                                    p(.class("is-size-7 mt-3")) {
                                        "Additional family members: $333/year each"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var additionalServicesSection: some HTML {
        section(.class("section")) {
            div(.class("container")) {
                h2(.class("title is-2 has-text-centered has-text-mystical mb-6")) { "Explore Our Wisdom 🌍" }
                div(.class("columns is-multiline")) {
                    div(.class("column is-3 has-text-centered")) {
                        a(.href("/astrology"), .class("has-text-dark")) {
                            div(.class("box")) {
                                span(.class("icon is-large has-text-mystical")) {
                                    "☀️"
                                }
                                h4(.class("title is-5 mt-3")) { "Astrology" }
                                p { "Celestial insights" }
                            }
                        }
                    }
                    div(.class("column is-3 has-text-centered")) {
                        a(.href("/numerology"), .class("has-text-dark")) {
                            div(.class("box")) {
                                span(.class("icon is-large has-text-mystical")) {
                                    "∞"
                                }
                                h4(.class("title is-5 mt-3")) { "Numerology" }
                                p { "Sacred mathematics" }
                            }
                        }
                    }
                    div(.class("column is-3 has-text-centered")) {
                        a(.href("/tarot"), .class("has-text-dark")) {
                            div(.class("box")) {
                                span(.class("icon is-large has-text-mystical")) {
                                    "🌙"
                                }
                                h4(.class("title is-5 mt-3")) { "Tarot" }
                                p { "Archetypal guidance" }
                            }
                        }
                    }
                    div(.class("column is-3 has-text-centered")) {
                        a(.href("/traditions"), .class("has-text-dark")) {
                            div(.class("box")) {
                                span(.class("icon is-large has-text-mystical")) {
                                    "🌍"
                                }
                                h4(.class("title is-5 mt-3")) { "Traditions" }
                                p { "Cultural wisdom" }
                            }
                        }
                    }
                }
            }
        }
    }

    private var ctaSection: some HTML {
        section(.class("section has-background-light")) {
            div(.class("container has-text-centered")) {
                h2(.class("title is-2 has-text-mystical")) { "Ready to Find Your Power Places? 🌍" }
                p(.class("subtitle is-4 mb-5")) {
                    "Begin your astrocartography journey today around the world 🌍"
                }
                a(
                    .class("button is-mystical is-large"),
                    .href("mailto:team@hoshihoshi.app?subject=Astrocartography%20Consultation")
                ) {
                    span(.class("icon")) {
                        "✉"
                    }
                    span { "Email Us to Get Started" }
                }
            }
        }
    }

    private var customFooter: some HTML {
        footer(.class("footer has-background-dark")) {
            div(.class("container has-text-centered")) {
                p(.class("has-text-grey-light")) {
                    "Destined is a Sagebrush Services powered company"
                }
            }
        }
    }
}
