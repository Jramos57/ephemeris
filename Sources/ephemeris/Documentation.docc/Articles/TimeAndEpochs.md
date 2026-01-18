# Time and Epochs

Understand how ephemeris represents time using Julian Dates and the Epoch type.

@Metadata {
    @PageImage(purpose: card, source: "time-epochs-card", alt: "A timeline showing different time systems")
    @PageColor(blue)
}

## Overview

Asking "Where is Mars?" requires specifying *when*. But what calendar do you use? How do you handle time zones, leap seconds, and historical calendar reforms? Astronomers solved this centuries ago with **Julian Dates**—a continuous count of days that sidesteps all these complications.

The ephemeris package uses the ``Epoch`` struct to represent instants in time, providing easy conversion between Julian Dates, calendar dates, and Swift's `Date` type.

## The Problem with Calendar Dates

Calendar dates seem simple until you dig into the details:

- **Leap years**: 1900 wasn't a leap year (divisible by 100), but 2000 was (divisible by 400)
- **Calendar reforms**: The Gregorian calendar was adopted at different times in different countries (1582 in Catholic countries, 1752 in Britain)
- **Leap seconds**: UTC occasionally adds a second to stay synchronized with Earth's rotation
- **Time zones**: UTC, TAI, TT, TDB, UT1—astronomers use several time scales

For computations spanning centuries, we need something simpler.

## Julian Dates

A **Julian Date (JD)** is a continuous count of days since a reference point:

```
JD 0 = January 1, 4713 BC (Julian calendar), 12:00 noon
```

This date was chosen because it predates all recorded history, ensuring all historical dates have positive JD values.

Examples:
- **JD 2451545.0** = January 1, 2000, 12:00 TT (J2000.0)
- **JD 2440587.5** = January 1, 1970, 00:00 UTC (Unix epoch)
- **JD 2460676.5** = January 1, 2025, 00:00 UTC

The fractional part represents the time of day:
- `.0` = noon
- `.5` = midnight
- `.25` = 6:00 AM
- `.75` = 6:00 PM

### Modified Julian Date (MJD)

For modern dates, JD values are cumbersome (7+ digits). The **Modified Julian Date** shifts the origin:

```
MJD = JD - 2400000.5
```

This makes MJD 0 = November 17, 1858, and shifts midnight to `.0` instead of `.5`.

## The Epoch Type

``Epoch`` wraps a Julian Date with convenient initializers and properties:

### Creating Epochs

```swift
// From a Julian Date
let epoch = Epoch(julianDate: 2460676.5)

// From a Modified Julian Date
let epoch = Epoch(modifiedJulianDate: 60676.0)

// From a Foundation Date
let epoch = Epoch(date: Date())

// From calendar components (assumes UTC)
let epoch = Epoch(year: 2025, month: 7, day: 4, hour: 12, minute: 0, second: 0)
```

### Common Reference Epochs

```swift
// J2000.0 - The standard astronomical epoch
let j2000 = Epoch.j2000  // JD 2451545.0, January 1, 2000, 12:00 TT

// Unix epoch - January 1, 1970, 00:00 UTC
let unix = Epoch.unixEpoch  // JD 2440587.5
```

### Accessing Time Values

```swift
let epoch = Epoch(date: Date())

// Julian Date representation
let jd = epoch.julianDate           // e.g., 2460676.75
let mjd = epoch.modifiedJulianDate  // e.g., 60676.25

// Centuries from J2000 (useful for orbital element propagation)
let T = epoch.julianCenturiesFromJ2000  // e.g., 0.25 (quarter century)

// Calendar components (year, month, day, hour, minute, second)
let components = epoch.dateComponents
print("Year: \(components.0), Month: \(components.1)")

// Foundation Date (for UI display, etc.)
let date = epoch.date  // Date object
```

### Time Arithmetic

