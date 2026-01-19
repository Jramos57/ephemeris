import Foundation
import simd

/// Coordinate frame transformations for astronomical calculations.
///
/// This module provides transformations between different coordinate reference frames
/// commonly used in astronomy and astrodynamics:
///
/// - **Ecliptic J2000**: The plane of Earth's orbit at J2000.0. Most planetary orbital
///   elements are given in this frame.
///
/// - **Equatorial J2000 (ICRF)**: Earth's equator at J2000.0. Right ascension and
///   declination are measured in this frame.
///
/// ## The Obliquity
///
/// The angle between the ecliptic and equatorial planes is called the obliquity (ε).
/// At J2000.0, ε ≈ 23.439°. This is the key parameter for ecliptic-equatorial transforms.
///
/// ## Rotation Matrices
///
/// Transformations are implemented using rotation matrices:
/// - Rx(θ): Rotation about x-axis
/// - Ry(θ): Rotation about y-axis
/// - Rz(θ): Rotation about z-axis
///
/// ## Example
///
/// ```swift
/// // Convert ecliptic position to equatorial
/// let eclipticPos = SIMD3<Double>(1.0, 0.5, 0.1)  // AU
/// let equatorialPos = CoordinateTransform.eclipticToEquatorial(eclipticPos)
///
/// // Transform a full state vector
/// let eclipticState = StateVector(...)
/// let equatorialState = CoordinateTransform.transform(eclipticState, to: .equatorialJ2000)
/// ```
public enum CoordinateTransform {
    
    // MARK: - Ecliptic-Equatorial Transforms
    
    /// Transforms a vector from ecliptic J2000 to equatorial J2000 coordinates.
    ///
    /// The transformation is a rotation about the x-axis (vernal equinox direction)
    /// by the obliquity angle ε:
    ///
    /// ```
    /// [x_eq]   [1    0       0    ] [x_ecl]
    /// [y_eq] = [0  cos(ε) -sin(ε)] [y_ecl]
    /// [z_eq]   [0  sin(ε)  cos(ε)] [z_ecl]
    /// ```
    ///
    /// - Parameter ecliptic: Position vector in ecliptic J2000 frame.
    /// - Returns: Position vector in equatorial J2000 frame.
    public static func eclipticToEquatorial(_ ecliptic: SIMD3<Double>) -> SIMD3<Double> {
        let eps = Constants.obliquityJ2000Radians
        let cosEps = cos(eps)
        let sinEps = sin(eps)
        
        return SIMD3(
            ecliptic.x,
            cosEps * ecliptic.y - sinEps * ecliptic.z,
            sinEps * ecliptic.y + cosEps * ecliptic.z
        )
    }
    
    /// Transforms a vector from equatorial J2000 to ecliptic J2000 coordinates.
    ///
    /// This is the inverse of `eclipticToEquatorial`, using rotation by -ε:
    ///
    /// ```
    /// [x_ecl]   [1    0        0   ] [x_eq]
    /// [y_ecl] = [0  cos(ε)  sin(ε)] [y_eq]
    /// [z_ecl]   [0 -sin(ε)  cos(ε)] [z_eq]
    /// ```
    ///
    /// - Parameter equatorial: Position vector in equatorial J2000 frame.
    /// - Returns: Position vector in ecliptic J2000 frame.
    public static func equatorialToEcliptic(_ equatorial: SIMD3<Double>) -> SIMD3<Double> {
        let eps = Constants.obliquityJ2000Radians
        let cosEps = cos(eps)
        let sinEps = sin(eps)
        
        return SIMD3(
            equatorial.x,
            cosEps * equatorial.y + sinEps * equatorial.z,
            -sinEps * equatorial.y + cosEps * equatorial.z
        )
    }
    
    // MARK: - StateVector Transforms
    
    /// Transforms a state vector to a different reference frame.
    ///
    /// Currently supports:
    /// - Ecliptic J2000 ↔ Equatorial J2000
    ///
    /// - Parameters:
    ///   - state: The state vector to transform.
    ///   - targetFrame: The desired output reference frame.
    /// - Returns: State vector in the target frame.
    public static func transform(
        _ state: StateVector,
        to targetFrame: ReferenceFrame
    ) -> StateVector {
        // If already in target frame, return as-is
        guard state.frame != targetFrame else { return state }
        
        let newPosition: SIMD3<Double>
        let newVelocity: SIMD3<Double>
        
        switch (state.frame, targetFrame) {
        case (.eclipticJ2000, .equatorialJ2000), (.eclipticJ2000, .icrf):
            newPosition = eclipticToEquatorial(state.position)
            newVelocity = eclipticToEquatorial(state.velocity)
            
        case (.equatorialJ2000, .eclipticJ2000), (.icrf, .eclipticJ2000):
            newPosition = equatorialToEcliptic(state.position)
            newVelocity = equatorialToEcliptic(state.velocity)
            
        case (.icrf, .equatorialJ2000), (.equatorialJ2000, .icrf):
            // ICRF and J2000 equatorial are nearly identical for our purposes
            newPosition = state.position
            newVelocity = state.velocity
            
        default:
            // For unsupported transforms, return unchanged with warning
            // In a production system, this should throw an error
            newPosition = state.position
            newVelocity = state.velocity
        }
        
        return StateVector(
            position: newPosition,
            velocity: newVelocity,
            epoch: state.epoch,
            frame: targetFrame
        )
    }
    
