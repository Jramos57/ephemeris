import Foundation

/// Loads and provides access to bundled solar system ephemeris data.
///
/// This data source provides orbital elements for all major planets plus Ceres and Pluto,
/// as well as major moons (relative to their parent bodies), bundled within the package
/// for offline use.
///
/// ## Data Source
///
/// The bundled data comes from JPL's "Approximate Positions of the Planets" document:
/// https://ssd.jpl.nasa.gov/planets/approx_pos.html
///
/// It's valid for the time range 1800 AD - 2050 AD with the following approximate accuracy:
/// - Inner planets: ~20 arcsec in longitude
/// - Outer planets: ~600 arcsec in longitude
///
/// ## Usage
///
/// ```swift
/// let bundled = try BundledEphemeris.load()
/// let earthElements = bundled.elements(for: .earth)
/// let moonElements = bundled.moonElements(for: .moon) // relative to Earth
/// let marsElements = bundled.elements(for: .mars, at: someEpoch)
/// ```
public struct BundledEphemeris: Sendable {
    
    /// All loaded planetary body data (heliocentric).
    public let bodies: [CelestialBody: BodyData]
    
    /// All loaded moon data (relative to parent body).
    public let moons: [CelestialBody: MoonData]
    
    /// Sun's physical parameters.
    public let sunData: PhysicalParameters
    
    /// Metadata about the data source.
    public let metadata: Metadata
    
    // MARK: - Nested Types
    
    /// Metadata about the ephemeris data.
    public struct Metadata: Codable, Sendable {
        public let source: String
        public let url: String
        public let validRange: String
        public let referenceFrame: String
        public let epoch: String
    }
    
    /// Complete data for a celestial body (planet/asteroid).
    public struct BodyData: Sendable {
        public let name: String
        public let naifId: Int
        public let elements: OrbitalElements
        public let physicalParameters: PhysicalParameters
    }
    
    /// Complete data for a moon (orbits a parent body).
    public struct MoonData: Sendable {
        public let name: String
        public let naifId: Int
        public let parent: CelestialBody
        public let elements: MoonOrbitalElements
        public let orbitalPeriod: Double  // days
        public let isRetrograde: Bool
        public let physicalParameters: PhysicalParameters
    }
    
    /// Orbital elements for a moon (relative to parent body).
    ///
    /// Unlike planetary elements (which use AU), moon elements use km for
    /// semi-major axis since moons orbit much closer to their parent.
    public struct MoonOrbitalElements: Sendable {
        /// Semi-major axis in km.
        public let semiMajorAxis: Double
        /// Eccentricity (dimensionless).
        public let eccentricity: Double
        /// Inclination in degrees (relative to parent's equatorial plane or ecliptic).
        public let inclination: Double
        /// Mean longitude at epoch in degrees.
        public let meanLongitude: Double
        /// Longitude of periapsis in degrees.
        public let longitudeOfPeriapsis: Double
        /// Longitude of ascending node in degrees.
        public let longitudeOfAscendingNode: Double
        
        /// Semi-major axis in meters.
        public var semiMajorAxisMeters: Double {
            semiMajorAxis * 1000.0
        }
    }
    
    /// Physical parameters for a body.
    public struct PhysicalParameters: Codable, Sendable {
        /// Mass in kg.
        public let mass: Double
        /// Gravitational parameter GM in m³/s².
        public let gm: Double
        /// Mean radius in km.
        public let meanRadius: Double
    }
    
    // MARK: - Loading
    
    /// Loads the bundled ephemeris data.
    ///
    /// - Throws: If the bundled data cannot be found or parsed.
    /// - Returns: The loaded ephemeris data.
    public static func load() throws -> BundledEphemeris {
        guard let url = Bundle.module.url(forResource: "solar_system_elements", withExtension: "json") else {
            throw EphemerisError.bundledDataNotFound
        }
        
        let data = try Data(contentsOf: url)
        return try parse(data)
    }
    
