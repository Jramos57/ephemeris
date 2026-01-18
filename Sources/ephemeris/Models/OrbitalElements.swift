import Foundation

/// Keplerian orbital elements describing an orbit.
///
/// Orbital elements are a set of six parameters that uniquely define an orbit
/// in space. This implementation uses the elements commonly provided by JPL
/// for planetary ephemerides.
///
/// ## Elements
///
/// - **Semi-major axis (a)**: Half the longest diameter of the ellipse (AU)
/// - **Eccentricity (e)**: Shape of orbit (0 = circle, 0-1 = ellipse, 1 = parabola, >1 = hyperbola)
/// - **Inclination (I)**: Tilt of orbital plane relative to reference plane (degrees)
/// - **Mean longitude (L)**: Position along orbit from reference direction (degrees)
/// - **Longitude of perihelion (ϖ)**: Direction of closest approach to Sun (degrees)
/// - **Longitude of ascending node (Ω)**: Where orbit crosses reference plane going "up" (degrees)
///
/// ## Example
///
/// ```swift
/// // Earth's orbital elements at J2000
/// let earth = OrbitalElements(
///     semiMajorAxis: 1.00000261,
///     eccentricity: 0.01671123,
///     inclination: -0.00001531,
///     meanLongitude: 100.46457166,
///     longitudeOfPerihelion: 102.93768193,
///     longitudeOfAscendingNode: 0.0,
///     epoch: .j2000
/// )
/// ```
///
/// ## References
///
/// - [JPL Approximate Positions of the Planets](https://ssd.jpl.nasa.gov/planets/approx_pos.html)
/// - Explanatory Supplement to the Astronomical Almanac, 3rd ed.
public struct OrbitalElements: Codable, Sendable, Hashable {
    
    // MARK: - Properties
    
    /// Semi-major axis in astronomical units (AU).
    ///
    /// For elliptical orbits, this is half the longest diameter.
    /// For hyperbolic orbits, this value is negative.
    public let semiMajorAxis: Double
    
    /// Orbital eccentricity (dimensionless).
    ///
    /// - 0: Circular orbit
    /// - 0 < e < 1: Elliptical orbit
    /// - 1: Parabolic trajectory
    /// - e > 1: Hyperbolic trajectory
    public let eccentricity: Double
    
    /// Inclination in degrees.
    ///
    /// The angle between the orbital plane and the reference plane (ecliptic).
    /// Range: 0° to 180°
    public let inclination: Double
    
    /// Mean longitude in degrees.
    ///
    /// L = M + ϖ, where M is mean anomaly and ϖ is longitude of perihelion.
    /// This represents the angular position along the orbit.
    public let meanLongitude: Double
    
    /// Longitude of perihelion in degrees.
    ///
    /// ϖ = Ω + ω, where Ω is longitude of ascending node and ω is argument of perihelion.
    /// This is the direction from the Sun to perihelion, measured in the reference plane.
    public let longitudeOfPerihelion: Double
    
    /// Longitude of the ascending node in degrees.
    ///
    /// The angle from the reference direction (vernal equinox) to the ascending node,
    /// measured in the reference plane.
    public let longitudeOfAscendingNode: Double
    
    /// The epoch at which these elements are valid.
    public let epoch: Epoch
    
    /// Rates of change per Julian century (optional).
    ///
    /// When provided, elements can be propagated to other epochs.
    public let rates: OrbitalElementRates?
    
    // MARK: - Initialization
    
    /// Creates orbital elements with the given parameters.
    ///
    /// - Parameters:
    ///   - semiMajorAxis: Semi-major axis in AU
    ///   - eccentricity: Orbital eccentricity (0 to ~1 for bound orbits)
    ///   - inclination: Inclination in degrees
    ///   - meanLongitude: Mean longitude in degrees
    ///   - longitudeOfPerihelion: Longitude of perihelion in degrees
    ///   - longitudeOfAscendingNode: Longitude of ascending node in degrees
    ///   - epoch: The reference epoch for these elements
    ///   - rates: Optional rates of change per Julian century
    public init(
        semiMajorAxis: Double,
        eccentricity: Double,
        inclination: Double,
        meanLongitude: Double,
        longitudeOfPerihelion: Double,
        longitudeOfAscendingNode: Double,
        epoch: Epoch,
        rates: OrbitalElementRates? = nil
    ) {
        self.semiMajorAxis = semiMajorAxis
        self.eccentricity = eccentricity
        self.inclination = inclination
        self.meanLongitude = meanLongitude
        self.longitudeOfPerihelion = longitudeOfPerihelion
        self.longitudeOfAscendingNode = longitudeOfAscendingNode
        self.epoch = epoch
        self.rates = rates
    }
    
