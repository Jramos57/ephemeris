import Foundation

/// A celestial body in the solar system.
///
/// This enumeration includes the Sun, planets, dwarf planets, and major moons
/// that are commonly needed for orbital mechanics calculations.
///
/// ## Example
///
/// ```swift
/// let mars = CelestialBody.mars
/// print(mars.name)  // "Mars"
/// print(mars.naifId) // 499
/// ```
///
/// ## NAIF IDs
///
/// Each body has a NAIF (Navigation and Ancillary Information Facility) ID,
/// which is used by JPL's SPICE toolkit and Horizons system. These IDs follow
/// a standard convention:
/// - Sun: 10
/// - Planetary barycenters: 1-9
/// - Planet centers: X99 (e.g., Earth = 399, Mars = 499)
/// - Moons: XYY where X is planet number (e.g., Moon = 301, Io = 501)
public enum CelestialBody: String, Codable, Sendable, CaseIterable {
    
    // MARK: - Sun
    
    case sun
    
    // MARK: - Planets
    
    case mercury
    case venus
    case earth
    case mars
    case jupiter
    case saturn
    case uranus
    case neptune
    
    // MARK: - Dwarf Planets
    
    case ceres
    case pluto
    
    // MARK: - Major Moons
    
    case moon        // Earth's Moon (Luna)
    case io          // Jupiter I
    case europa      // Jupiter II
    case ganymede    // Jupiter III
    case callisto    // Jupiter IV
    case titan       // Saturn VI
    case enceladus   // Saturn II
    
    // MARK: - Properties
    
    /// The display name of the celestial body.
    public var name: String {
        switch self {
        case .sun: return "Sun"
        case .mercury: return "Mercury"
        case .venus: return "Venus"
        case .earth: return "Earth"
        case .mars: return "Mars"
        case .jupiter: return "Jupiter"
        case .saturn: return "Saturn"
        case .uranus: return "Uranus"
        case .neptune: return "Neptune"
        case .ceres: return "Ceres"
        case .pluto: return "Pluto"
        case .moon: return "Moon"
        case .io: return "Io"
        case .europa: return "Europa"
        case .ganymede: return "Ganymede"
        case .callisto: return "Callisto"
        case .titan: return "Titan"
        case .enceladus: return "Enceladus"
        }
    }
    
    /// The NAIF ID used by JPL Horizons and SPICE.
    public var naifId: Int {
        switch self {
        case .sun: return 10
        case .mercury: return 199
        case .venus: return 299
        case .earth: return 399
        case .mars: return 499
        case .jupiter: return 599
        case .saturn: return 699
        case .uranus: return 799
        case .neptune: return 899
        case .ceres: return 2000001  // Ceres is asteroid 1
        case .pluto: return 999
        case .moon: return 301
        case .io: return 501
        case .europa: return 502
        case .ganymede: return 503
        case .callisto: return 504
        case .titan: return 606
        case .enceladus: return 602
        }
    }
    
    /// The Horizons command string for this body.
    ///
    /// Used when constructing API requests to JPL Horizons.
    public var horizonsCommand: String {
        return "'\(naifId)'"
    }
    
    /// Whether this body is a planet.
    public var isPlanet: Bool {
        switch self {
        case .mercury, .venus, .earth, .mars, .jupiter, .saturn, .uranus, .neptune:
            return true
        default:
            return false
        }
    }
    
    /// Whether this body is a moon.
    public var isMoon: Bool {
        switch self {
        case .moon, .io, .europa, .ganymede, .callisto, .titan, .enceladus:
            return true
        default:
            return false
        }
    }
    
    /// The parent body (for moons) or nil (for planets/Sun).
    public var parent: CelestialBody? {
        switch self {
        case .moon: return .earth
        case .io, .europa, .ganymede, .callisto: return .jupiter
        case .titan, .enceladus: return .saturn
        default: return nil
        }
    }
    
    /// All planets in order from the Sun.
    public static let planets: [CelestialBody] = [
        .mercury, .venus, .earth, .mars, .jupiter, .saturn, .uranus, .neptune
    ]
    
    /// All moons included in this enumeration.
    public static let moons: [CelestialBody] = [
        .moon, .io, .europa, .ganymede, .callisto, .titan, .enceladus
    ]
}
