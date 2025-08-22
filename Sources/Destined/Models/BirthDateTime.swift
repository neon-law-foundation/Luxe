import Foundation

/// Represents precise birth date and time information with timezone handling.
///
/// Birth time precision is crucial for accurate astrological calculations. Even a few minutes
/// difference can significantly impact the calculated planetary positions and house cusps.
/// This structure stores both the local birth time and the necessary timezone information
/// to convert to UTC for astronomical calculations.
///
/// ## Usage
///
/// ```swift
/// let birthTime = BirthDateTime(
///     date: Date(),
///     hour: 14,
///     minute: 30,
///     second: 45,
///     timezone: "America/Los_Angeles",
///     isDaylightSaving: true,
///     utcOffset: -7
/// )
///
/// print(birthTime.timeString) // "14:30:45"
/// let utcTime = birthTime.utcDate // Converted to UTC
/// ```
///
/// ## Important Notes
///
/// - Time components must be valid (0-23 hours, 0-59 minutes/seconds)
/// - UTC offset should be between -12 and +14 hours
/// - Timezone string should be a valid IANA timezone identifier
/// - Daylight saving flag helps with historical accuracy
public struct BirthDateTime: Codable, Sendable {
    public let date: Date
    public let hour: Int
    public let minute: Int
    public let second: Int
    public let timezone: String
    public let isDaylightSaving: Bool
    public let utcOffset: Int

    public init(
        date: Date,
        hour: Int,
        minute: Int,
        second: Int,
        timezone: String,
        isDaylightSaving: Bool,
        utcOffset: Int
    ) {
        self.date = date
        self.hour = hour
        self.minute = minute
        self.second = second
        self.timezone = timezone
        self.isDaylightSaving = isDaylightSaving
        self.utcOffset = utcOffset
    }

    /// Validates that time components are within valid ranges
    public var isValidTime: Bool {
        hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59 && second >= 0 && second <= 59
    }

    /// Returns a formatted time string (HH:mm:ss)
    public var timeString: String {
        String(format: "%02d:%02d:%02d", hour, minute, second)
    }

    /// Calculates the UTC date by applying the timezone offset
    public var utcDate: Date {
        // Create a proper date components with the exact time and timezone
        var calendar = Calendar(identifier: .gregorian)

        // First extract components from the stored date to get the base date
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)

        // Create new components with our precise time
        var preciseComponents = DateComponents()
        preciseComponents.year = dateComponents.year
        preciseComponents.month = dateComponents.month
        preciseComponents.day = dateComponents.day
        preciseComponents.hour = hour
        preciseComponents.minute = minute
        preciseComponents.second = second

        // Create the local date with the specified timezone if available
        if let timeZone = TimeZone(identifier: timezone) {
            calendar.timeZone = timeZone
            let localDate = calendar.date(from: preciseComponents) ?? date

            // Convert to UTC
            var utcCalendar = Calendar(identifier: .gregorian)
            utcCalendar.timeZone = TimeZone(identifier: "UTC")!
            return localDate
        } else {
            // Fallback: use manual offset calculation
            let localTimeInterval = TimeInterval((hour * 3600) + (minute * 60) + second)
            let baseDate = calendar.startOfDay(for: date)
            let localDateTime = baseDate.addingTimeInterval(localTimeInterval)

            // Convert to UTC by subtracting the UTC offset
            // If offset is -7 (local is 7 hours behind UTC), add 7 hours to get UTC
            let utcTimeInterval = TimeInterval(-utcOffset * 3600)
            return localDateTime.addingTimeInterval(utcTimeInterval)
        }
    }

    /// Validates all time components and timezone information
    public var isValid: Bool {
        isValidTime && utcOffset >= -12 && utcOffset <= 14
    }
}