    // MARK: - Computed Properties
    
    /// Argument of perihelion (ω) in degrees.
    ///
    /// The angle from the ascending node to the perihelion, measured in the orbital plane.
    /// ω = ϖ - Ω
    public var argumentOfPerihelion: Double {
        longitudeOfPerihelion - longitudeOfAscendingNode
    }
    
    /// Mean anomaly (M) in degrees.
    ///
    /// The angular position if the orbit were circular and the body moved at constant speed.
    /// M = L - ϖ
    public var meanAnomaly: Double {
        meanLongitude - longitudeOfPerihelion
    }
    
    /// Mean anomaly normalized to the range [-180°, 180°].
    ///
    /// This normalization is required for efficient solution of Kepler's equation.
    public var meanAnomalyNormalized: Double {
        var M = meanAnomaly.truncatingRemainder(dividingBy: 360.0)
        if M > 180.0 { M -= 360.0 }
        if M < -180.0 { M += 360.0 }
        return M
    }
    
    /// Perihelion distance (q) in AU.
    ///
    /// The closest approach distance to the central body.
    /// q = a(1 - e)
    public var perihelionDistance: Double {
        semiMajorAxis * (1.0 - eccentricity)
    }
    
    /// Aphelion distance (Q) in AU.
    ///
    /// The farthest distance from the central body (only meaningful for elliptical orbits).
    /// Q = a(1 + e)
    public var aphelionDistance: Double {
        semiMajorAxis * (1.0 + eccentricity)
    }
    
    /// Orbital period in years.
    ///
    /// Calculated from Kepler's third law: T² = a³ (for heliocentric orbits).
    /// Only meaningful for bound (elliptical) orbits.
    public var orbitalPeriodYears: Double {
        sqrt(pow(abs(semiMajorAxis), 3))
    }
    
    /// Orbital period in days.
    public var orbitalPeriodDays: Double {
        orbitalPeriodYears * 365.25
    }
    
    // MARK: - Orbit Type
    
    /// Whether this is an elliptical (bound) orbit.
    public var isElliptical: Bool {
        eccentricity >= 0 && eccentricity < 1
    }
    
    /// Whether this is a circular orbit (e ≈ 0).
    public var isCircular: Bool {
        eccentricity < 0.001
    }
    
    /// Whether this is a parabolic trajectory (e = 1).
    public var isParabolic: Bool {
        abs(eccentricity - 1.0) < 0.001
    }
    
    /// Whether this is a hyperbolic trajectory (e > 1).
    public var isHyperbolic: Bool {
        eccentricity > 1
    }
    
    // MARK: - Propagation
    
    /// Returns orbital elements propagated to a different epoch.
    ///
    /// If rates are available, elements are linearly extrapolated using:
    /// element(t) = element₀ + rate × T
    ///
    /// where T is the number of Julian centuries from the original epoch.
    ///
    /// - Parameter epoch: The target epoch.
    /// - Returns: Orbital elements at the new epoch.
    public func at(epoch targetEpoch: Epoch) -> OrbitalElements {
        guard let rates = rates else {
            // No rates available, return copy with new epoch
            return OrbitalElements(
                semiMajorAxis: semiMajorAxis,
                eccentricity: eccentricity,
                inclination: inclination,
                meanLongitude: meanLongitude,
                longitudeOfPerihelion: longitudeOfPerihelion,
                longitudeOfAscendingNode: longitudeOfAscendingNode,
                epoch: targetEpoch,
                rates: nil
            )
        }
        
        // Calculate centuries from original epoch to target
        let T = (targetEpoch.julianDate - epoch.julianDate) / 36525.0
        
        return OrbitalElements(
            semiMajorAxis: semiMajorAxis + rates.semiMajorAxisRate * T,
            eccentricity: eccentricity + rates.eccentricityRate * T,
            inclination: inclination + rates.inclinationRate * T,
            meanLongitude: meanLongitude + rates.meanLongitudeRate * T,
            longitudeOfPerihelion: longitudeOfPerihelion + rates.longitudeOfPerihelionRate * T,
            longitudeOfAscendingNode: longitudeOfAscendingNode + rates.longitudeOfAscendingNodeRate * T,
            epoch: targetEpoch,
            rates: rates
        )
    }
}