    /// Parses ephemeris data from JSON.
    ///
    /// - Parameter data: JSON data to parse.
    /// - Returns: Parsed ephemeris data.
    public static func parse(_ data: Data) throws -> BundledEphemeris {
        let decoder = JSONDecoder()
        let raw = try decoder.decode(RawEphemerisData.self, from: data)
        
        // Parse planetary bodies
        var bodies: [CelestialBody: BodyData] = [:]
        
        for (key, bodyData) in raw.bodies {
            guard let body = CelestialBody(rawValue: key) else { continue }
            
            let rates: OrbitalElementRates?
            if let r = bodyData.rates {
                rates = OrbitalElementRates(
                    semiMajorAxisRate: r.semiMajorAxisRate,
                    eccentricityRate: r.eccentricityRate,
                    inclinationRate: r.inclinationRate,
                    meanLongitudeRate: r.meanLongitudeRate,
                    longitudeOfPerihelionRate: r.longitudeOfPerihelionRate,
                    longitudeOfAscendingNodeRate: r.longitudeOfAscendingNodeRate
                )
            } else {
                rates = nil
            }
            
            let elements = OrbitalElements(
                semiMajorAxis: bodyData.elements.semiMajorAxis,
                eccentricity: bodyData.elements.eccentricity,
                inclination: bodyData.elements.inclination,
                meanLongitude: bodyData.elements.meanLongitude,
                longitudeOfPerihelion: bodyData.elements.longitudeOfPerihelion,
                longitudeOfAscendingNode: bodyData.elements.longitudeOfAscendingNode,
                epoch: .j2000,
                rates: rates
            )
            
            bodies[body] = BodyData(
                name: bodyData.name,
                naifId: bodyData.naifId,
                elements: elements,
                physicalParameters: bodyData.physicalParameters
            )
        }
        
        // Parse moons
        var moons: [CelestialBody: MoonData] = [:]
        
        if let rawMoons = raw.moons {
            for (key, moonData) in rawMoons {
                guard let moon = CelestialBody(rawValue: key),
                      let parent = CelestialBody(rawValue: moonData.parent) else { continue }
                
                let elements = MoonOrbitalElements(
                    semiMajorAxis: moonData.elements.semiMajorAxis,
                    eccentricity: moonData.elements.eccentricity,
                    inclination: moonData.elements.inclination,
                    meanLongitude: moonData.elements.meanLongitude,
                    longitudeOfPeriapsis: moonData.elements.longitudeOfPeriapsis,
                    longitudeOfAscendingNode: moonData.elements.longitudeOfAscendingNode
                )
                
                moons[moon] = MoonData(
                    name: moonData.name,
                    naifId: moonData.naifId,
                    parent: parent,
                    elements: elements,
                    orbitalPeriod: moonData.orbitalPeriod,
                    isRetrograde: moonData.retrograde ?? false,
                    physicalParameters: moonData.physicalParameters
                )
            }
        }
        
        return BundledEphemeris(
            bodies: bodies,
            moons: moons,
            sunData: raw.sun.physicalParameters,
            metadata: raw.metadata
        )
    }
    
    // MARK: - Planetary Body Access
    
    /// Gets orbital elements for a body at J2000 epoch.
    ///
    /// - Parameter body: The celestial body.
    /// - Returns: Orbital elements, or nil if not available.
    public func elements(for body: CelestialBody) -> OrbitalElements? {
        bodies[body]?.elements
    }
    
    /// Gets orbital elements for a body propagated to a specific epoch.
    ///
    /// Uses the element rates to propagate from J2000 to the target epoch.
    ///
    /// - Parameters:
    ///   - body: The celestial body.
    ///   - epoch: The target epoch.
    /// - Returns: Orbital elements at the target epoch, or nil if body not available.
    public func elements(for body: CelestialBody, at epoch: Epoch) -> OrbitalElements? {
        guard let baseElements = bodies[body]?.elements else { return nil }
        return baseElements.at(epoch: epoch)
    }
    
    /// Gets the gravitational parameter (GM) for a body.
    ///
    /// - Parameter body: The celestial body.
    /// - Returns: GM in m³/s², or nil if not available.
    public func gm(for body: CelestialBody) -> Double? {
        // Check planets first, then moons
        if let planetGM = bodies[body]?.physicalParameters.gm {
            return planetGM
        }
        return moons[body]?.physicalParameters.gm
    }
    
    /// Gets the Sun's gravitational parameter.
    public var gmSun: Double {
        sunData.gm
    }
    
    /// All available planetary bodies in the bundled data.
    public var availableBodies: [CelestialBody] {
        Array(bodies.keys).sorted { $0.rawValue < $1.rawValue }
    }
    
    // MARK: - Moon Access
    
    /// Gets orbital elements for a moon (relative to parent body).
    ///
    /// - Parameter moon: The moon.
    /// - Returns: Moon orbital elements, or nil if not available.
    public func moonElements(for moon: CelestialBody) -> MoonOrbitalElements? {
        moons[moon]?.elements
    }
    
