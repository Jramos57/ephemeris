# ephemeris

A Swift package for computing positions and velocities of planets, moons, and other solar system bodies at any point in time.

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20|%20iOS%20|%20watchOS%20|%20tvOS%20|%20visionOS-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Overview

**ephemeris** uses Keplerian orbital mechanics with JPL orbital elements to compute heliocentric positions for:

- All 8 planets (Mercury through Neptune)
- Dwarf planets (Ceres, Pluto)
- Major moons (Earth's Moon, Mars's moons, Jupiter's Galilean moons, Saturn's major moons)

### Key Features

- **Offline Operation** — Bundled orbital data from JPL, valid 1800-2050 AD
- **Moon Support** — Hierarchical moon positions computed relative to parent planets
- **Coordinate Frames** — Ecliptic J2000, Equatorial J2000/ICRF transformations
- **Thread-Safe** — Actor-based design for safe concurrent access
- **Optional Online Data** — JPL Horizons API client for high-precision validation

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Jramos57/ephemeris.git", from: "1.0.0")
]
```

Then add to your target:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["ephemeris"]
    )
]
```

### Xcode

1. **File → Add Package Dependencies...**
2. Enter: `https://github.com/Jramos57/ephemeris`
3. Click **Add Package**

## Quick Start

```swift
import ephemeris

// Create the ephemeris engine
let eph = try Ephemeris()

// Get Mars position right now
let now = Epoch(date: Date())
let mars = try await eph.state(of: .mars, at: now)

print("Mars is \(mars.distanceAU) AU from the Sun")
print("Moving at \(mars.speedKmPerSec) km/s")

// Earth-Mars distance
let distance = try await eph.distanceAU(between: .earth, and: .mars, at: now)
print("Earth-Mars: \(distance) AU")
```

### Working with Moons

```swift
// Get the Moon's position relative to Earth
let moonFromEarth = try await eph.state(of: .moon, at: now, relativeTo: .earth)
print("Moon distance: \(moonFromEarth.distanceKm) km")

// Jupiter's moons
let jupiterMoons = eph.moons(of: .jupiter)
for moon in jupiterMoons {
    let state = try await eph.state(of: moon, at: now, relativeTo: .jupiter)
    print("\(moon.name): \(state.distanceKm) km from Jupiter")
}
```

### Time Handling

```swift
// From a Date
let now = Epoch(date: Date())

// From calendar components
let launch = Epoch(year: 2025, month: 7, day: 4, hour: 12, minute: 0, second: 0)

// From Julian Date
let jd = Epoch(julianDate: 2460676.5)

// Standard epoch
let j2000 = Epoch.j2000
```

### Coordinate Frames

```swift
// Default: Ecliptic J2000 (best for solar system visualization)
let eph = try Ephemeris()

// Equatorial J2000 (for telescope/RA-Dec work)
let eph = try Ephemeris(outputFrame: .equatorialJ2000)

// Transform between frames
let equatorial = CoordinateTransform.eclipticToEquatorial(eclipticPosition)
```

## Available Bodies

### Planets
`mercury`, `venus`, `earth`, `mars`, `jupiter`, `saturn`, `uranus`, `neptune`

### Dwarf Planets
`ceres`, `pluto`

### Moons
| Parent | Moons |
|--------|-------|
| Earth | `moon` |
| Mars | `phobos`, `deimos` |
| Jupiter | `io`, `europa`, `ganymede`, `callisto` |
| Saturn | `titan`, `enceladus`, `phoebe` |

## JPL Horizons Validation

For high-precision work, validate against JPL's Horizons system:

```swift
let horizons = HorizonsClient()

// Fetch precise Mars state
let preciseMars = try await horizons.stateVector(
    for: .mars,
    at: now,
    relativeTo: .sun,
    frame: .eclipticJ2000
)

// Compare with bundled data
let bundledMars = try await eph.state(of: .mars, at: now)
let error = simd_length(bundledMars.position - preciseMars.position)
print("Position difference: \(error / 1000) km")
```

## Accuracy

| Bodies | Accuracy | Valid Range |
|--------|----------|-------------|
| Planets | < 1 arcminute | 1900-2100 AD |
| Earth's Moon | Excellent | 1900-2100 AD |
| Other moons | Variable | 1900-2100 AD |
| Outside range | Degraded | 1800-2050 AD |

For spacecraft navigation or eclipse prediction, use `HorizonsClient` for higher precision.

## Platform Requirements

- macOS 15+
- iOS 18+
- watchOS 11+
- tvOS 18+
- visionOS 2+
- Swift 6.0+

## Documentation

Full documentation is available at:
- [GitHub Pages](https://jramos57.github.io/ephemeris/documentation/ephemeris/)
- [Swift Package Index](https://swiftpackageindex.com/Jramos57/ephemeris/documentation)

## License

MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

Orbital data derived from [JPL Solar System Dynamics](https://ssd.jpl.nasa.gov/).
