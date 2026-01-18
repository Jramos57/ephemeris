import Foundation
import simd

/// A 3D position and velocity state vector.
///
/// State vectors represent the complete instantaneous state of an object in space,
/// consisting of position and velocity components. They are commonly used for
/// numerical orbit propagation and as output from ephemeris calculations.
///
/// ## Coordinate Systems
///
/// State vectors are always associated with a reference frame (e.g., ICRF, Ecliptic J2000)
/// and an epoch. The interpretation of the components depends on the frame:
///
/// - **Ecliptic J2000**: x toward vernal equinox, z toward ecliptic north pole
/// - **ICRF/Equatorial**: x toward vernal equinox, z toward celestial north pole
///
/// ## Units
///
/// All distances are in **meters** and velocities in **meters per second**.
/// This follows SI convention and avoids unit confusion in calculations.
///
/// ## Example
///
/// ```swift
/// // Earth's position at some epoch
/// let earth = StateVector(
///     position: SIMD3(1.0 * AU, 0, 0),     // 1 AU along x-axis
///     velocity: SIMD3(0, 29780, 0),         // ~30 km/s orbital velocity
///     epoch: .j2000,
///     frame: .eclipticJ2000
/// )
///
/// print(earth.distance)      // Distance from origin (m)
/// print(earth.speed)         // Orbital speed (m/s)
/// ```
public struct StateVector: Codable, Sendable, Hashable {
    
    // MARK: - Properties
    
    /// Position vector in meters.
    ///
    /// Components are (x, y, z) in the specified reference frame.
    public let position: SIMD3<Double>
    
    /// Velocity vector in meters per second.
    ///
    /// Components are (vx, vy, vz) in the specified reference frame.
    public let velocity: SIMD3<Double>
    
    /// The epoch at which this state is valid.
    public let epoch: Epoch
    
    /// The coordinate reference frame.
    public let frame: ReferenceFrame
    
    // MARK: - Initialization
    
    /// Creates a state vector with the given position and velocity.
    ///
    /// - Parameters:
    ///   - position: Position vector in meters.
    ///   - velocity: Velocity vector in meters per second.
    ///   - epoch: The time at which this state is valid.
    ///   - frame: The reference frame for the coordinates.
    public init(
        position: SIMD3<Double>,
        velocity: SIMD3<Double>,
        epoch: Epoch,
        frame: ReferenceFrame
    ) {
        self.position = position
        self.velocity = velocity
        self.epoch = epoch
        self.frame = frame
    }
    
    /// Creates a state vector from component arrays.
    ///
    /// - Parameters:
    ///   - x, y, z: Position components in meters.
    ///   - vx, vy, vz: Velocity components in meters per second.
    ///   - epoch: The time at which this state is valid.
    ///   - frame: The reference frame for the coordinates.
    public init(
        x: Double, y: Double, z: Double,
        vx: Double, vy: Double, vz: Double,
        epoch: Epoch,
        frame: ReferenceFrame
    ) {
        self.position = SIMD3(x, y, z)
        self.velocity = SIMD3(vx, vy, vz)
        self.epoch = epoch
        self.frame = frame
    }
    
    // MARK: - Computed Properties
    
    /// Distance from the origin in meters.
    public var distance: Double {
        simd_length(position)
    }
    
    /// Distance from the origin in kilometers.
    public var distanceKm: Double {
        distance / 1000.0
    }
    
    /// Distance from the origin in astronomical units.
    public var distanceAU: Double {
        distance / Constants.au
    }
    
    /// Speed (magnitude of velocity) in meters per second.
    public var speed: Double {
        simd_length(velocity)
    }
    
    /// Speed in kilometers per second.
    public var speedKmPerSec: Double {
        speed / 1000.0
    }
    
    /// Unit vector pointing from origin to position.
    public var positionDirection: SIMD3<Double> {
        simd_normalize(position)
    }
    
    /// Unit vector in the direction of motion.
    public var velocityDirection: SIMD3<Double> {
        simd_normalize(velocity)
    }
    
    /// Specific angular momentum vector (h = r × v).
    ///
    /// The angular momentum per unit mass, perpendicular to the orbital plane.
    public var specificAngularMomentum: SIMD3<Double> {
        simd_cross(position, velocity)
    }
    
    /// Magnitude of specific angular momentum (m²/s).
    public var specificAngularMomentumMagnitude: Double {
        simd_length(specificAngularMomentum)
    }
    
    /// Radial velocity component (m/s).
    ///
    /// Positive when moving away from the origin.
    public var radialVelocity: Double {
        simd_dot(positionDirection, velocity)
    }
    
    /// Transverse (tangential) velocity component (m/s).
    ///
    /// Velocity component perpendicular to the radial direction.
    public var transverseVelocity: Double {
        let vRadial = radialVelocity * positionDirection
        let vTransverse = velocity - vRadial
        return simd_length(vTransverse)
    }
    
    // MARK: - Position Components (for convenience)
    
    /// X position component in meters.
    public var x: Double { position.x }
    
    /// Y position component in meters.
    public var y: Double { position.y }
    
    /// Z position component in meters.
    public var z: Double { position.z }
    
    /// X velocity component in m/s.
    public var vx: Double { velocity.x }
    
    /// Y velocity component in m/s.
    public var vy: Double { velocity.y }
    
    /// Z velocity component in m/s.
    public var vz: Double { velocity.z }
}

// MARK: - CustomStringConvertible

extension StateVector: CustomStringConvertible {
    public var description: String {
        """
        StateVector(epoch: \(epoch.julianDate), frame: \(frame.rawValue))
          r = [\(String(format: "%.3e", x)), \(String(format: "%.3e", y)), \(String(format: "%.3e", z))] m
          v = [\(String(format: "%.3f", vx)), \(String(format: "%.3f", vy)), \(String(format: "%.3f", vz))] m/s
          |r| = \(String(format: "%.6f", distanceAU)) AU
          |v| = \(String(format: "%.3f", speedKmPerSec)) km/s
        """
    }
}


