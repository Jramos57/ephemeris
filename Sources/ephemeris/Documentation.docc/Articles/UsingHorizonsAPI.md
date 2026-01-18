# Using the Horizons API

Validate your ephemeris calculations against JPL's high-precision data.

@Metadata {
    @PageImage(purpose: card, source: "horizons-api-card", alt: "A satellite dish communicating with space")
    @PageColor(blue)
}

## Overview

The **ephemeris** package includes bundled orbital data that's accurate enough for most applications. But for high-precision work—spacecraft navigation, eclipse prediction, or scientific research—you may want to validate against JPL's **Horizons system**, which provides state-of-the-art ephemeris data.

The ``HorizonsClient`` actor provides an async interface to the JPL Horizons API, letting you fetch precise state vectors and orbital elements for any solar system body.

## What is JPL Horizons?

[Horizons](https://ssd.jpl.nasa.gov/horizons/) is a service from NASA's Jet Propulsion Laboratory that provides:

- **High-precision ephemerides**: Based on the DE (Development Ephemeris) series, with sub-kilometer accuracy
- **All solar system bodies**: Planets, moons, asteroids, comets, spacecraft
- **Any time range**: From ancient history to centuries in the future
- **Multiple output formats**: State vectors, orbital elements, observer tables

The bundled data in **ephemeris** derives from Horizons, but with reduced precision to keep the package lightweight.

## Getting Started with HorizonsClient

### Creating a Client

```swift
import ephemeris

let horizons = HorizonsClient()
```

The client handles:
- Rate limiting (respects JPL's usage guidelines)
- Automatic retries on transient errors
- Response parsing and error handling

### Fetching a State Vector

```swift
let epoch = Epoch(year: 2025, month: 6, day: 1)

// Get Mars state relative to the Sun
let marsState = try await horizons.stateVector(
    for: .mars,
    at: epoch,
    relativeTo: .sun,
    frame: .eclipticJ2000
)

print("Position: \(marsState.position) meters")
print("Velocity: \(marsState.velocity) m/s")
print("Distance: \(marsState.distanceAU) AU")
```

### Comparing with Bundled Data

Here's how to validate the bundled ephemeris against Horizons:

```swift
import ephemeris

let eph = try Ephemeris()
let horizons = HorizonsClient()
let epoch = Epoch(date: Date())

// Get Mars from bundled data
let bundledMars = try await eph.state(of: .mars, at: epoch)

// Get Mars from Horizons
let horizonsMars = try await horizons.stateVector(
    for: .mars,
    at: epoch,
    relativeTo: .sun,
    frame: .eclipticJ2000
)

// Compare positions
let positionDiff = bundledMars.position - horizonsMars.position
let distanceError = simd_length(positionDiff)
let distanceErrorKm = distanceError / 1000

print("Position difference: \(distanceErrorKm) km")
print("Relative error: \(distanceError / horizonsMars.distance * 100)%")
```

Typical results for planets:
- **Inner planets**: ~100-1000 km error
- **Outer planets**: ~1000-10000 km error
- **Relative error**: Usually <0.001%

## Fetching Time Series

For trajectory visualization or analysis, fetch a series of state vectors:

```swift
let startEpoch = Epoch(year: 2025, month: 1, day: 1)
let endEpoch = Epoch(year: 2025, month: 12, day: 31)

// Get daily Mars positions for a year
let marsTraj = try await horizons.stateVectors(
    for: .mars,
    from: startEpoch,
    to: endEpoch,
    stepDays: 1,  // Daily samples
    relativeTo: .sun,
    frame: .eclipticJ2000
)

print("Got \(marsTraj.count) data points")

for (epoch, state) in marsTraj.prefix(5) {
    print("\(epoch.date): \(state.distanceAU) AU")
}
```

## Fetching Orbital Elements

You can also retrieve high-precision orbital elements:

```swift
let epoch = Epoch(year: 2025, month: 1, day: 1)

let marsElements = try await horizons.orbitalElements(
    for: .mars,
    at: epoch,
    relativeTo: .sun
)

print("Semi-major axis: \(marsElements.semiMajorAxis) AU")
print("Eccentricity: \(marsElements.eccentricity)")
print("Inclination: \(marsElements.inclination)°")
print("Period: \(marsElements.orbitalPeriodYears) years")
```

## Error Handling

The ``HorizonsClient`` can throw ``HorizonsError`` for various conditions:

```swift
do {
    let state = try await horizons.stateVector(for: .mars, at: epoch)
} catch HorizonsError.rateLimited {
    // JPL is throttling requests; wait and retry
    try await Task.sleep(for: .seconds(5))
    // retry...
    
} catch HorizonsError.invalidResponse {
    print("Received invalid data from Horizons")
    
} catch HorizonsError.maxRetriesExceeded {
    print("Network issues; try again later")
    
} catch HorizonsError.apiError(let message) {
    print("Horizons error: \(message)")
    
} catch {
    print("Unexpected error: \(error)")
}
```

### Error Types

| Error | Description | Resolution |
|-------|-------------|------------|
| `.rateLimited` | Too many requests | Wait before retrying |
| `.invalidResponse` | Malformed response | Check body/parameters |
| `.maxRetriesExceeded` | Network failures | Check connection |
| `.clientError(code)` | 4xx HTTP error | Check request |
| `.serverError(code)` | 5xx HTTP error | Horizons is down |
| `.noDataReturned` | Empty response | Check date range |
| `.apiError(message)` | Horizons-specific error | Read error message |

## Configuration Options

Customize the client's retry behavior:

```swift
let horizons = HorizonsClient(
    maxRetries: 5,           // Retry up to 5 times
    baseDelay: 2.0,          // Start with 2-second delay
    session: .shared         // Use custom URLSession if needed
)
```

The client uses exponential backoff with jitter for retries.

## Body Identifiers

The ``CelestialBody`` enum provides the correct Horizons identifiers:

```swift
// Each body has a NAIF ID and Horizons command string
print(CelestialBody.mars.naifId)        // 499
print(CelestialBody.mars.horizonsCommand)  // "499"

print(CelestialBody.moon.naifId)        // 301
print(CelestialBody.moon.horizonsCommand)  // "301"
```

You can also query bodies not in the ``CelestialBody`` enum by constructing requests manually (advanced usage).

## Rate Limiting and Best Practices

JPL Horizons is a free public service. Please use it responsibly:

1. **Cache results**: Don't fetch the same data repeatedly
2. **Batch requests**: Use `stateVectors(from:to:)` instead of many single queries
3. **Limit frequency**: Add delays between large batch operations
4. **Use bundled data first**: Only query Horizons when you need higher precision

```swift
// Good: Fetch a year of data in one call
let trajectory = try await horizons.stateVectors(
    for: .mars,
    from: startEpoch,
    to: endEpoch,
    stepDays: 1
)

// Avoid: 365 separate calls
for day in 0..<365 {
    let epoch = startEpoch.adding(days: Double(day))
    let state = try await horizons.stateVector(for: .mars, at: epoch)
    // This is inefficient and may get rate-limited
}
```

## Offline vs. Online Trade-offs

| Feature | Bundled Data | Horizons API |
|---------|--------------|--------------|
| Accuracy | ~0.001% relative | State-of-the-art |
| Time range | 1800-2050 AD | Any time |
| Bodies | Planets + major moons | Everything |
| Network | Not required | Required |
| Speed | Instantaneous | Seconds per query |
| Rate limits | None | Yes |

**Recommendation**: Use bundled data for visualization, UI, and exploration. Use Horizons for validation, scientific work, and precision applications.

## Example: Validation Script

Here's a complete validation script comparing bundled data to Horizons for all planets:

```swift
import ephemeris

@main
struct ValidateEphemeris {
    static func main() async throws {
        let eph = try Ephemeris()
        let horizons = HorizonsClient()
        let now = Epoch(date: Date())
        
        print("Validating ephemeris against JPL Horizons")
        print("Date: \(now.date)")
        print("=" * 60)
        print()
        
        for body in CelestialBody.planets {
            let bundled = try await eph.state(of: body, at: now)
            let precise = try await horizons.stateVector(
                for: body,
                at: now,
                relativeTo: .sun,
                frame: .eclipticJ2000
            )
            
            let posError = simd_length(bundled.position - precise.position)
            let velError = simd_length(bundled.velocity - precise.velocity)
            
            print("\(body.name):")
            print("  Position error: \(posError / 1000) km")
            print("  Velocity error: \(velError) m/s")
            print("  Relative error: \((posError / precise.distance) * 100)%")
            print()
            
            // Small delay to be polite to JPL
            try await Task.sleep(for: .milliseconds(500))
        }
    }
}
```

## See Also

- ``HorizonsClient``
- ``HorizonsError``
- ``CelestialBody``
- <doc:UnderstandingOrbitalElements>
- [JPL Horizons System](https://ssd.jpl.nasa.gov/horizons/)
