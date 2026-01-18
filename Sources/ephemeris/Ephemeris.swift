import Foundation
import simd

/// The main interface for computing planetary and moon positions.
///
/// `Ephemeris` provides high-level access to solar system body positions at any point in time.
/// It combines bundled orbital elements with Keplerian propagation to compute state vectors.
///
/// ## Features
///
/// - Compute positions of planets, dwarf planets, and moons at any epoch
/// - Hierarchical moon positions (moons orbit parents, computed relative to parent then transformed to heliocentric)
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
/// // Get Earth's position at J2000 (heliocentric)
/// let earthState = try await ephemeris.state(of: .earth, at: .j2000)
/// print("Earth distance: \(earthState.distanceAU) AU")
///
/// // Get Moon's position (heliocentric - computed via Earth)
/// let moonState = try await ephemeris.state(of: .moon, at: .j2000)
///
/// // Get Moon's position relative to Earth
/// let moonRelative = try await ephemeris.state(of: .moon, at: .j2000, relativeTo: .earth)
/// ```
///
/// ## Accuracy
///
/// Using JPL approximate positions:
/// - Inner planets: ~20 arcseconds in longitude
/// - Outer planets: ~600 arcseconds in longitude
/// - Moons: Variable, sufficient for game purposes
///
/// For higher accuracy, consider using JPL Horizons API.
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
    /// For planets and asteroids, this computes the position directly from orbital elements.
    /// For moons, this first computes the parent body's position, then adds the moon's
    /// position relative to its parent.
    ///
    /// - Parameters:
    ///   - body: The celestial body.
    ///   - epoch: The time at which to compute the position.
    /// - Returns: Heliocentric state vector in the configured output frame.
    /// - Throws: If the body is not available or epoch is invalid.
    public func state(of body: CelestialBody, at epoch: Epoch) throws -> StateVector {
        // Check if this is a moon
        if body.isMoon {
            return try moonHeliocentricState(of: body, at: epoch)
        }
        
        // Planet or asteroid - compute directly
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
    
    /// Computes the state vector of a body relative to another body.
    ///
    /// For moons, passing their parent as the reference body returns the moon's
    /// orbital position around the parent.
    ///
    /// - Parameters:
    ///   - body: The celestial body.
    ///   - epoch: The time at which to compute the position.
    ///   - reference: The reference body (position is computed relative to this).
    /// - Returns: State vector relative to the reference body.
    /// - Throws: If either body is not available.
    public func state(of body: CelestialBody, at epoch: Epoch, relativeTo reference: CelestialBody) throws -> StateVector {
        // Special case: moon relative to its parent
        if body.isMoon, body.parent == reference {
            return try moonRelativeState(of: body, at: epoch)
        }
        
        // General case: compute both heliocentric positions and subtract
        let bodyState = try state(of: body, at: epoch)
        let refState = try state(of: reference, at: epoch)
        
        return StateVector(
            position: bodyState.position - refState.position,
            velocity: bodyState.velocity - refState.velocity,
            epoch: epoch,
            frame: outputFrame
        )
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
    
    // MARK: - Moon-Specific Queries
    
    /// Computes the heliocentric state of a moon.
    ///
    /// This computes the parent's heliocentric position, then adds the moon's
    /// position relative to the parent.
    private func moonHeliocentricState(of moon: CelestialBody, at epoch: Epoch) throws -> StateVector {
        guard let parent = moon.parent else {
            throw EphemerisError.parentNotFound(moon)
        }
        
        // Get parent's heliocentric state
        let parentState = try state(of: parent, at: epoch)
        
        // Get moon's state relative to parent
        let moonRelative = try moonRelativeState(of: moon, at: epoch)
        
        // Combine: moon_heliocentric = parent_heliocentric + moon_relative
        var heliocentricState = StateVector(
            position: parentState.position + moonRelative.position,
            velocity: parentState.velocity + moonRelative.velocity,
            epoch: epoch,
            frame: .eclipticJ2000
        )
        
        // Transform to output frame if needed
        if outputFrame != .eclipticJ2000 {
            heliocentricState = CoordinateTransform.transform(heliocentricState, to: outputFrame)
        }
        
        return heliocentricState
    }
    
    /// Computes the state of a moon relative to its parent body.
    private func moonRelativeState(of moon: CelestialBody, at epoch: Epoch) throws -> StateVector {
        guard let moonData = bundledData.moonData(for: moon) else {
            throw EphemerisError.moonNotFound(moon)
        }
        
        guard let parentGM = bundledData.gm(for: moonData.parent) else {
            throw EphemerisError.parentNotFound(moon)
        }
        
        return KeplerSolver.stateVector(
            from: moonData.elements,
            gmParent: parentGM,
            epoch: epoch,
            orbitalPeriod: moonData.orbitalPeriod,
            isRetrograde: moonData.isRetrograde,
            frame: .eclipticJ2000
        )
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
    
    /// List of all planetary bodies available in this ephemeris.
    public var availableBodies: [CelestialBody] {
        bundledData.availableBodies
    }
    
    /// List of all moons available in this ephemeris.
    public var availableMoons: [CelestialBody] {
        bundledData.availableMoons
    }
    
    /// All available bodies (planets + moons).
    public var allBodies: [CelestialBody] {
        bundledData.availableBodies + bundledData.availableMoons
    }
    
    /// Gets all moons of a specific parent body.
    ///
    /// - Parameter parent: The parent body.
    /// - Returns: Array of moons orbiting the parent.
    public func moons(of parent: CelestialBody) -> [CelestialBody] {
        bundledData.moons(of: parent)
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