// MARK: - CustomStringConvertible

extension OrbitalElements: CustomStringConvertible {
    public var description: String {
        """
        OrbitalElements(epoch: \(epoch.julianDate))
          a = \(String(format: "%.6f", semiMajorAxis)) AU
          e = \(String(format: "%.6f", eccentricity))
          I = \(String(format: "%.4f", inclination))°
          L = \(String(format: "%.4f", meanLongitude))°
          ϖ = \(String(format: "%.4f", longitudeOfPerihelion))°
          Ω = \(String(format: "%.4f", longitudeOfAscendingNode))°
        """
    }
}

// MARK: - OrbitalElementRates

/// Rates of change for orbital elements, per Julian century.
///
/// These rates allow orbital elements to be propagated to different epochs
/// using linear extrapolation. They are typically derived from curve fits
/// to numerical integrations or observations.
///
/// ## Example
///
/// ```swift
/// // Earth's element rates (from JPL)
/// let earthRates = OrbitalElementRates(
///     semiMajorAxisRate: 0.00000562,      // AU/century
///     eccentricityRate: -0.00004392,       // /century
///     inclinationRate: -0.01294668,        // deg/century
///     meanLongitudeRate: 35999.37244981,   // deg/century
///     longitudeOfPerihelionRate: 0.32327364,
///     longitudeOfAscendingNodeRate: 0.0
/// )
/// ```
public struct OrbitalElementRates: Codable, Sendable, Hashable {
    
    /// Rate of change of semi-major axis (AU per Julian century).
    public let semiMajorAxisRate: Double
    
    /// Rate of change of eccentricity (per Julian century).
    public let eccentricityRate: Double
    
    /// Rate of change of inclination (degrees per Julian century).
    public let inclinationRate: Double
    
    /// Rate of change of mean longitude (degrees per Julian century).
    ///
    /// This is approximately the mean motion in degrees per century.
    public let meanLongitudeRate: Double
    
    /// Rate of change of longitude of perihelion (degrees per Julian century).
    public let longitudeOfPerihelionRate: Double
    
    /// Rate of change of longitude of ascending node (degrees per Julian century).
    public let longitudeOfAscendingNodeRate: Double
    
    /// Creates orbital element rates.
    ///
    /// - Parameters:
    ///   - semiMajorAxisRate: AU per Julian century
    ///   - eccentricityRate: Per Julian century
    ///   - inclinationRate: Degrees per Julian century
    ///   - meanLongitudeRate: Degrees per Julian century
    ///   - longitudeOfPerihelionRate: Degrees per Julian century
    ///   - longitudeOfAscendingNodeRate: Degrees per Julian century
    public init(
        semiMajorAxisRate: Double,
        eccentricityRate: Double,
        inclinationRate: Double,
        meanLongitudeRate: Double,
        longitudeOfPerihelionRate: Double,
        longitudeOfAscendingNodeRate: Double
    ) {
        self.semiMajorAxisRate = semiMajorAxisRate
        self.eccentricityRate = eccentricityRate
        self.inclinationRate = inclinationRate
        self.meanLongitudeRate = meanLongitudeRate
        self.longitudeOfPerihelionRate = longitudeOfPerihelionRate
        self.longitudeOfAscendingNodeRate = longitudeOfAscendingNodeRate
    }
}
