import Foundation

/// Represents a point in time using Julian Date, the standard for astronomical calculations.
///
/// Julian Date (JD) is a continuous count of days since the beginning of the Julian Period
/// (January 1, 4713 BC in the proleptic Julian calendar). This system avoids complications
/// from calendar reforms and varying month lengths.
///
/// ## Overview
///
/// `Epoch` provides conversions between:
/// - Julian Date (JD)
/// - Modified Julian Date (MJD = JD - 2400000.5)
/// - Calendar dates (Gregorian)
/// - Foundation `Date`
/// - Julian centuries from J2000.0 (used in orbital element calculations)
///
/// ## Example
///
/// ```swift
/// // Create from Julian Date
/// let epoch = Epoch(julianDate: 2451545.0)  // J2000.0
///
/// // Create from calendar date
/// let launch = Epoch(year: 2025, month: 3, day: 15, hour: 14, minute: 30, second: 0)
///
/// // Get Julian centuries from J2000 for orbital calculations
/// let T = launch.julianCenturiesFromJ2000
/// ```
///
/// ## Thread Safety
///
/// `Epoch` is a value type and conforms to `Sendable`, making it safe to use across
/// actor boundaries and in concurrent code.
///
/// ## References
///
/// - [JPL Julian Date Converter](https://ssd.jpl.nasa.gov/tools/jdc/)
/// - Explanatory Supplement to the Astronomical Almanac, 3rd ed.
public struct Epoch: Sendable, Hashable, Codable {
    
    // MARK: - Properties
    
    /// The Julian Date value.
    ///
    /// Julian Date is defined as the number of days (including fractional days)
    /// since noon Universal Time on January 1, 4713 BC (Julian calendar).
    public let julianDate: Double
    
    // MARK: - Standard Epochs
    
    /// The J2000.0 standard epoch: 2000-Jan-01 12:00:00 TT (JD 2451545.0)
    ///
    /// This is the fundamental reference epoch for modern astronomical calculations.
    /// Orbital elements and coordinate systems are typically referenced to J2000.0.
    public static let j2000 = Epoch(julianDate: 2451545.0)
    
    /// The Unix epoch: 1970-Jan-01 00:00:00 UTC (JD 2440587.5)
    public static let unixEpoch = Epoch(julianDate: 2440587.5)
    
    // MARK: - Initialization
    
    /// Creates an epoch from a Julian Date value.
    ///
    /// - Parameter julianDate: The Julian Date (days since JD 0).
    public init(julianDate: Double) {
        self.julianDate = julianDate
    }
    
    /// Creates an epoch from a Modified Julian Date value.
    ///
    /// Modified Julian Date (MJD) is defined as JD - 2400000.5, which shifts the
    /// epoch to midnight on November 17, 1858 and reduces the magnitude of the number.
    ///
    /// - Parameter modifiedJulianDate: The Modified Julian Date.
    public init(modifiedJulianDate: Double) {
        self.julianDate = modifiedJulianDate + 2400000.5
    }
    
    /// Creates an epoch from calendar date components.
    ///
    /// Uses the Gregorian calendar for dates after October 15, 1582, and the
    /// Julian calendar for earlier dates.
    ///
    /// - Parameters:
    ///   - year: The year (use negative years or 0 for BC dates in astronomical convention).
    ///   - month: The month (1-12).
    ///   - day: The day of month (1-31).
    ///   - hour: The hour (0-23). Default is 0.
    ///   - minute: The minute (0-59). Default is 0.
    ///   - second: The second (0-59, can include fractional seconds). Default is 0.
    public init(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0, second: Double = 0) {
        // Algorithm from Explanatory Supplement to the Astronomical Almanac
        // Valid for both Julian and Gregorian calendars
        
        var y = year
        var m = month
        
        // Adjust for January and February being "13th" and "14th" months of previous year
        if m <= 2 {
            y -= 1
            m += 12
        }
        
        // Calculate the Julian Date
        let a = y / 100
        let b: Int
        
        // Use Gregorian calendar for dates on or after October 15, 1582
        if year > 1582 || (year == 1582 && (month > 10 || (month == 10 && day >= 15))) {
            b = 2 - a + (a / 4)
        } else {
            b = 0
        }
        
        let jd = Double(Int(365.25 * Double(y + 4716))) +
                 Double(Int(30.6001 * Double(m + 1))) +
                 Double(day) +
                 Double(b) -
                 1524.5
        
        // Add time of day
        let dayFraction = (Double(hour) + Double(minute) / 60.0 + second / 3600.0) / 24.0
        
        self.julianDate = jd + dayFraction
    }
    
