# Capabilities and Limitations

Understand the precision, intended use cases, and technical trade-offs of the ephemeris library.

@Metadata {
    @PageColor(purple)
}

## The Verdict: "Visualization-Grade"

This library is an **excellent choice for visualization applications** (planetariums, educational apps, games, augmented reality). However, it is designed for speed and ease of use rather than the sub-arcsecond precision required for professional astrometry or spacecraft navigation.

### What it Does Well

* **Correct J2000 Implementation:** Everything is anchored to the J2000 epoch, the industry standard for mapping and visualization.
* **Robust Math:** Orbital positions are calculated using **Newton-Raphson iteration** on Kepler’s equation, ensuring mathematical stability.
* **Tilt Handling:** Effectively manages the transformation between "Ecliptic" (solar system plane) and "Equatorial" (Earth's tilted plane) using the J2000 obliquity (~23.4°).
* **Developer Experience:** Native Swift types (`SIMD3`), `Spherical`/`Cartesian` helpers, and integration-ready outputs for SceneKit/RealityKit.

### Limitations

If you are building a telescope controller or high-precision navigation tool, be aware of the following:

#### 1. Precision of Equinoxes (J2000 vs. JNow)

* **The Issue:** The J2000 coordinate frame is "fixed" to the Earth's orientation on Jan 1, 2000. Because Earth wobbles (precession), the "North" of today is slightly different from the "North" of 2000.
* **Magnitude:** The difference grows by about 50 arcseconds per year. In 2025, this amounts to nearly **0.35 degrees**.
* **Impact:** Negligible for hand-held AR apps, but significant for pointing a physical telescope.
* **Solution:** Use the ``CoordinateTransform/convertJ2000ToJNow(_:at:)`` method to apply a precession matrix when current-date accuracy is required.

#### 2. Heliocentric vs. Barycentric

* **The Issue:** `ephemeris` calculates positions relative to the Sun (heliocentric). High-precision standards (like ICRF) use the Solar System Barycenter (center of mass).
* **Magnitude:** The Sun wobbles around the barycenter by up to ~2 solar radii due to Jupiter's gravity.
* **Impact:** Causes position errors of ~1500 km for outer planets. This is invisible to the eye but critical for spaceflight simulation.

## Summary Table

| Feature | `ephemeris` Library | Professional Standard (e.g. SPICE) | Use This Library If... |
| --- | --- | --- | --- |
| **Math Model** | Keplerian Elements (Approximate) | Numerical Integration (Exact) | You want speed & offline use. |
| **Accuracy** | ~1-2 arcminutes | < 0.001 arcseconds | You are building a planetarium app. |
| **Reference** | Fixed J2000 | True Equator & Equinox of Date | You usually don't need to blind-point a telescope. |
| **Origin** | Sun-Centered | Barycenter-Centered | You don't need physics-grade precision. |