```swift
let now = Epoch(date: Date())

// Add days
let tomorrow = now.adding(days: 1)
let nextWeek = now.adding(days: 7)
let lastMonth = now.adding(days: -30)

// Time differences
let daysBetween = tomorrow.days(since: now)     // 1.0
let secondsBetween = tomorrow.seconds(since: now)  // 86400.0
```

## Time Scales

Astronomers use several time scales, each with subtle differences:

| Scale | Description | Use Case |
|-------|-------------|----------|
| **UTC** | Coordinated Universal Time, includes leap seconds | Everyday civil time |
| **UT1** | Based on Earth's actual rotation | Navigation, observations |
| **TAI** | International Atomic Time, no leap seconds | Precise timekeeping |
| **TT** | Terrestrial Time = TAI + 32.184s | Ephemeris calculations |
| **TDB** | Barycentric Dynamical Time | Planetary motion |

### Which Time Scale Does ephemeris Use?

The ``Epoch`` type uses **TT (Terrestrial Time)** for internal calculations, which is the standard for ephemeris work. When you create an Epoch from a Foundation `Date` (which uses UTC), the conversion assumes:

```
TT ≈ UTC + 32.184s + leap_seconds
```

The difference between UTC and TT is currently about 69 seconds (32.184s base + ~37 leap seconds as of 2025). For most applications, this difference is negligible—it shifts positions by fractions of an arcsecond.

> Important: If you need sub-arcsecond precision, use TT times explicitly or consult JPL's NAIF utilities for precise time conversions.

## Practical Examples

### Current Planetary Positions

```swift
// "Right now"
let now = Epoch(date: Date())
let mars = try await eph.state(of: .mars, at: now)
```

### Historical Event

```swift
// Apollo 11 Moon landing: July 20, 1969, 20:17:40 UTC
let apollo11 = Epoch(year: 1969, month: 7, day: 20, hour: 20, minute: 17, second: 40)
let moonThen = try await eph.state(of: .moon, at: apollo11)
```

### Future Planning

```swift
// Mars opposition in January 2025
let opposition = Epoch(year: 2025, month: 1, day: 16)
let earthMarsDistance = try await eph.distanceAU(between: .earth, and: .mars, at: opposition)
print("Distance at opposition: \(earthMarsDistance) AU")
```

### Looping Over Time

```swift
// Mars distance over one year
var epoch = Epoch(year: 2025, month: 1, day: 1)
let endEpoch = Epoch(year: 2026, month: 1, day: 1)

while epoch.julianDate < endEpoch.julianDate {
    let distance = try await eph.distanceAU(between: .earth, and: .mars, at: epoch)
    print("\(epoch.date): \(distance) AU")
    epoch = epoch.adding(days: 30)
}
```

## J2000.0: The Standard Epoch

**J2000.0** (Julian Date 2451545.0, January 1, 2000, 12:00 TT) is the standard reference epoch for modern astronomy:

- Coordinate frames are defined at this instant
- Orbital elements are typically given at J2000.0 with rates of change
- All catalogs and databases use J2000.0 as the common reference

The ``Epoch/j2000`` static property provides this epoch:

```swift
let j2000 = Epoch.j2000
print(j2000.julianDate)  // 2451545.0

// Time since J2000 in various units
let now = Epoch(date: Date())
let daysSinceJ2000 = now.days(since: .j2000)
let centuriesSinceJ2000 = now.julianCenturiesFromJ2000
```

## Valid Time Range

The bundled ephemeris data is valid from approximately **1800 AD to 2050 AD**:

```swift
let eph = try Ephemeris()
print(eph.validRange)  // "1800 AD to 2050 AD"
```

Queries outside this range may throw ``EphemerisError/invalidEpoch(_:)`` or return degraded accuracy. For dates outside this range, consider using ``HorizonsClient`` to query JPL's long-term ephemerides.

## See Also

- ``Epoch``
- ``Constants``
- <doc:UnderstandingOrbitalElements>
- <doc:UsingHorizonsAPI>
