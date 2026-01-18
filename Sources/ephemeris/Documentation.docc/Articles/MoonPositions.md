# Moon Positions

Learn how ephemeris computes moon positions relative to their parent planets.

@Metadata {
    @PageImage(purpose: card, source: "moon-positions-card", alt: "A moon orbiting a planet with the Sun in the background")
    @PageColor(blue)
}

## Overview

While planets orbit the Sun, moons orbit planets. This hierarchical relationship requires special handling: we must first compute a moon's position relative to its parent planet, then transform that to the Sun-centered (heliocentric) frame used throughout **ephemeris**.

This article explains how the package handles moon computations and how to work with moon positions effectively.

## Available Moons

The ``CelestialBody`` enum includes major moons for several planets:

```swift
// Earth
.moon           // The Moon

// Mars
.phobos         // Inner moon, 9,377 km orbit
.deimos         // Outer moon, 23,460 km orbit

// Jupiter (Galilean moons)
.io             // Innermost, volcanic
.europa         // Potential subsurface ocean
.ganymede       // Largest moon in solar system
.callisto       // Outermost Galilean moon

// Saturn
.titan          // Largest Saturn moon, thick atmosphere
.enceladus      // Active geysers, subsurface ocean
.phoebe         // Distant, retrograde orbit
```

### Querying Available Moons

```swift
let eph = try Ephemeris()

// All available moons
let allMoons = eph.availableMoons
print(allMoons.map(\.name))

// Moons of a specific planet
let jupiterMoons = eph.moons(of: .jupiter)
print(jupiterMoons.map(\.name))  // ["Io", "Europa", "Ganymede", "Callisto"]

// Check if a body is a moon
print(CelestialBody.titan.isMoon)     // true
print(CelestialBody.titan.parent)     // .saturn
```

## Hierarchical Computation

When you query a moon's state, **ephemeris** performs these steps:

1. **Compute moon-relative-to-parent**: Using the moon's orbital elements around its parent planet
2. **Compute parent-relative-to-Sun**: Using the planet's heliocentric orbital elements  
3. **Add the vectors**: Transform the moon position to heliocentric coordinates

```swift
// This returns heliocentric position (relative to Sun)
let moonState = try await eph.state(of: .moon, at: now)

// To get position relative to Earth (the parent):
let moonFromEarth = try await eph.state(of: .moon, at: now, relativeTo: .earth)
print("Moon distance from Earth: \(moonFromEarth.distanceKm) km")
```

### Under the Hood

The computation uses ``KeplerSolver/stateVector(from:gmParent:epoch:orbitalPeriod:isRetrograde:frame:)`` for moon orbital elements, which differ slightly from planetary elements:

```swift
// Moon elements are stored differently - accessed via BundledEphemeris
let data = try BundledEphemeris.load()
if let moonElements = data.moonElements(for: .moon) {
    print("Semi-major axis: \(moonElements.semiMajorAxis) km")
    print("Eccentricity: \(moonElements.eccentricity)")
    print("Inclination: \(moonElements.inclination)°")
}
```

## Relative Positions

For many applications, you want positions relative to a parent body rather than the Sun:

### Moon-to-Parent Distance

```swift
// Distance from Earth to Moon
let moonFromEarth = try await eph.state(of: .moon, at: now, relativeTo: .earth)
print("Distance: \(moonFromEarth.distanceKm) km")  // ~384,400 km average

// Distance from Jupiter to Io
let ioFromJupiter = try await eph.state(of: .io, at: now, relativeTo: .jupiter)
print("Io distance: \(ioFromJupiter.distanceKm) km")  // ~421,700 km
```

### Relative Position Vectors

```swift
// Vector from Earth to Moon
let earthToMoon = try await eph.relativePosition(of: .moon, from: .earth, at: now)
print("Moon direction: \(earthToMoon)")

// The vector components
let x = earthToMoon.x  // meters in X direction
let y = earthToMoon.y  // meters in Y direction  
let z = earthToMoon.z  // meters in Z direction
```

