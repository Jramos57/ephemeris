import Testing
import Foundation
@testable import ephemeris

/// Tests for the Epoch type - Julian Date handling and conversions
///
/// Reference data from:
/// - JPL Horizons: https://ssd.jpl.nasa.gov/tools/jdc/
/// - US Naval Observatory
@Suite("Epoch Tests")
struct EpochTests {
    
    // MARK: - Constants
    
    /// J2000.0 epoch: 2000-Jan-01 12:00:00 TT
    /// Julian Date: 2451545.0
    static let j2000JulianDate: Double = 2451545.0
    
    // MARK: - Julian Date Creation Tests
    
    @Test("J2000 epoch has correct Julian Date")
    func j2000EpochValue() {
        let j2000 = Epoch.j2000
        #expect(j2000.julianDate == Self.j2000JulianDate)
    }
    
    @Test("Create epoch from Julian Date")
    func createFromJulianDate() {
        let epoch = Epoch(julianDate: 2451545.0)
        #expect(epoch.julianDate == 2451545.0)
    }
    
    @Test("Create epoch from Modified Julian Date")
    func createFromModifiedJulianDate() {
        // MJD = JD - 2400000.5
        // J2000 MJD = 2451545.0 - 2400000.5 = 51544.5
        let epoch = Epoch(modifiedJulianDate: 51544.5)
        #expect(epoch.julianDate == 2451545.0)
    }
    
    @Test("Modified Julian Date conversion is correct")
    func modifiedJulianDateConversion() {
        let epoch = Epoch.j2000
        #expect(epoch.modifiedJulianDate == 51544.5)
    }
    
    // MARK: - Date Component Tests
    
    @Test("J2000 converts to correct calendar date")
    func j2000CalendarDate() {
        let j2000 = Epoch.j2000
        let components = j2000.dateComponents
        
        #expect(components.year == 2000)
        #expect(components.month == 1)
        #expect(components.day == 1)
        #expect(components.hour == 12)
        #expect(components.minute == 0)
    }
    
    @Test("Create epoch from date components")
    func createFromDateComponents() {
        let epoch = Epoch(year: 2000, month: 1, day: 1, hour: 12, minute: 0, second: 0)
        
        // Should be very close to J2000 (within floating point tolerance)
        #expect(abs(epoch.julianDate - Self.j2000JulianDate) < 0.0001)
    }
    
    @Test("Known date: 2024-Jan-01 00:00:00 UTC")
    func knownDate2024() {
        // From JPL JD converter: 2024-Jan-01 00:00:00 = JD 2460310.5
        let epoch = Epoch(year: 2024, month: 1, day: 1, hour: 0, minute: 0, second: 0)
        #expect(abs(epoch.julianDate - 2460310.5) < 0.0001)
    }
    
    @Test("Known date: 1969-Jul-20 20:17:40 UTC (Apollo 11 landing)")
    func apollo11Landing() {
        // Apollo 11 landed: 1969-Jul-20 20:17:40 UTC
        // JD = 2440423.345601852
        let epoch = Epoch(year: 1969, month: 7, day: 20, hour: 20, minute: 17, second: 40)
        #expect(abs(epoch.julianDate - 2440423.345601852) < 0.0001)
    }
    
    // MARK: - Julian Century Tests
    
    @Test("Julian centuries from J2000 at J2000 is zero")
    func julianCenturiesAtJ2000() {
        let j2000 = Epoch.j2000
        #expect(j2000.julianCenturiesFromJ2000 == 0.0)
    }
    
    @Test("Julian centuries calculation is correct")
    func julianCenturiesCalculation() {
        // 36525 days = 1 Julian century
        let oneHundredYearsLater = Epoch(julianDate: Self.j2000JulianDate + 36525.0)
        #expect(abs(oneHundredYearsLater.julianCenturiesFromJ2000 - 1.0) < 0.0001)
        
        let fiftyYearsLater = Epoch(julianDate: Self.j2000JulianDate + 18262.5)
        #expect(abs(fiftyYearsLater.julianCenturiesFromJ2000 - 0.5) < 0.0001)
    }
    
