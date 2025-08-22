import Foundation

/// Main birth data record linking user to their complete birth information.
///
/// This is the primary data structure that combines all birth-related information
/// needed for astrocartography calculations. It links a user to their precise
/// birth location and time, forming the foundation for generating accurate
/// astrological charts and power place recommendations.
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
/// let dateTime = BirthDateTime(
///     date: Date(),
///     hour: 14,
///     minute: 30,
///     second: 45,
///     timezone: "America/Los_Angeles",
///     isDaylightSaving: true,
///     utcOffset: -7
/// )
///
/// let birthData = BirthData(
///     userId: "user123",
///     location: location,
///     dateTime: dateTime,
///     notes: "Born during a solar eclipse"
/// )
///
/// print(birthData.summary) // Formatted summary of birth data
/// ```
///
/// ## Validation
///
/// The `isValid` property ensures that all components are properly formed:
/// - User ID is not empty
/// - Location coordinates are within valid bounds
/// - Time components are within valid ranges
/// - Timezone information is consistent
public struct BirthData: Codable, Sendable, Identifiable {
    public let id: UUID
    public let userId: String
    public let location: BirthLocation
    public let dateTime: BirthDateTime
    public let notes: String?

    public init(
        id: UUID = UUID(),
        userId: String,
        location: BirthLocation,
        dateTime: BirthDateTime,
        notes: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.location = location
        self.dateTime = dateTime
        self.notes = notes
    }

    /// Validates that all components of the birth data are valid
    public var isValid: Bool {
        location.isValid && dateTime.isValid && !userId.isEmpty
    }

    /// Returns a summary description of the birth data
    public var summary: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let dateString = dateFormatter.string(from: dateTime.date)

        return "\(dateString) at \(dateTime.timeString) in \(location.displayString)"
    }
}
