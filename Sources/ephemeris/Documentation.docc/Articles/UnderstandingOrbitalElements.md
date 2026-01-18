# Understanding Orbital Elements

Learn how Keplerian orbital elements describe an orbit and how ephemeris uses them to compute positions.

@Metadata {
    @PageImage(purpose: card, source: "orbital-elements-card", alt: "Diagram showing orbital elements")
    @PageColor(blue)
}

## Overview

Every planet, moon, and spacecraft follows a path through space governed by gravity. Rather than storing millions of position snapshots, we describe these orbits mathematically using **Keplerian orbital elements**—six numbers that completely define an orbit's size, shape, and orientation.

This article explains what each orbital element means, how they combine to describe an orbit, and how **ephemeris** uses them to compute positions at any time.

## The Two-Body Problem

Johannes Kepler discovered in the early 1600s that planets orbit the Sun in ellipses, not circles. Isaac Newton later proved this mathematically: two bodies orbiting each other under gravity trace out conic sections (circles, ellipses, parabolas, or hyperbolas).

For planets orbiting the Sun, we treat this as a **two-body problem**: the Sun and one planet, ignoring all other bodies. This simplification works remarkably well because the Sun contains 99.8% of the solar system's mass.

> Note: Real planetary orbits are perturbed by other planets, causing the orbital elements to slowly change over time. The ephemeris package handles this by storing **rates of change** for each element.

## The Six Classical Orbital Elements

An orbit in 3D space requires six numbers to fully describe:

### Shape and Size

**Semi-major axis (a)** — The "average radius" of the orbit. For an ellipse, it's half the longest diameter. Measured in AU (astronomical units) or meters.

```
a = 1.0 AU  →  Earth's orbital size
a = 5.2 AU  →  Jupiter's orbital size
```

**Eccentricity (e)** — How elongated the orbit is:
- `e = 0` → Perfect circle
- `0 < e < 1` → Ellipse (all planets)
- `e = 1` → Parabola (escape trajectory)
- `e > 1` → Hyperbola (unbound trajectory)

```
e = 0.017  →  Earth (nearly circular)
e = 0.206  →  Mercury (most eccentric planet)
e = 0.967  →  Halley's Comet (highly elongated)
```

### Orientation in Space

**Inclination (i)** — The tilt of the orbital plane relative to a reference plane (usually the ecliptic—Earth's orbital plane). Measured in degrees.

```
i = 0°   →  Orbit lies in the ecliptic plane
i = 7°   →  Mercury (most inclined planet)
i = 17°  →  Pluto
i = 90°  →  Polar orbit
```

**Longitude of ascending node (Ω)** — Where the orbit crosses the reference plane going "upward" (south to north). Measured in degrees from the vernal equinox direction.

**Argument of perihelion (ω)** — The angle from the ascending node to the perihelion (closest point to the Sun), measured in the orbital plane. Sometimes expressed as **longitude of perihelion (ϖ = Ω + ω)**.

### Position in Orbit

**Mean anomaly (M)** — Where the body is along its orbit at a reference time. This isn't the true angle—it's a mathematical convenience that increases uniformly with time.

```
M = 0°    →  At perihelion
M = 180°  →  At aphelion
```

The mean anomaly changes at a constant rate:

```
M(t) = M₀ + n × (t - t₀)
```

Where `n` is the **mean motion** (360° divided by the orbital period).

## From Elements to Position

The ephemeris package uses ``KeplerSolver`` to convert orbital elements to Cartesian coordinates (x, y, z position and velocity). The process has three main steps:

### Step 1: Solve Kepler's Equation

The mean anomaly `M` tells us *when* the body is in its orbit, but we need the **true anomaly** `ν` (the actual angle from perihelion). This requires solving **Kepler's equation**:

```
M = E - e × sin(E)
```

Where `E` is the **eccentric anomaly**, an intermediate angle. This equation has no closed-form solution—we must solve it iteratively.

```swift
// The KeplerSolver handles this automatically
let E = KeplerSolver.solveKepler(meanAnomaly: M, eccentricity: e)
let trueAnomaly = KeplerSolver.trueAnomaly(eccentricAnomaly: E, eccentricity: e)
```

### Step 2: Compute Position in the Orbital Plane

With the true anomaly, we can compute the position in the orbit's own coordinate system:

```
r = a × (1 - e²) / (1 + e × cos(ν))  // Distance from focus
x_orbital = r × cos(ν)
y_orbital = r × sin(ν)
z_orbital = 0  // By definition, the orbit lies in its plane
```

### Step 3: Rotate to the Reference Frame

Finally, we apply three rotations to transform from the orbital plane to the reference frame (e.g., Ecliptic J2000):

1. Rotate by `-ω` (argument of perihelion)
2. Rotate by `-i` (inclination)
3. Rotate by `-Ω` (longitude of ascending node)

```swift
// The ephemeris package handles all this internally
let state = try await eph.state(of: .mars, at: epoch)
```

## Orbital Elements in ephemeris

The ``OrbitalElements`` struct represents a complete set of Keplerian elements:

```swift
let elements = try await eph.orbitalElements(for: .mars)

print("Semi-major axis: \(elements.semiMajorAxis) AU")
print("Eccentricity: \(elements.eccentricity)")
print("Inclination: \(elements.inclination)°")
print("Period: \(elements.orbitalPeriodYears) years")

// Derived properties
print("Perihelion: \(elements.perihelionDistance) AU")
print("Aphelion: \(elements.aphelionDistance) AU")
print("Is elliptical: \(elements.isElliptical)")
```

### Element Rates

Planetary orbits slowly change due to gravitational perturbations from other planets. The bundled data includes **rates of change** per Julian century:

```swift
if let rates = elements.rates {
    print("Semi-major axis rate: \(rates.semiMajorAxisRate) AU/century")
    print("Eccentricity rate: \(rates.eccentricityRate) /century")
}
```

When you request a state at a specific epoch, the package automatically propagates the elements forward or backward in time using these rates:

```swift
// Elements at J2000
let elementsJ2000 = try await eph.orbitalElements(for: .jupiter, at: .j2000)

// Elements propagated to 2025
let epoch2025 = Epoch(year: 2025, month: 1, day: 1)
let elements2025 = try await eph.orbitalElements(for: .jupiter, at: epoch2025)
```

## Limitations of Keplerian Elements

The two-body approximation has limits:

1. **Perturbations**: Other planets slightly tug on each orbit, causing precession and other long-term changes. The element rates help, but accuracy degrades for dates far from J2000.

2. **Moons**: Moons orbit their parent planets, not the Sun. Their elements are defined relative to the parent, then transformed to heliocentric coordinates. See <doc:MoonPositions>.

3. **Small bodies**: Asteroids and comets can have highly eccentric orbits with strong perturbations. For these, consider using ``HorizonsClient`` for more accurate data.

## Accuracy Notes

The bundled ephemeris data achieves:

- **Planetary positions**: Better than 1 arcminute accuracy for 1900-2100 AD
- **Moon positions**: Variable accuracy; Earth's Moon is excellent, outer moons are approximate
- **Outside 1800-2050 AD**: Accuracy degrades significantly

For applications requiring higher precision (spacecraft navigation, eclipse prediction), use the ``HorizonsClient`` to query JPL's high-fidelity ephemerides.

## See Also

- ``OrbitalElements``
- ``KeplerSolver``
- ``Ephemeris/orbitalElements(for:at:)``
- <doc:CoordinateFrames>
