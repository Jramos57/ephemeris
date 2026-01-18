import Foundation
import simd

/// Solves Kepler's equation and computes orbital positions.
///
/// Kepler's equation relates the mean anomaly M to the eccentric anomaly E:
///
/// ```
/// M = E - e*sin(E)
/// ```
///
/// Given M and e, we solve for E using Newton-Raphson iteration,
/// then compute the position in the orbital plane.
///
/// ## Algorithm
///
/// The Newton-Raphson iteration for Kepler's equation:
///
/// ```
/// E_{n+1} = E_n + ΔE
/// where ΔE = ΔM / (1 - e*cos(E_n))
/// and ΔM = M - (E_n - e*sin(E_n))
/// ```
///
/// Starting guess: E_0 = M + e*sin(M) (faster convergence)
///
/// ## References
///
/// - [JPL Approximate Positions](https://ssd.jpl.nasa.gov/planets/approx_pos.html)
/// - Explanatory Supplement to the Astronomical Almanac, 3rd ed.
public enum KeplerSolver {
    
    /// Default convergence tolerance (degrees).
    public static let defaultTolerance: Double = 1e-8
    
    /// Maximum iterations for Newton-Raphson.
    public static let maxIterations: Int = 50
    
    // MARK: - Kepler Equation
    
    /// Solves Kepler's equation for the eccentric anomaly.
    ///
    /// Given the mean anomaly M and eccentricity e, finds the eccentric anomaly E
    /// such that M = E - e*sin(E).
    ///
    /// - Parameters:
    ///   - meanAnomaly: Mean anomaly in degrees (should be in range -180 to 180 for best results).
    ///   - eccentricity: Orbital eccentricity (0 ≤ e < 1 for elliptical orbits).
    ///   - tolerance: Convergence tolerance in degrees. Default is 1e-8.
    /// - Returns: Eccentric anomaly in degrees.
    public static func solveKepler(
        meanAnomaly M: Double,
        eccentricity e: Double,
        tolerance: Double = defaultTolerance
    ) -> Double {
        // Handle circular orbit (trivial case)
        guard e > 0 else { return M }
        
        // Convert e to e* for degree-based calculation
        // e* = e * (180/π) so that: M = E - e* * sin(E) works in degrees
        let eStar = e * 180.0 / .pi
        
        // Starting guess: E_0 = M + e* * sin(M)
        // This provides faster convergence than E_0 = M
        let MRad = M * .pi / 180.0
        var E = M + eStar * sin(MRad)
        
        // Newton-Raphson iteration
        for _ in 0..<maxIterations {
            let ERad = E * .pi / 180.0
            let sinE = sin(ERad)
            let cosE = cos(ERad)
            
            // ΔM = M - (E - e* * sin(E))
            let deltaM = M - (E - eStar * sinE)
            
            // ΔE = ΔM / (1 - e * cos(E))
            let deltaE = deltaM / (1.0 - e * cosE)
            
            E += deltaE
            
            // Check convergence
            if abs(deltaE) <= tolerance {
                break
            }
        }
        
        return E
    }
    
    // MARK: - True Anomaly
    
    /// Converts eccentric anomaly to true anomaly.
    ///
    /// The true anomaly ν is the actual angle from perihelion to the body's position,
    /// as seen from the focus of the ellipse.
    ///
    /// Formula:
    /// ```
    /// tan(ν/2) = sqrt((1+e)/(1-e)) * tan(E/2)
    /// ```
    ///
    /// - Parameters:
    ///   - eccentricAnomaly: Eccentric anomaly E in degrees.
    ///   - eccentricity: Orbital eccentricity (0 ≤ e < 1).
    /// - Returns: True anomaly in degrees.
    public static func trueAnomaly(
        eccentricAnomaly E: Double,
        eccentricity e: Double
    ) -> Double {
        // Handle circular orbit
        guard e > 0 else { return E }
        
        let ERad = E * .pi / 180.0
        
        // tan(ν/2) = sqrt((1+e)/(1-e)) * tan(E/2)
        let factor = sqrt((1.0 + e) / (1.0 - e))
        let nuHalf = atan(factor * tan(ERad / 2.0))
        
        // Convert back to degrees and double the angle
        var nu = nuHalf * 2.0 * 180.0 / .pi
        
        // Handle quadrant correctly
        // If E is in (90, 270), ν should be in the same half-plane
        if E > 90 && E <= 270 {
            if nu < 0 { nu += 360.0 }
        } else if E > 270 {
            if nu < 0 { nu += 360.0 }
        } else if E < -90 && E >= -270 {
            if nu > 0 { nu -= 360.0 }
        }
        
        return nu
    }
    