    /// Gets the parent body of a moon.
    ///
    /// - Parameter moon: The moon.
    /// - Returns: The parent body, or nil if not a moon.
    public func parentBody(of moon: CelestialBody) -> CelestialBody? {
        moons[moon]?.parent
    }
    
    /// Gets the orbital period of a moon.
    ///
    /// - Parameter moon: The moon.
    /// - Returns: Orbital period in days, or nil if not available.
    public func orbitalPeriod(of moon: CelestialBody) -> Double? {
        moons[moon]?.orbitalPeriod
    }
    
    /// Checks if a moon has a retrograde orbit.
    ///
    /// - Parameter moon: The moon.
    /// - Returns: True if retrograde, false otherwise.
    public func isRetrograde(_ moon: CelestialBody) -> Bool {
        moons[moon]?.isRetrograde ?? false
    }
    
    /// All available moons in the bundled data.
    public var availableMoons: [CelestialBody] {
        Array(moons.keys).sorted { $0.rawValue < $1.rawValue }
    }
    
    /// Gets all moons of a specific parent body.
    ///
    /// - Parameter parent: The parent body.
    /// - Returns: Array of moons orbiting the parent.
    public func moons(of parent: CelestialBody) -> [CelestialBody] {
        moons.filter { $0.value.parent == parent }.map { $0.key }.sorted { $0.rawValue < $1.rawValue }
    }
    
    /// Gets the complete moon data for a moon.
    ///
    /// - Parameter moon: The moon.
    /// - Returns: Complete moon data, or nil if not available.
    public func moonData(for moon: CelestialBody) -> MoonData? {
        moons[moon]
    }
}

// MARK: - Raw JSON Structure

/// Raw JSON structure for decoding.
private struct RawEphemerisData: Codable {
    let metadata: BundledEphemeris.Metadata
    let bodies: [String: RawBodyData]
    let moons: [String: RawMoonData]?
    let sun: RawSunData
}

private struct RawBodyData: Codable {
    let name: String
    let naifId: Int
    let elements: RawElements
    let rates: RawRates?
    let physicalParameters: BundledEphemeris.PhysicalParameters
}

private struct RawElements: Codable {
    let semiMajorAxis: Double
    let eccentricity: Double
    let inclination: Double
    let meanLongitude: Double
    let longitudeOfPerihelion: Double
    let longitudeOfAscendingNode: Double
}

private struct RawRates: Codable {
    let semiMajorAxisRate: Double
    let eccentricityRate: Double
    let inclinationRate: Double
    let meanLongitudeRate: Double
    let longitudeOfPerihelionRate: Double
    let longitudeOfAscendingNodeRate: Double
}

private struct RawMoonData: Codable {
    let name: String
    let naifId: Int
    let parent: String
    let elements: RawMoonElements
    let orbitalPeriod: Double
    let retrograde: Bool?
    let physicalParameters: BundledEphemeris.PhysicalParameters
}

private struct RawMoonElements: Codable {
    let semiMajorAxis: Double
    let eccentricity: Double
    let inclination: Double
    let meanLongitude: Double
    let longitudeOfPeriapsis: Double
    let longitudeOfAscendingNode: Double
}

private struct RawSunData: Codable {
    let name: String
    let naifId: Int
    let physicalParameters: BundledEphemeris.PhysicalParameters
}

// MARK: - Errors

/// Errors that can occur when loading ephemeris data.
public enum EphemerisError: Error, LocalizedError {
    case bundledDataNotFound
    case bodyNotFound(CelestialBody)
    case moonNotFound(CelestialBody)
    case parentNotFound(CelestialBody)
    case invalidEpoch(Epoch)
    case networkError(Error)
    case parseError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .bundledDataNotFound:
            return "Bundled ephemeris data not found in package resources"
        case .bodyNotFound(let body):
            return "Celestial body '\(body.name)' not found in ephemeris data"
        case .moonNotFound(let moon):
            return "Moon '\(moon.name)' not found in ephemeris data"
        case .parentNotFound(let body):
            return "Parent body for '\(body.name)' not found in ephemeris data"
        case .invalidEpoch(let epoch):
            return "Epoch \(epoch) is outside the valid range for this ephemeris"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parseError(let error):
            return "Parse error: \(error.localizedDescription)"
        }
    }
}