### Distance Between Any Two Bodies

```swift
// Earth-Moon distance
let distance = try await eph.distance(between: .earth, and: .moon, at: now)
print("Earth-Moon: \(distance / 1000) km")

// Also works for moon-to-moon (across parent boundaries)
let europaToTitan = try await eph.distanceAU(between: .europa, and: .titan, at: now)
print("Europa to Titan: \(europaToTitan) AU")
```

## Retrograde Moons

Some moons orbit in the opposite direction to their parent planet's rotation—these are **retrograde** moons. Phoebe (Saturn's distant moon) is an example:

```swift
let data = try BundledEphemeris.load()
print("Phoebe is retrograde: \(data.isRetrograde(.phoebe))")  // true
```

The ``KeplerSolver`` handles retrograde orbits automatically when computing state vectors.

## Moon Orbital Periods

The bundled data includes orbital periods for accurate mean anomaly computation:

```swift
let data = try BundledEphemeris.load()

// Earth's Moon: ~27.3 days
if let moonPeriod = data.orbitalPeriod(of: .moon) {
    print("Lunar month: \(moonPeriod / 86400) days")
}

// Io: ~1.77 days
if let ioPeriod = data.orbitalPeriod(of: .io) {
    print("Io period: \(ioPeriod / 86400) days")
}
```

## Accuracy Considerations

Moon position accuracy varies by body:

| Moon | Accuracy | Notes |
|------|----------|-------|
| Earth's Moon | Excellent | Well-characterized orbit, precise elements |
| Phobos, Deimos | Good | Small, but well-studied |
| Galilean moons | Good | Strong mutual perturbations modeled approximately |
| Titan | Good | Largest Saturn moon, well-studied |
| Enceladus | Moderate | Smaller body |
| Phoebe | Moderate | Distant retrograde orbit |

For applications requiring high precision (spacecraft navigation, eclipse timing), validate against ``HorizonsClient`` data.

### Perturbations and Limitations

The Keplerian model treats each moon as orbiting only its parent. In reality:

- **Galilean moons**: Io, Europa, and Ganymede are in a 1:2:4 orbital resonance, causing mutual perturbations
- **Earth's Moon**: Solar gravity causes significant perturbations (evection, variation, annual equation)
- **Irregular moons**: Highly eccentric orbits are more affected by solar gravity

The bundled elements provide average behavior but don't capture these short-period variations.

## Example: Moon Positions for Visualization

Here's a complete example showing all moons of Jupiter relative to the planet:

```swift
import ephemeris

let eph = try Ephemeris()
let now = Epoch(date: Date())

// Get Jupiter and its moons
let jupiterMoons = eph.moons(of: .jupiter)

print("Jupiter's moons at \(now.date):")
print("=" * 50)

for moon in jupiterMoons {
    let state = try await eph.state(of: moon, at: now, relativeTo: .jupiter)
    let distanceKm = state.distanceKm
    let period = try BundledEphemeris.load().orbitalPeriod(of: moon)!
    
    print("""
        \(moon.name):
          Distance: \(String(format: "%.0f", distanceKm)) km
          Speed: \(String(format: "%.2f", state.speedKmPerSec)) km/s
          Period: \(String(format: "%.2f", period / 86400)) days
        """)
}
```

Output:
```
Jupiter's moons at 2025-01-15 12:00:00 +0000:
==================================================
Io:
  Distance: 421700 km
  Speed: 17.33 km/s
  Period: 1.77 days
Europa:
  Distance: 671034 km
  Speed: 13.74 km/s
  Period: 3.55 days
Ganymede:
  Distance: 1070412 km
  Speed: 10.88 km/s
  Period: 7.15 days
Callisto:
  Distance: 1882709 km
  Speed: 8.20 km/s
  Period: 16.69 days
```

## See Also

- ``CelestialBody``
- ``Ephemeris/state(of:at:relativeTo:)``
- ``Ephemeris/moons(of:)``
- ``BundledEphemeris/moonElements(for:)``
- <doc:UnderstandingOrbitalElements>
