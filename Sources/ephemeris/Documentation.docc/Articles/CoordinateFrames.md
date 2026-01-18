# Coordinate Frames

Understand the reference frames used in ephemeris and when to use each one.

@Metadata {
    @PageImage(purpose: card, source: "coordinate-frames-card", alt: "Diagram of ecliptic and equatorial planes")
    @PageColor(blue)
}

## Overview

A position in space is meaningless without specifying *where you're measuring from* and *which direction is "up."* These choices define a **coordinate reference frame**. The ephemeris package supports several standard astronomical frames, each useful for different purposes.

## Why Reference Frames Matter

Consider asking "Where is Mars?" The answer depends on:

1. **Origin**: Are we measuring from the Sun? Earth? The solar system barycenter?
2. **Orientation**: Which direction is +X? Which plane is Z=0?
3. **Time**: Does the frame rotate with Earth, or is it fixed to distant stars?

Different frames answer these questions differently, optimizing for different use cases.

## Frames in ephemeris

The ``ReferenceFrame`` enum defines the available frames:

```swift
public enum ReferenceFrame: String, Codable, Sendable {
    case icrf                  // International Celestial Reference Frame
    case eclipticJ2000         // Ecliptic plane at J2000.0
    case equatorialJ2000       // Mean equator at J2000.0
    case heliocentricEcliptic  // Heliocentric with ecliptic axes
}
```

### Ecliptic J2000 (Default)

**Origin**: Sun  
**X-Y Plane**: Earth's orbital plane (the ecliptic) at epoch J2000.0  
**X-axis**: Points toward the vernal equinox (where the ecliptic crosses the celestial equator going north)

This is the **default frame** and the natural choice for solar system work:

```swift
let eph = try Ephemeris() // Uses eclipticJ2000 by default
let mars = try await eph.state(of: .mars, at: now)
// mars.position is in ecliptic coordinates
```

**Use when**: Visualizing the solar system, computing planetary positions, orbital mechanics calculations.

**Advantage**: All planets orbit close to the X-Y plane (low inclinations), making visualization intuitive.

### Equatorial J2000

**Origin**: Sun (in ephemeris; can be Earth-centered in other contexts)  
**X-Y Plane**: Earth's equatorial plane at J2000.0  
**X-axis**: Points toward the vernal equinox

The equatorial frame tilts ~23.4° relative to the ecliptic (this tilt is Earth's axial obliquity):

```swift
let eph = try Ephemeris(outputFrame: .equatorialJ2000)
let mars = try await eph.state(of: .mars, at: now)
// mars.position is in equatorial coordinates
```

**Use when**: Working with telescope observations (Right Ascension and Declination are defined in this frame), comparing with star catalogs.

### ICRF (International Celestial Reference Frame)

**Origin**: Solar system barycenter (center of mass)  
**Orientation**: Defined by distant quasars, essentially identical to equatorial J2000

The ICRF is the modern standard, replacing the older FK5 catalog. For most purposes, ICRF and equatorialJ2000 are interchangeable (differences are sub-milliarcsecond).

```swift
let eph = try Ephemeris(outputFrame: .icrf)
```

**Use when**: High-precision astrometry, interoperability with modern astronomical databases.

### Heliocentric Ecliptic

Same as eclipticJ2000 but explicitly named to emphasize the heliocentric origin. In the ephemeris package, this is functionally equivalent to `.eclipticJ2000`.

## Transforming Between Frames

The ``CoordinateTransform`` enum provides utilities for converting between frames:

```swift
// Convert a position from ecliptic to equatorial
let eclipticPos: SIMD3<Double> = [1.0, 0.0, 0.0]  // Along X-axis
let equatorialPos = CoordinateTransform.eclipticToEquatorial(eclipticPos)

// Convert a full state vector
let eclipticState = try await eph.state(of: .mars, at: now)
let equatorialState = CoordinateTransform.transform(eclipticState, to: .equatorialJ2000)
```

### The Obliquity of the Ecliptic

The transformation between ecliptic and equatorial frames is a rotation around the X-axis by the **obliquity**—the angle between the planes:

```swift
// The obliquity at J2000.0
let obliquity = ReferenceFrame.j2000Obliquity  // ≈ 23.439°
let obliquityRad = ReferenceFrame.j2000ObliquityRadians
```

The obliquity changes slowly over time due to precession and nutation, but for most applications the J2000.0 value is sufficient.

## Spherical Coordinates

For some applications, Cartesian (x, y, z) coordinates are less useful than spherical coordinates:

```swift
// Convert Cartesian to spherical (r, longitude, latitude)
let spherical = CoordinateTransform.cartesianToSpherical(position)
let r = spherical.0         // Distance in meters
let longitude = spherical.1 // Longitude in radians
let latitude = spherical.2  // Latitude in radians

// Convert to Right Ascension and Declination (equatorial frame)
let (ra, dec, distance) = CoordinateTransform.cartesianToRADec(equatorialPosition)
// ra: Right Ascension in radians
// dec: Declination in radians
// distance: in same units as input

// Convert back
let cartesian = CoordinateTransform.raDecToCartesian(ra: ra, dec: dec, distance: distance)
```

## Frame Considerations for Different Use Cases

| Use Case | Recommended Frame |
|----------|-------------------|
| Solar system visualization | `.eclipticJ2000` |
| Orbital mechanics calculations | `.eclipticJ2000` |
| Telescope pointing / star catalogs | `.equatorialJ2000` |
| Mission design / JPL compatibility | `.icrf` |
| Moon positions relative to Earth | `.eclipticJ2000` (then transform) |

## Important Notes

### J2000.0 Epoch

The "J2000" in frame names refers to the epoch at which the reference directions are defined:

- **J2000.0** = January 1, 2000, 12:00 TT (Terrestrial Time)
- **Julian Date** = 2451545.0

At this instant, the vernal equinox and celestial pole define the X-axis and Z-axis. Over time, precession shifts these directions, but J2000-based frames remain fixed—they don't follow the precession.

### Heliocentric vs. Barycentric

**ephemeris** returns heliocentric positions (Sun at origin). For the highest precision, especially for outer planets, you might need **barycentric** positions (solar system center of mass at origin). The difference is small—the barycenter wobbles around the Sun by about 1 solar radius—but matters for precision applications.

The ``HorizonsClient`` can return barycentric data from JPL for validation.

### Earth's Moon

Earth's Moon is close enough that the Earth-Moon barycenter (about 4,600 km from Earth's center) can matter. The ephemeris package computes the Moon's position relative to Earth's center, then transforms to heliocentric coordinates.

## See Also

- ``ReferenceFrame``
- ``CoordinateTransform``
- ``Constants``
- <doc:TimeAndEpochs>
