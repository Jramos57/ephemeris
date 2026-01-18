import Foundation

/// A coordinate reference frame for expressing positions and velocities.
///
/// Different reference frames are used for different purposes in astronomy and
/// astrodynamics. The choice of frame affects how coordinates are interpreted
/// and how they transform over time.
///
/// ## Common Frames
///
/// - **ICRF (International Celestial Reference Frame)**: The standard inertial frame
///   aligned with distant quasars. Nearly identical to J2000 equatorial.
///
/// - **Ecliptic J2000**: The plane of Earth's orbit at J2000.0 epoch. Commonly used
///   for solar system dynamics as most planets orbit near this plane.
///
/// - **Body-fixed frames**: Rotate with a celestial body (e.g., IAU_EARTH).
///
/// ## Example
///
/// ```swift
/// let position = StateVector(
///     position: SIMD3(1.0, 0, 0) * Constants.AU,
///     velocity: SIMD3(0, 29780, 0),
///     epoch: .j2000,
///     frame: .eclipticJ2000
/// )
/// ```
public enum ReferenceFrame: String, Codable, Sendable, CaseIterable {
    
    /// International Celestial Reference Frame (ICRF).
    ///
    /// The standard inertial reference frame based on extragalactic radio sources.
    /// Aligned with the Earth's mean equator and equinox at J2000.0.
    /// This is the fundamental reference frame for modern astronomy.
    case icrf = "ICRF"
    
    /// Ecliptic plane at J2000.0 epoch.
    ///
    /// The x-axis points toward the vernal equinox, the z-axis is perpendicular
    /// to the ecliptic plane (toward ecliptic north pole), and the y-axis completes
    /// the right-handed system.
    ///
    /// This frame is commonly used for solar system dynamics because planetary
    /// orbits are nearly coplanar with the ecliptic.
    case eclipticJ2000 = "ECLIPJ2000"
    
    /// Mean equator and equinox of J2000.0.
    ///
    /// Equivalent to ICRF for most practical purposes. The equatorial plane
    /// is Earth's mean equator at J2000.0.
    case equatorialJ2000 = "J2000"
    
    /// Heliocentric frame centered on the Sun.
    ///
    /// Origin at the Sun's center, with axes aligned to ecliptic J2000.
    /// Used for planetary orbital mechanics.
    case heliocentricEcliptic = "HCI"
    
    /// The obliquity of the ecliptic at J2000.0 (degrees).
    ///
    /// This is the angle between the equatorial and ecliptic planes,
    /// used for transforming between equatorial and ecliptic coordinates.
    ///
    /// Value: 23.439291111 degrees (IAU 2006 value)
    public static let j2000Obliquity: Double = 23.439291111
    
    /// The obliquity of the ecliptic at J2000.0 (radians).
    public static let j2000ObliquityRadians: Double = j2000Obliquity * .pi / 180.0
}