    // MARK: - Rotation Matrices
    
    /// Creates a rotation matrix for rotation about the x-axis.
    ///
    /// ```
    /// Rx(θ) = [1    0       0   ]
    ///         [0  cos(θ) -sin(θ)]
    ///         [0  sin(θ)  cos(θ)]
    /// ```
    ///
    /// - Parameter angle: Rotation angle in radians.
    /// - Returns: 3x3 rotation matrix.
    public static func rotationMatrixX(angle: Double) -> simd_double3x3 {
        let c = cos(angle)
        let s = sin(angle)
        return simd_double3x3(
            SIMD3(1, 0, 0),
            SIMD3(0, c, s),
            SIMD3(0, -s, c)
        )
    }
    
    /// Creates a rotation matrix for rotation about the y-axis.
    ///
    /// ```
    /// Ry(θ) = [ cos(θ)  0  sin(θ)]
    ///         [   0     1    0   ]
    ///         [-sin(θ)  0  cos(θ)]
    /// ```
    ///
    /// - Parameter angle: Rotation angle in radians.
    /// - Returns: 3x3 rotation matrix.
    public static func rotationMatrixY(angle: Double) -> simd_double3x3 {
        let c = cos(angle)
        let s = sin(angle)
        return simd_double3x3(
            SIMD3(c, 0, -s),
            SIMD3(0, 1, 0),
            SIMD3(s, 0, c)
        )
    }
    
    /// Creates a rotation matrix for rotation about the z-axis.
    ///
    /// ```
    /// Rz(θ) = [cos(θ) -sin(θ)  0]
    ///         [sin(θ)  cos(θ)  0]
    ///         [  0       0     1]
    /// ```
    ///
    /// - Parameter angle: Rotation angle in radians.
    /// - Returns: 3x3 rotation matrix.
    public static func rotationMatrixZ(angle: Double) -> simd_double3x3 {
        let c = cos(angle)
        let s = sin(angle)
        return simd_double3x3(
            SIMD3(c, s, 0),
            SIMD3(-s, c, 0),
            SIMD3(0, 0, 1)
        )
    }
    
    // MARK: - Spherical Coordinates
    
    /// Converts Cartesian coordinates to spherical coordinates.
    ///
    /// - Parameter cartesian: Position vector (x, y, z).
    /// - Returns: Tuple (r, longitude, latitude) where:
    ///   - r: Distance from origin (same units as input)
    ///   - longitude: Angle in x-y plane from x-axis (degrees, 0-360)
    ///   - latitude: Angle from x-y plane (degrees, -90 to +90)
    public static func cartesianToSpherical(
        _ cartesian: SIMD3<Double>
    ) -> (r: Double, longitude: Double, latitude: Double) {
        let r = simd_length(cartesian)
        
        guard r > 0 else {
            return (0, 0, 0)
        }
        
        // Latitude: angle from x-y plane
        let lat = asin(cartesian.z / r) * Constants.radiansToDegrees
        
        // Longitude: angle in x-y plane from x-axis
        var lon = atan2(cartesian.y, cartesian.x) * Constants.radiansToDegrees
        if lon < 0 { lon += 360.0 }
        
        return (r, lon, lat)
    }
    
    /// Converts spherical coordinates to Cartesian coordinates.
    ///
    /// - Parameters:
    ///   - r: Distance from origin.
    ///   - longitude: Angle in x-y plane from x-axis (degrees).
    ///   - latitude: Angle from x-y plane (degrees).
    /// - Returns: Position vector (x, y, z).
    public static func sphericalToCartesian(
        r: Double,
        longitude: Double,
        latitude: Double
    ) -> SIMD3<Double> {
        let lonRad = longitude * Constants.degreesToRadians
        let latRad = latitude * Constants.degreesToRadians
        
        let cosLat = cos(latRad)
        
        return SIMD3(
            r * cosLat * cos(lonRad),
            r * cosLat * sin(lonRad),
            r * sin(latRad)
        )
    }
    
    // MARK: - Right Ascension / Declination
    