    // MARK: - Orbital Plane Position
    
    /// Computes position in the orbital plane.
    ///
    /// Returns (x', y') where:
    /// - x' axis points from focus to perihelion
    /// - y' axis is perpendicular, in the orbital plane
    /// - z' = 0 (by definition, in the orbital plane)
    ///
    /// Formulas:
    /// ```
    /// x' = a * (cos(E) - e)
    /// y' = a * sqrt(1 - e²) * sin(E)
    /// ```
    ///
    /// - Parameters:
    ///   - semiMajorAxis: Semi-major axis a (in any unit, usually AU).
    ///   - eccentricity: Orbital eccentricity e.
    ///   - eccentricAnomaly: Eccentric anomaly E in degrees.
    /// - Returns: Tuple (x', y') in the same units as semi-major axis.
    public static func orbitalPlanePosition(
        semiMajorAxis a: Double,
        eccentricity e: Double,
        eccentricAnomaly E: Double
    ) -> (xPrime: Double, yPrime: Double) {
        let ERad = E * .pi / 180.0
        
        let xPrime = a * (cos(ERad) - e)
        let yPrime = a * sqrt(1.0 - e * e) * sin(ERad)
        
        return (xPrime, yPrime)
    }
    
    // MARK: - Velocity in Orbital Plane
    
    /// Computes velocity in the orbital plane.
    ///
    /// Returns (vx', vy') where:
    /// - vx' is velocity component along x' axis
    /// - vy' is velocity component along y' axis
    ///
    /// Derived from vis-viva equation and Kepler's laws.
    ///
    /// - Parameters:
    ///   - semiMajorAxis: Semi-major axis a in AU.
    ///   - eccentricity: Orbital eccentricity e.
    ///   - eccentricAnomaly: Eccentric anomaly E in degrees.
    ///   - gm: Gravitational parameter μ = GM in m³/s².
    /// - Returns: Tuple (vx', vy') in m/s.
    public static func orbitalPlaneVelocity(
        semiMajorAxis a: Double,
        eccentricity e: Double,
        eccentricAnomaly E: Double,
        gm: Double
    ) -> (vxPrime: Double, vyPrime: Double) {
        let ERad = E * .pi / 180.0
        let aMeters = a * Constants.au
        
        // Mean motion n = sqrt(μ/a³)
        let n = sqrt(gm / (aMeters * aMeters * aMeters))
        
        // Eccentric anomaly rate: dE/dt = n / (1 - e*cos(E))
        let dEdt = n / (1.0 - e * cos(ERad))
        
        // Position derivatives:
        // dx'/dE = -a * sin(E)
        // dy'/dE = a * sqrt(1-e²) * cos(E)
        // v = (dx'/dt, dy'/dt) = (dx'/dE, dy'/dE) * dE/dt
        
        let vxPrime = -aMeters * sin(ERad) * dEdt
        let vyPrime = aMeters * sqrt(1.0 - e * e) * cos(ERad) * dEdt
        
        return (vxPrime, vyPrime)
    }
    
    // MARK: - Full State Vector
    
