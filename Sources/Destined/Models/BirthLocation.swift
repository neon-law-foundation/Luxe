import Foundation

/// Represents a geographic location for birth data with validation.
///
/// Birth location is a critical component for accurate astrocartography calculations.
/// The geographic coordinates must be precise to generate accurate astrological charts
/// and planetary lines for astrocartography mapping.
///
/// ## Usage
///
/// ```swift
/// let location = BirthLocation(
///     latitude: 36.1699,
///     longitude: -115.1398,
///     city: "Las Vegas",
///     state: "Nevada",
///     country: "United States",
///     timezone: "America/Los_Angeles"
/// )
///
/// if location.isValid {
///     print(location.displayString) // "Las Vegas, Nevada, United States"
/// }
/// ```
///
/// ## Important Notes
///
/// - Latitude must be between -90.0 and 90.0 degrees
/// - Longitude must be between -180.0 and 180.0 degrees
/// - Timezone should be a valid IANA timezone identifier
/// - State is optional and can be nil for countries that don't use states/provinces
public struct BirthLocation: Codable, Sendable {
    /// Latitude in decimal degrees (-90.0 to 90.0)
    public let latitude: Double

    /// Longitude in decimal degrees (-180.0 to 180.0)
    public let longitude: Double

    /// City name where the birth occurred
    public let city: String

    /// State or province name (optional, can be nil for countries without states)
    public let state: String?

    /// Country name where the birth occurred
    public let country: String

    /// IANA timezone identifier (e.g., "America/Los_Angeles", "Europe/London")
    public let timezone: String

    /// Creates a new birth location with the specified coordinates and location details.
    ///
    /// - Parameters:
    ///   - latitude: Latitude in decimal degrees (-90.0 to 90.0)
    ///   - longitude: Longitude in decimal degrees (-180.0 to 180.0)
    ///   - city: City name where the birth occurred
    ///   - state: State or province name (optional)
    ///   - country: Country name where the birth occurred
    ///   - timezone: IANA timezone identifier
    public init(
        latitude: Double,
        longitude: Double,
        city: String,
        state: String? = nil,
        country: String,
        timezone: String
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.city = city
        self.state = state
        self.country = country
        self.timezone = timezone
    }

    /// Validates that the latitude is within valid bounds (-90 to 90 degrees)
    public var isValidLatitude: Bool {
        latitude >= -90.0 && latitude <= 90.0
    }

    /// Validates that the longitude is within valid bounds (-180 to 180 degrees)
    public var isValidLongitude: Bool {
        longitude >= -180.0 && longitude <= 180.0
    }

    /// Returns a formatted display string for the location
    public var displayString: String {
        if let state = state {
            return "\(city), \(state), \(country)"
        } else {
            return "\(city), \(country)"
        }
    }

    /// Validates that both latitude and longitude are within valid bounds
    public var isValid: Bool {
        isValidLatitude && isValidLongitude
    }
}
