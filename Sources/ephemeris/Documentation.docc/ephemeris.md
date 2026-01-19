# ``ephemeris``

Compute precise positions and velocities of planets, moons, and other solar system bodies at any point in time.

@Metadata {
    @DisplayName("ephemeris")
    @PageImage(purpose: icon, source: "ephemeris-icon", alt: "A stylized orbit path around a central body")
    @PageColor(blue)
}

## Overview

**ephemeris** is a Swift package for computing the positions and velocities of solar system bodies using Keplerian orbital mechanics. Whether you're building a planetarium app, a spacecraft mission planner, or just exploring celestial mechanics, this package provides accurate ephemeris data with an easy-to-use API.

The package computes heliocentric (Sun-centered) positions for:
- All 8 planets (Mercury through Neptune)
- Dwarf planets (Ceres, Pluto)
- Major moons (Earth's Moon, Mars's moons, Jupiter's Galilean moons, and more)

### Key Features

- **Offline Operation**: Bundled orbital elements from JPL, valid from 1800-2050 AD
- **Moon Support**: Hierarchical moon positions computed relative to their parent planets
- **Coordinate Frames**: Transform between Ecliptic J2000, Equatorial J2000/ICRF, and more
- **Thread-Safe**: Actor-based design for safe concurrent access
- **Optional Online Data**: JPL Horizons API client for high-precision validation

### Quick Example

```swift
import ephemeris

// Create the ephemeris engine
let eph = try Ephemeris()

// Get Mars position right now
let now = Epoch(date: Date())
let marsState = try await eph.state(of: .mars, at: now)

print("Mars is \(marsState.distanceAU) AU from the Sun")
print("Moving at \(marsState.speedKmPerSec) km/s")

// Get Earth-Mars distance
let distance = try await eph.distanceAU(between: .earth, and: .mars, at: now)
print("Earth-Mars distance: \(distance) AU")
```

## Topics

### Essentials

- <doc:GettingStarted>
- ``Ephemeris``
- ``CelestialBody``

### Understanding the Concepts

- <doc:UnderstandingOrbitalElements>
- <doc:CoordinateFrames>
- <doc:TimeAndEpochs>
- <doc:MoonPositions>
- <doc:Capabilities>

### Core Types

- ``StateVector``
- ``OrbitalElements``
- ``Epoch``
- ``ReferenceFrame``

### Data Sources

- ``BundledEphemeris``
- ``HorizonsClient``
- <doc:UsingHorizonsAPI>

### Constants and Utilities

- ``Constants``
- ``KeplerSolver``
- ``CoordinateTransform``

### Error Handling

- ``EphemerisError``
- ``HorizonsError``