    /// Computes a state vector from moon orbital elements.
    ///
    /// This method is similar to stateVector(from:gm:frame:) but handles moon elements
    /// which use different units (km for semi-major axis) and slightly different
    /// element definitions (longitudeOfPeriapsis instead of longitudeOfPerihelion).
    ///
    /// The returned state vector is relative to the moon's parent body (not heliocentric).
    ///
    /// - Parameters:
    ///   - elements: Moon orbital elements.
    ///   - gmParent: Gravitational parameter μ = GM of the parent body (m³/s²).
    ///   - epoch: The epoch for the state vector.
    ///   - orbitalPeriod: The moon's orbital period in days.
    ///   - isRetrograde: Whether the moon has a retrograde orbit.
    ///   - frame: Output reference frame. Default is ecliptic J2000.
    /// - Returns: State vector with position (m) and velocity (m/s) relative to parent.
    public static func stateVector(
        from elements: BundledEphemeris.MoonOrbitalElements,
        gmParent: Double,
        epoch: Epoch,
        orbitalPeriod: Double,
        isRetrograde: Bool = false,
        frame: ReferenceFrame = .eclipticJ2000
    ) -> StateVector {
        // For moons, we use the orbital period to compute mean motion
        // Mean motion n = 2π / T (rad/s)
        let periodSeconds = orbitalPeriod * 86400.0  // days to seconds
        let n = 2.0 * .pi / periodSeconds
        
        // Calculate days since J2000
        let daysSinceJ2000 = epoch.julianDate - Epoch.j2000.julianDate
        
        // Mean anomaly at epoch (starting from meanLongitude at J2000)
        // M = M0 + n * t
        var M = elements.meanLongitude + (n * daysSinceJ2000 * 86400.0) * 180.0 / .pi
        
        // Normalize M to [-180, 180]
        M = M.truncatingRemainder(dividingBy: 360.0)
        if M > 180.0 { M -= 360.0 }
        if M < -180.0 { M += 360.0 }
        
        // Solve Kepler's equation
        let E = solveKepler(meanAnomaly: M, eccentricity: elements.eccentricity)
        
        // Position in orbital plane (km -> meters)
        let aMeters = elements.semiMajorAxis * 1000.0
        let ERad = E * .pi / 180.0
        let xPrime = aMeters * (cos(ERad) - elements.eccentricity)
        let yPrime = aMeters * sqrt(1.0 - elements.eccentricity * elements.eccentricity) * sin(ERad)
        
        // Velocity in orbital plane
        let dEdt = n / (1.0 - elements.eccentricity * cos(ERad))
        var vxPrime = -aMeters * sin(ERad) * dEdt
        var vyPrime = aMeters * sqrt(1.0 - elements.eccentricity * elements.eccentricity) * cos(ERad) * dEdt
        
        // For retrograde orbits, reverse the velocity direction
        if isRetrograde {
            vxPrime = -vxPrime
            vyPrime = -vyPrime
        }
        
        // Argument of periapsis: ω = ϖ - Ω
        let omega = (elements.longitudeOfPeriapsis - elements.longitudeOfAscendingNode) * .pi / 180.0
        let Omega = elements.longitudeOfAscendingNode * .pi / 180.0
        let I = elements.inclination * .pi / 180.0
        
        // Rotation matrix components
        let cosOmega = cos(Omega)
        let sinOmega = sin(Omega)
        let cosI = cos(I)
        let sinI = sin(I)
        let cosomega = cos(omega)
        let sinomega = sin(omega)
        
        // First row of rotation matrix (for x)
        let m11 = cosomega * cosOmega - sinomega * sinOmega * cosI
        let m12 = -sinomega * cosOmega - cosomega * sinOmega * cosI
        
        // Second row (for y)
        let m21 = cosomega * sinOmega + sinomega * cosOmega * cosI
        let m22 = -sinomega * sinOmega + cosomega * cosOmega * cosI
        
        // Third row (for z)
        let m31 = sinomega * sinI
        let m32 = cosomega * sinI
        
        // Apply rotation to position
        let x = m11 * xPrime + m12 * yPrime
        let y = m21 * xPrime + m22 * yPrime
        let z = m31 * xPrime + m32 * yPrime
        
        // Apply rotation to velocity
        let vx = m11 * vxPrime + m12 * vyPrime
        let vy = m21 * vxPrime + m22 * vyPrime
        let vz = m31 * vxPrime + m32 * vyPrime
        
        return StateVector(
            position: SIMD3(x, y, z),
            velocity: SIMD3(vx, vy, vz),
            epoch: epoch,
            frame: frame
        )
    }
    