    /// Creates an epoch from a Foundation `Date`.
    ///
    /// - Parameter date: A Foundation Date object.
    public init(date: Date) {
        // Foundation Date uses seconds since 2001-Jan-01 00:00:00 UTC
        // JD of 2001-Jan-01 00:00:00 = 2451910.5
        let referenceJD = 2451910.5
        let secondsPerDay = 86400.0
        
        let secondsSinceReference = date.timeIntervalSinceReferenceDate
        self.julianDate = referenceJD + (secondsSinceReference / secondsPerDay)
    }
    
    // MARK: - Computed Properties
    
    /// The Modified Julian Date (MJD = JD - 2400000.5).
    ///
    /// MJD is commonly used because it has a smaller magnitude and starts at midnight
    /// rather than noon.
    public var modifiedJulianDate: Double {
        julianDate - 2400000.5
    }
    
    /// The number of Julian centuries since J2000.0.
    ///
    /// This value is used extensively in orbital element calculations where elements
    /// are given with rates of change per Julian century.
    ///
    /// A Julian century is exactly 36525 days.
    ///
    /// - Note: Positive values are after J2000, negative values are before.
    public var julianCenturiesFromJ2000: Double {
        (julianDate - Self.j2000.julianDate) / 36525.0
    }
    
    /// The date components (year, month, day, hour, minute) for this epoch.
    ///
    /// Returns components in the Gregorian calendar (or Julian calendar for dates
    /// before October 15, 1582).
    public var dateComponents: (year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Double) {
        // Algorithm from Explanatory Supplement to the Astronomical Almanac
        let jd = julianDate + 0.5
        let z = Int(jd)
        let f = jd - Double(z)
        
        let a: Int
        if z < 2299161 {
            a = z
        } else {
            let alpha = Int((Double(z) - 1867216.25) / 36524.25)
            a = z + 1 + alpha - (alpha / 4)
        }
        
        let b = a + 1524
        let c = Int((Double(b) - 122.1) / 365.25)
        let d = Int(365.25 * Double(c))
        let e = Int(Double(b - d) / 30.6001)
        
        let day = b - d - Int(30.6001 * Double(e))
        let month = e < 14 ? e - 1 : e - 13
        let year = month > 2 ? c - 4716 : c - 4715
        
        // Extract time components from fractional day
        let totalHours = f * 24.0
        let hour = Int(totalHours)
        let totalMinutes = (totalHours - Double(hour)) * 60.0
        let minute = Int(totalMinutes)
        let second = (totalMinutes - Double(minute)) * 60.0
        
        return (year, month, day, hour, minute, second)
    }
    
    /// A Foundation `Date` representation of this epoch.
    ///
    /// Useful for interoperability with Foundation APIs and UI formatting.
    public var date: Date {
        // Foundation Date uses seconds since 2001-Jan-01 00:00:00 UTC
        // JD of 2001-Jan-01 00:00:00 = 2451910.5
        let referenceJD = 2451910.5
        let secondsPerDay = 86400.0
        
        let secondsSinceReference = (julianDate - referenceJD) * secondsPerDay
        return Date(timeIntervalSinceReferenceDate: secondsSinceReference)
    }
    
    // MARK: - Arithmetic
    
    /// Returns a new epoch by adding the specified number of days.
    ///
    /// - Parameter days: The number of days to add (can be negative).
    /// - Returns: A new epoch offset by the given number of days.
    public func adding(days: Double) -> Epoch {
        Epoch(julianDate: julianDate + days)
    }
    
    /// Returns the number of days between this epoch and another.
    ///
    /// - Parameter other: The reference epoch.
    /// - Returns: The number of days since the reference epoch (positive if this is later).
    public func days(since other: Epoch) -> Double {
        julianDate - other.julianDate
    }
    
    /// Returns the number of seconds between this epoch and another.
    ///
    /// - Parameter other: The reference epoch.
    /// - Returns: The number of seconds since the reference epoch.
    public func seconds(since other: Epoch) -> Double {
        days(since: other) * 86400.0
    }
}

// MARK: - Comparable

extension Epoch: Comparable {
    public static func < (lhs: Epoch, rhs: Epoch) -> Bool {
        lhs.julianDate < rhs.julianDate
    }
}

// MARK: - CustomStringConvertible

extension Epoch: CustomStringConvertible {
    public var description: String {
        let (year, month, day, hour, minute, second) = dateComponents
        return String(format: "%04d-%02d-%02d %02d:%02d:%05.2f (JD %.5f)",
                      year, month, day, hour, minute, second, julianDate)
    }
}