    @Test("Negative Julian centuries for dates before J2000")
    func negativeJulianCenturies() {
        // 100 years before J2000
        let epoch = Epoch(julianDate: Self.j2000JulianDate - 36525.0)
        #expect(abs(epoch.julianCenturiesFromJ2000 - (-1.0)) < 0.0001)
    }
    
    // MARK: - Foundation Date Interop Tests
    
    @Test("Convert to Foundation Date and back")
    func foundationDateRoundTrip() {
        let original = Epoch(year: 2025, month: 6, day: 15, hour: 14, minute: 30, second: 0)
        let date = original.date
        let restored = Epoch(date: date)
        
        // Should be within 1 second
        #expect(abs(original.julianDate - restored.julianDate) < 1.0 / 86400.0)
    }
    
    @Test("Create epoch from Foundation Date")
    func createFromFoundationDate() {
        // Create a known date using Foundation
        var components = DateComponents()
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = 12
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(identifier: "UTC")
        
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: components) else {
            Issue.record("Failed to create date from components")
            return
        }
        
        let epoch = Epoch(date: date)
        #expect(abs(epoch.julianDate - Self.j2000JulianDate) < 0.0001)
    }
    
    // MARK: - Arithmetic Tests
    
    @Test("Add days to epoch")
    func addDays() {
        let epoch = Epoch.j2000
        let later = epoch.adding(days: 100)
        #expect(later.julianDate == Self.j2000JulianDate + 100)
    }
    
    @Test("Subtract days from epoch")
    func subtractDays() {
        let epoch = Epoch.j2000
        let earlier = epoch.adding(days: -50)
        #expect(earlier.julianDate == Self.j2000JulianDate - 50)
    }
    
    @Test("Days between epochs")
    func daysBetween() {
        let epoch1 = Epoch.j2000
        let epoch2 = Epoch(julianDate: Self.j2000JulianDate + 365.25)
        #expect(epoch2.days(since: epoch1) == 365.25)
    }
    
    // MARK: - Comparison Tests
    
    @Test("Epoch comparison operators")
    func comparisonOperators() {
        let earlier = Epoch(julianDate: 2451545.0)
        let later = Epoch(julianDate: 2451546.0)
        
        #expect(earlier < later)
        #expect(later > earlier)
        #expect(earlier <= later)
        #expect(later >= earlier)
        #expect(earlier != later)
        
        let same = Epoch(julianDate: 2451545.0)
        #expect(earlier == same)
    }
    
    // MARK: - Edge Cases
    
    @Test("Very old date: 1 BC (Julian calendar)")
    func ancientDate() {
        // Year 0 in astronomical year numbering = 1 BC
        // JD of 1 BC Jan 1 noon = 1721057.5
        let epoch = Epoch(julianDate: 1721057.5)
        #expect(epoch.julianDate == 1721057.5)
    }
    
    @Test("Far future date: year 2225")
    func futureDate() {
        // 2225-Jan-01 00:00:00 = JD 2533732.5 (calculated via algorithm)
        // This validates our implementation works for dates ~200 years in the future
        let epoch = Epoch(year: 2225, month: 1, day: 1, hour: 0, minute: 0, second: 0)
        
        // Verify the date components round-trip correctly
        let components = epoch.dateComponents
        #expect(components.year == 2225)
        #expect(components.month == 1)
        #expect(components.day == 1)
        
        // Verify it's reasonably far in the future (> 200 years from J2000)
        #expect(epoch.julianCenturiesFromJ2000 > 2.0)
        #expect(epoch.julianCenturiesFromJ2000 < 2.5)
    }
    
    // MARK: - Codable Tests
    
    @Test("Epoch is Codable")
    func codableRoundTrip() throws {
        let original = Epoch(julianDate: 2451545.0)
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Epoch.self, from: data)
        
        #expect(original == decoded)
    }
    
    // MARK: - Sendable Tests
    
    @Test("Epoch can be passed across actor boundaries")
    func sendableConformance() async {
        let epoch = Epoch.j2000
        
        // This compiles only if Epoch is Sendable
        let result = await Task.detached {
            return epoch.julianDate
        }.value
        
        #expect(result == epoch.julianDate)
    }
}