    /// Computes a state vector from orbital elements.
    ///
    /// This is the main entry point for converting Keplerian orbital elements
    /// to Cartesian position and velocity vectors.
    ///
    /// ## Process
    ///
    /// 1. Compute mean anomaly M from mean longitude and longitude of perihelion
    /// 2. Solve Kepler's equation for eccentric anomaly E
    /// 3. Compute position (x', y') in orbital plane
    /// 4. Compute velocity (vx', vy') in orbital plane
    /// 5. Rotate from orbital plane to ecliptic J2000 frame
    ///
    /// - Parameters:
    ///   - elements: Orbital elements at the desired epoch.
    ///   - gm: Gravitational parameter μ = GM of the central body (m³/s²).
    ///         Default is Sun's GM for heliocentric orbits.
    ///   - frame: Output reference frame. Default is ecliptic J2000.
    /// - Returns: State vector with position (m) and velocity (m/s).
    public static func stateVector(
        from elements: OrbitalElements,
        gm: Double = Constants.gmSun,
        frame: ReferenceFrame = .eclipticJ2000
    ) -> StateVector {
        // Step 1: Get mean anomaly and normalize to [-180, 180]
        let M = elements.meanAnomalyNormalized
        
        // Step 2: Solve Kepler's equation
        let E = solveKepler(meanAnomaly: M, eccentricity: elements.eccentricity)
        
        // Step 3: Position in orbital plane (AU)
        let (xPrime, yPrime) = orbitalPlanePosition(
            semiMajorAxis: elements.semiMajorAxis,
            eccentricity: elements.eccentricity,
            eccentricAnomaly: E
        )
        
        // Step 4: Velocity in orbital plane (m/s)
        let (vxPrime, vyPrime) = orbitalPlaneVelocity(
            semiMajorAxis: elements.semiMajorAxis,
            eccentricity: elements.eccentricity,
            eccentricAnomaly: E,
            gm: gm
        )
        
        // Step 5: Rotate to ecliptic frame
        // Get angles in radians
        let omega = elements.argumentOfPerihelion * .pi / 180.0  // ω
        let Omega = elements.longitudeOfAscendingNode * .pi / 180.0  // Ω
        let I = elements.inclination * .pi / 180.0  // I
        
        // Rotation matrix components (see JPL documentation)
        let cosOmega = cos(Omega)
        let sinOmega = sin(Omega)
        let cosI = cos(I)
        let sinI = sin(I)
        let cosomega = cos(omega)
        let sinomega = sin(omega)
        
        // Rotation matrix M = Rz(-Ω) * Rx(-I) * Rz(-ω)
        // Applied to r' = (x', y', 0) gives r_ecl
        
        // First row of rotation matrix (for x_ecl)
        let m11 = cosomega * cosOmega - sinomega * sinOmega * cosI
        let m12 = -sinomega * cosOmega - cosomega * sinOmega * cosI
        
        // Second row (for y_ecl)
        let m21 = cosomega * sinOmega + sinomega * cosOmega * cosI
        let m22 = -sinomega * sinOmega + cosomega * cosOmega * cosI
        
        // Third row (for z_ecl)
        let m31 = sinomega * sinI
        let m32 = cosomega * sinI
        
        // Apply rotation to position (convert AU to meters)
        let xEcl = (m11 * xPrime + m12 * yPrime) * Constants.au
        let yEcl = (m21 * xPrime + m22 * yPrime) * Constants.au
        let zEcl = (m31 * xPrime + m32 * yPrime) * Constants.au
        
        // Apply rotation to velocity (already in m/s)
        let vxEcl = m11 * vxPrime + m12 * vyPrime
        let vyEcl = m21 * vxPrime + m22 * vyPrime
        let vzEcl = m31 * vxPrime + m32 * vyPrime
        
        return StateVector(
            position: SIMD3(xEcl, yEcl, zEcl),
            velocity: SIMD3(vxEcl, vyEcl, vzEcl),
            epoch: elements.epoch,
            frame: frame
        )
    }
}
