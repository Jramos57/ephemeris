# Getting Started with ephemeris

Learn how to add ephemeris to your project and compute your first planetary position.

@Metadata {
    @PageImage(purpose: card, source: "getting-started-card", alt: "A planet orbiting around the sun")
    @PageColor(blue)
}

## Overview

This guide walks you through adding **ephemeris** to your Swift project and computing positions of planets and moons. By the end, you'll understand the core workflow: create an ``Ephemeris`` instance, specify a time using ``Epoch``, and retrieve position data as a ``StateVector``.

## Adding ephemeris to Your Project

### Swift Package Manager

Add ephemeris to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/Jramos57/ephemeris.git", from: "1.0.0")
]
```

Then add it to your target:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["ephemeris"]
    )
]
```

### Xcode Project

1. Open your project in Xcode
2. Go to **File → Add Package Dependencies...**
3. Enter the repository URL: `https://github.com/Jramos57/ephemeris`
4. Click **Add Package**

## Your First Ephemeris Query

### Step 1: Import and Create the Ephemeris

```swift
import ephemeris

// Create the ephemeris engine
// This loads bundled orbital data from JPL
let eph = try Ephemeris()
```

The ``Ephemeris`` actor loads orbital elements for all planets and moons from bundled data. This data is valid from approximately 1800 AD to 2050 AD.

### Step 2: Specify a Point in Time

The ``Epoch`` type represents a specific moment in time. You can create one from a Foundation `Date`, a Julian Date, or calendar components:

```swift
// From the current date
let now = Epoch(date: Date())

// From a specific calendar date (January 1, 2025, noon UTC)
let newYear = Epoch(year: 2025, month: 1, day: 1, hour: 12, minute: 0, second: 0)

// From a Julian Date
let jd = Epoch(julianDate: 2460676.5)

// The standard J2000.0 epoch (January 1, 2000, 12:00 TT)
let j2000 = Epoch.j2000
```

### Step 3: Query a Body's State

Use ``Ephemeris/state(of:at:)`` to get a body's position and velocity:

```swift
// Get Mars state at the current time
let marsState = try await eph.state(of: .mars, at: now)

// Access position and velocity
print("Position: \(marsState.position) meters")
print("Velocity: \(marsState.velocity) m/s")

// Use convenience properties
print("Distance from Sun: \(marsState.distanceAU) AU")
print("Speed: \(marsState.speedKmPerSec) km/s")
```

The ``StateVector`` contains the body's 3D position (in meters) and velocity (in m/s) in the specified coordinate frame, along with many useful computed properties.

## Common Queries

### Get Position Only

If you only need position without velocity:

```swift
let position = try await eph.position(of: .jupiter, at: now)
print("Jupiter position: \(position)") // SIMD3<Double> in meters
```

### Distance from the Sun

```swift
let distance = try await eph.distance(of: .saturn, at: now)
print("Saturn is \(distance / Constants.au) AU from the Sun")
```

### Distance Between Two Bodies

```swift
// Earth-Mars distance (useful for mission planning)
let earthMars = try await eph.distanceAU(between: .earth, and: .mars, at: now)
print("Earth-Mars: \(earthMars) AU")

// This varies from ~0.5 AU (opposition) to ~2.5 AU (conjunction)
```

### Query Multiple Bodies at Once

For efficiency, query multiple bodies in a single call:

```swift
// Get all planets at once
let allPlanets = try await eph.allPlanetStates(at: now)

for (body, state) in allPlanets.sorted(by: { $0.value.distanceAU < $1.value.distanceAU }) {
    print("\(body.name): \(state.distanceAU) AU from Sun")
}

// Or specific bodies
let innerPlanets: [CelestialBody] = [.mercury, .venus, .earth, .mars]
let states = try await eph.states(of: innerPlanets, at: now)
```

## Working with Moons

Moons are computed hierarchically—first relative to their parent planet, then transformed to heliocentric coordinates:

```swift
// Get the Moon's position (heliocentric by default)
let moonState = try await eph.state(of: .moon, at: now)

// Get the Moon's position relative to Earth
let moonFromEarth = try await eph.state(of: .moon, at: now, relativeTo: .earth)
print("Moon is \(moonFromEarth.distanceKm) km from Earth")

// List available moons
print("Available moons: \(eph.availableMoons.map(\.name))")

// Get moons of a specific planet
let jupiterMoons = eph.moons(of: .jupiter)
print("Jupiter's moons: \(jupiterMoons.map(\.name))")
// Prints: ["Io", "Europa", "Ganymede", "Callisto"]
```

## Available Celestial Bodies

The ``CelestialBody`` enum provides all supported bodies:

```swift
// Planets
CelestialBody.mercury, .venus, .earth, .mars, .jupiter, .saturn, .uranus, .neptune

// Dwarf planets
CelestialBody.ceres, .pluto

// Moons
CelestialBody.moon           // Earth's Moon
CelestialBody.phobos, .deimos // Mars
CelestialBody.io, .europa, .ganymede, .callisto // Jupiter (Galilean moons)
CelestialBody.titan, .enceladus, .phoebe // Saturn

// Static collections
CelestialBody.planets  // All 8 planets
CelestialBody.moons    // All supported moons
```

## Coordinate Frames

By default, ephemeris returns positions in the **Ecliptic J2000** frame—the standard for solar system work. You can change this at initialization:

```swift
// Use equatorial coordinates (RA/Dec aligned)
let eph = try Ephemeris(outputFrame: .equatorialJ2000)

// Or ICRF (nearly identical to equatorial J2000)
let eph = try Ephemeris(outputFrame: .icrf)
```

See <doc:CoordinateFrames> for details on when to use each frame.

## Error Handling

The ephemeris methods can throw ``EphemerisError``:

```swift
do {
    let state = try await eph.state(of: .mars, at: epoch)
} catch EphemerisError.bodyNotFound(let body) {
    print("Body not available: \(body)")
} catch EphemerisError.invalidEpoch(let epoch) {
    print("Epoch outside valid range: \(epoch)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Next Steps

Now that you can compute planetary positions, explore these topics:

- <doc:UnderstandingOrbitalElements> — Learn what orbital elements mean and how ephemeris uses them
- <doc:CoordinateFrames> — Understand when to use different reference frames
- <doc:TimeAndEpochs> — Deep dive into Julian dates and time handling
- <doc:MoonPositions> — How hierarchical moon computations work
- <doc:UsingHorizonsAPI> — Validate your results against JPL's high-precision data
