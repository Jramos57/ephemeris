import Foundation
import simd

/// The main interface for computing planetary positions.
///
/// `Ephemeris` provides high-level access to solar system body positions at any point in time.
/// It combines bundled orbital elements with Keplerian propagation to compute state vectors.
///
/// ## Features
///
/// - Compute positions of planets, dwarf planets at any epoch
/// - Uses JPL orbital elements (valid 1800-2050 AD)
/// - Supports propagation up to ~200 years from J2000
/// - Thread-safe (actor-based design)
///
/// ## Usage
///
/// ```swift
/// // Create an ephemeris instance
/// let ephemeris = try await Ephemeris()
///
/// // Get Earth's position at J2000
/// let earthState = try await ephemeris.state(of: .earth, at: .j2000)
/// print("Earth distance: \(earthState.distanceAU) AU")
///
/// // Get Mars position at a specific date
/// let epoch = Epoch(year: 2025, month: 6, day: 15)
/// let marsState = try await ephemeris.state(of: .mars, at: epoch)
/// ```
///
/// ## Accuracy
///
/// Using JPL approximate positions:
/// - Inner planets: ~20 arcseconds in longitude
/// - Outer planets: ~600 arcseconds in longitude
/// - Sufficient for visualization, game mechanics, mission planning sketches
///
/// For higher accuracy, consider using JPL Horizons API (coming soon).
public actor Ephemeris {
    
    // MARK: - Properties
    
    /// Bundled ephemeris data.
    private let bundledData: BundledEphemeris
    
    /// Output coordinate frame.
    public let outputFrame: ReferenceFrame
    
    // MARK: - Initialization
    
    /// Creates an ephemeris instance with bundled data.
    ///
    /// - Parameter outputFrame: The coordinate frame for output state vectors.
    ///                          Default is ecliptic J2000.
    /// - Throws: If bundled data cannot be loaded.
    public init(outputFrame: ReferenceFrame = .eclipticJ2000) throws {
        self.bundledData = try BundledEphemeris.load()
        self.outputFrame = outputFrame
    }
    
    /// Creates an ephemeris instance with custom data.
    ///
    /// Useful for testing or using refreshed data from Horizons.
    ///
    /// - Parameters:
    ///   - data: Custom ephemeris data.
    ///   - outputFrame: The coordinate frame for output state vectors.
    public init(data: BundledEphemeris, outputFrame: ReferenceFrame = .eclipticJ2000) {
        self.bundledData = data
        self.outputFrame = outputFrame
    }
    
    // MARK: - Position Queries
    
    /// Computes the heliocentric state vector of a body at a given epoch.
    ///
    /// The returned state vector gives the position and velocity of the body
    /// relative to the Sun (heliocentric coordinates).
    ///
    /// - Parameters:
    ///   - body: The celestial body.
    ///   - epoch: The time at which to compute the position.
    /// - Returns: Heliocentric state vector in the configured output frame.
    /// - Throws: If the body is not available or epoch is invalid.
    public func state(of body: CelestialBody, at epoch: Epoch) throws -> StateVector {
        // Get elements at the target epoch
        guard let elements = bundledData.elements(for: body, at: epoch) else {
            throw EphemerisError.bodyNotFound(body)
        }
        
        // Compute state vector using Kepler solver
        var state = KeplerSolver.stateVector(
            from: elements,
            gm: bundledData.gmSun,
            frame: .eclipticJ2000
        )
        
        // Transform to output frame if needed
        if outputFrame != .eclipticJ2000 {
            state = CoordinateTransform.transform(state, to: outputFrame)
        }
        
        return state
    }
    
    /// Computes the heliocentric position of a body at a given epoch.
    ///
    /// Convenience method that returns just the position vector.
    ///
    /// - Parameters:
    ///   - body: The celestial body.
    ///   - epoch: The time at which to compute the position.
    /// - Returns: Position vector in meters.
    public func position(of body: CelestialBody, at epoch: Epoch) throws -> SIMD3<Double> {
        try state(of: body, at: epoch).position
    }
    
    /// Computes the distance of a body from the Sun at a given epoch.
    ///
    /// - Parameters:
    ///   - body: The celestial body.
    ///   - epoch: The time at which to compute the distance.
    /// - Returns: Distance in astronomical units.
    public func distance(of body: CelestialBody, at epoch: Epoch) throws -> Double {
        try state(of: body, at: epoch).distanceAU
    }
    
    // MARK: - Multi-Body Queries
    
    /// Computes state vectors for multiple bodies at a given epoch.
    ///
    /// More efficient than calling `state(of:at:)` multiple times when you need
    /// positions of several bodies at the same time.
    ///
    /// - Parameters:
    ///   - bodies: The celestial bodies to compute.
    ///   - epoch: The time at which to compute positions.
    /// - Returns: Dictionary mapping bodies to their state vectors.
    public func states(of bodies: [CelestialBody], at epoch: Epoch) throws -> [CelestialBody: StateVector] {
        var results: [CelestialBody: StateVector] = [:]
        
        for body in bodies {
            results[body] = try state(of: body, at: epoch)
        }
        
        return results
    }
    
    /// Computes state vectors for all available planets at a given epoch.
    ///
    /// - Parameter epoch: The time at which to compute positions.
    /// - Returns: Dictionary mapping planets to their state vectors.
    public func allPlanetStates(at epoch: Epoch) throws -> [CelestialBody: StateVector] {
        try states(of: CelestialBody.planets, at: epoch)
    }
    
    // MARK: - Relative Positions
    
    /// Computes the position of one body relative to another.
    ///
    /// For example, to get Earth's position as seen from Mars:
    /// ```swift
    /// let earthFromMars = try ephemeris.relativePosition(of: .earth, from: .mars, at: epoch)
    /// ```
    ///
    /// - Parameters:
    ///   - target: The target body.
    ///   - observer: The observer body.
    ///   - epoch: The time at which to compute the relative position.
    /// - Returns: Position of target relative to observer (target - observer).
    public func relativePosition(
        of target: CelestialBody,
        from observer: CelestialBody,
        at epoch: Epoch
    ) throws -> SIMD3<Double> {
        let targetState = try state(of: target, at: epoch)
        let observerState = try state(of: observer, at: epoch)
        return targetState.position - observerState.position
    }
    
    /// Computes the distance between two bodies.
    ///
    /// - Parameters:
    ///   - body1: First body.
    ///   - body2: Second body.
    ///   - epoch: The time at which to compute the distance.
    /// - Returns: Distance in meters.
    public func distance(between body1: CelestialBody, and body2: CelestialBody, at epoch: Epoch) throws -> Double {
        let relative = try relativePosition(of: body1, from: body2, at: epoch)
        return simd_length(relative)
    }
    
    /// Computes the distance between two bodies in AU.
    ///
    /// - Parameters:
    ///   - body1: First body.
    ///   - body2: Second body.
    ///   - epoch: The time at which to compute the distance.
    /// - Returns: Distance in astronomical units.
    public func distanceAU(between body1: CelestialBody, and body2: CelestialBody, at epoch: Epoch) throws -> Double {
        try distance(between: body1, and: body2, at: epoch) / Constants.au
    }
    
    // MARK: - Orbital Elements Access
    
    /// Gets the orbital elements for a body at a given epoch.
    ///
    /// - Parameters:
    ///   - body: The celestial body.
    ///   - epoch: The target epoch. Default is J2000.
    /// - Returns: Orbital elements at the target epoch.
    public func orbitalElements(for body: CelestialBody, at epoch: Epoch = .j2000) throws -> OrbitalElements {
        guard let elements = bundledData.elements(for: body, at: epoch) else {
            throw EphemerisError.bodyNotFound(body)
        }
        return elements
    }
    
    // MARK: - Data Info
    
    /// List of all bodies available in this ephemeris.
    public var availableBodies: [CelestialBody] {
        bundledData.availableBodies
    }
    
    /// Metadata about the ephemeris data source.
    public var dataSource: String {
        bundledData.metadata.source
    }
    
    /// Valid time range description.
    public var validRange: String {
        bundledData.metadata.validRange
    }
}