    /// Converts equatorial Cartesian coordinates to RA/Dec.
    ///
    /// - Parameter equatorial: Position in equatorial frame.
    /// - Returns: Tuple (ra, dec, distance) where:
    ///   - ra: Right ascension in degrees (0-360)
    ///   - dec: Declination in degrees (-90 to +90)
    ///   - distance: Distance from origin
    public static func cartesianToRADec(
        _ equatorial: SIMD3<Double>
    ) -> (ra: Double, dec: Double, distance: Double) {
        let (r, lon, lat) = cartesianToSpherical(equatorial)
        return (lon, lat, r)
    }
    
    /// Converts RA/Dec to equatorial Cartesian coordinates.
    ///
    /// - Parameters:
    ///   - ra: Right ascension in degrees.
    ///   - dec: Declination in degrees.
    ///   - distance: Distance from origin.
    /// - Returns: Position in equatorial frame.
    public static func raDecToCartesian(
        ra: Double,
        dec: Double,
        distance: Double
    ) -> SIMD3<Double> {
        sphericalToCartesian(r: distance, longitude: ra, latitude: dec)
    }
    // MARK: - Precession (J2000 -> JNow)
    
    /// Converts a position vector from J2000 frame to the Mean Equator and Equinox of Date (JNow).
    ///
    /// This method applies a precession matrix to account for the Earth's axial precession
    /// (the slow wobble of Earth's rotational axis) since the J2000.0 epoch.
    ///
    /// The algorithm uses a standard low-precision model (suitable for < 1 arcminute accuracy)
    /// often cited in astronomical almanacs. It is sufficient for visual observation,
    /// telescope pointing (non-professional), and planetarium applications.
    ///
    /// - Parameters:
    ///   - vector: Position vector in J2000 equatorial coordinates.
    ///   - epoch: The date for which to calculate the precession.
    /// - Returns: Position vector in the JNow frame.
    public static func convertJ2000ToJNow(_ vector: SIMD3<Double>, at epoch: Epoch) -> SIMD3<Double> {
        // T is the number of Julian centuries since J2000.0
        let T = (epoch.julianDate - Epoch.j2000.julianDate) / 36525.0
        
        // Precession angles (in degrees)
        // From "Astronomical Algorithms" by Jean Meeus (Formula 22.2 / IAU 1976)
        // zeta = 2306.2181" * T + 0.30188" * T^2 + 0.017998" * T^3
        // z    = 2306.2181" * T + 1.09468" * T^2 + 0.018203" * T^3
        // theta= 2004.3109" * T - 0.42665" * T^2 - 0.041833" * T^3
        
        // Convert arcseconds to degrees (1 degree = 3600 arcseconds)
        let arcsecToDeg = 1.0 / 3600.0
        
        let zeta = (2306.2181 * T + 0.30188 * T * T + 0.017998 * T * T * T) * arcsecToDeg
        let z = (2306.2181 * T + 1.09468 * T * T + 0.018203 * T * T * T) * arcsecToDeg
        let theta = (2004.3109 * T - 0.42665 * T * T - 0.041833 * T * T * T) * arcsecToDeg
        
        // Convert to radians
        let zetaRad = zeta * Constants.degreesToRadians
        let zRad = z * Constants.degreesToRadians
        let thetaRad = theta * Constants.degreesToRadians
        
        // Precession Matrix P = Rz(-z) * Ry(theta) * Rz(-zeta)
        //
        // Rz(-A) means rotation about Z by -A
        // Ry(B)  means rotation about Y by B
        
        let cosZeta = cos(zetaRad)
        let sinZeta = sin(zetaRad)
        
        let cosZ = cos(zRad)
        let sinZ = sin(zRad)
        
        let cosTheta = cos(thetaRad)
        let sinTheta = sin(thetaRad)
        
        // Elements of the rotation matrix
        // Row 1
        let P11 = cosZeta * cosTheta * cosZ - sinZeta * sinZ
        let P12 = -sinZeta * cosTheta * cosZ - cosZeta * sinZ
        let P13 = -sinTheta * cosZ
        
        // Row 2
        let P21 = cosZeta * cosTheta * sinZ + sinZeta * cosZ
        let P22 = -sinZeta * cosTheta * sinZ + cosZeta * cosZ
        let P23 = -sinTheta * sinZ
        
        // Row 3
        let P31 = cosZeta * sinTheta
        let P32 = -sinZeta * sinTheta
        let P33 = cosTheta
        
        // Apply rotation
        let x = P11 * vector.x + P12 * vector.y + P13 * vector.z
        let y = P21 * vector.x + P22 * vector.y + P23 * vector.z
        let zPos = P31 * vector.x + P32 * vector.y + P33 * vector.z
        
        return SIMD3(x, y, zPos)
    }
}


