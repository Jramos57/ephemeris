import Testing
import Foundation
import simd
@testable import ephemeris

/// Tests for the main Ephemeris API
@Suite("Ephemeris Tests")
struct EphemerisTests {
    
    // MARK: - Initialization Tests
    
    @Test("Ephemeris initializes with bundled data")
    func initWithBundledData() async throws {
        let ephemeris = try Ephemeris()
        let bodies = await ephemeris.availableBodies
        
        #expect(bodies.contains(.earth))
        #expect(bodies.contains(.mars))
        #expect(bodies.contains(.jupiter))
    }
    
    @Test("Ephemeris reports correct data source")
    func dataSourceInfo() async throws {
        let ephemeris = try Ephemeris()
        let source = await ephemeris.dataSource
        
        #expect(source.contains("JPL"))
    }
    
    // MARK: - Planet Position Tests
    
    @Test("Earth at J2000 is approximately 1 AU from Sun")
    func earthJ2000() async throws {
        let ephemeris = try Ephemeris()
        let state = try await ephemeris.state(of: .earth, at: .j2000)
        
        // Earth should be about 1 AU from Sun
        #expect(state.distanceAU > 0.98)
        #expect(state.distanceAU < 1.02)
        
        // Orbital velocity ~30 km/s
        #expect(state.speedKmPerSec > 29.0)
        #expect(state.speedKmPerSec < 31.0)
    }
    
    @Test("Mars at J2000 is at expected distance")
    func marsJ2000() async throws {
        let ephemeris = try Ephemeris()
        let state = try await ephemeris.state(of: .mars, at: .j2000)
        
        // Mars semi-major axis is ~1.52 AU
        // Distance should be between perihelion (~1.38) and aphelion (~1.67)
        #expect(state.distanceAU > 1.35)
        #expect(state.distanceAU < 1.70)
    }
    
    @Test("Jupiter at J2000 is at expected distance")
    func jupiterJ2000() async throws {
        let ephemeris = try Ephemeris()
        let state = try await ephemeris.state(of: .jupiter, at: .j2000)
        
        // Jupiter semi-major axis is ~5.2 AU
        #expect(state.distanceAU > 4.9)
        #expect(state.distanceAU < 5.5)
    }
    
    @Test("All planets have reasonable distances")
    func allPlanetDistances() async throws {
        let ephemeris = try Ephemeris()
        let epoch = Epoch.j2000
        
        // Expected semi-major axes (AU)
        let expectedDistances: [CelestialBody: (min: Double, max: Double)] = [
            .mercury: (0.3, 0.5),
            .venus: (0.7, 0.75),
            .earth: (0.98, 1.02),
            .mars: (1.35, 1.7),
            .jupiter: (4.9, 5.5),
            .saturn: (9.0, 10.1),
            .uranus: (18.0, 20.5),
            .neptune: (29.5, 30.5)
        ]
        
        for (planet, range) in expectedDistances {
            let state = try await ephemeris.state(of: planet, at: epoch)
            #expect(state.distanceAU >= range.min, "\(planet.name) too close: \(state.distanceAU) AU")
            #expect(state.distanceAU <= range.max, "\(planet.name) too far: \(state.distanceAU) AU")
        }
    }
    
    // MARK: - Time Propagation Tests
    
    @Test("Positions change over time")
    func positionsChangeOverTime() async throws {
        let ephemeris = try Ephemeris()
        let epoch1 = Epoch.j2000
        let epoch2 = Epoch(julianDate: Epoch.j2000.julianDate + 30)  // 30 days later
        
        let earth1 = try await ephemeris.position(of: .earth, at: epoch1)
        let earth2 = try await ephemeris.position(of: .earth, at: epoch2)
        
        // After 30 days, Earth should have moved significantly
        // Earth travels ~2.57 million km per day, so ~77 million km in 30 days
        let positionChange = simd_length(earth2 - earth1)
        #expect(positionChange > 1e10)  // > 10 million km
        #expect(positionChange < 1e12)  // < 1 billion km
    }
    
    @Test("Earth returns to similar position after 1 year")
    func earthOrbitalPeriod() async throws {
        let ephemeris = try Ephemeris()
        let epoch1 = Epoch.j2000
        let epoch2 = Epoch(julianDate: Epoch.j2000.julianDate + 365.25)  // 1 sidereal year
        
        let distance1 = try await ephemeris.distance(of: .earth, at: epoch1)
        let distance2 = try await ephemeris.distance(of: .earth, at: epoch2)
        
        // Distance from Sun should be similar (within 5%)
        let ratio = distance2 / distance1
        #expect(ratio > 0.95)
        #expect(ratio < 1.05)
    }
    
    // MARK: - Relative Position Tests
    
    @Test("Earth-Mars distance is reasonable")
    func earthMarsDistance() async throws {
        let ephemeris = try Ephemeris()
        let distance = try await ephemeris.distanceAU(between: .earth, and: .mars, at: .j2000)
        
        // Earth-Mars distance ranges from ~0.37 AU (opposition) to ~2.67 AU (conjunction)
        #expect(distance > 0.3)
        #expect(distance < 2.7)
    }
    
    @Test("Relative position is antisymmetric")
    func relativePositionAntisymmetric() async throws {
        let ephemeris = try Ephemeris()
        let epoch = Epoch.j2000
        
        let earthFromMars = try await ephemeris.relativePosition(of: .earth, from: .mars, at: epoch)
        let marsFromEarth = try await ephemeris.relativePosition(of: .mars, from: .earth, at: epoch)
        
        // Should be opposite vectors
        let sum = earthFromMars + marsFromEarth
        #expect(simd_length(sum) < 1.0)  // Near zero
    }
    
    // MARK: - Multi-Body Queries
    
    @Test("All planet states query works")
    func allPlanetStates() async throws {
        let ephemeris = try Ephemeris()
        let states = try await ephemeris.allPlanetStates(at: .j2000)
        
        #expect(states.count == 8)
        #expect(states[.earth] != nil)
        #expect(states[.mars] != nil)
    }
    
    @Test("Multiple body query is consistent with single queries")
    func multiBodyConsistency() async throws {
        let ephemeris = try Ephemeris()
        let epoch = Epoch.j2000
        
        let multiResult = try await ephemeris.states(of: [.earth, .mars], at: epoch)
        let singleEarth = try await ephemeris.state(of: .earth, at: epoch)
        let singleMars = try await ephemeris.state(of: .mars, at: epoch)
        
        #expect(multiResult[.earth]?.position == singleEarth.position)
        #expect(multiResult[.mars]?.position == singleMars.position)
    }
    
    // MARK: - Orbital Elements Access
    
    @Test("Can retrieve orbital elements")
    func orbitalElementsAccess() async throws {
        let ephemeris = try Ephemeris()
        let elements = try await ephemeris.orbitalElements(for: .earth)
        
        #expect(abs(elements.semiMajorAxis - 1.0) < 0.01)
        #expect(elements.eccentricity < 0.02)
    }
    
    // MARK: - Dwarf Planet Tests
    
    @Test("Ceres position is in asteroid belt")
    func ceresPosition() async throws {
        let ephemeris = try Ephemeris()
        let state = try await ephemeris.state(of: .ceres, at: .j2000)
        
        // Ceres is at ~2.77 AU
        #expect(state.distanceAU > 2.5)
        #expect(state.distanceAU < 3.0)
    }
    
    @Test("Pluto position is beyond Neptune")
    func plutoPosition() async throws {
        let ephemeris = try Ephemeris()
        let state = try await ephemeris.state(of: .pluto, at: .j2000)
        
        // Pluto semi-major axis ~39.5 AU, but high eccentricity
        // At J2000, should be around 30 AU
        #expect(state.distanceAU > 25)
        #expect(state.distanceAU < 50)
    }
    
    // MARK: - Frame Transformation Tests
    
    @Test("Equatorial output frame works")
    func equatorialFrame() async throws {
        let ephemeris = try Ephemeris(outputFrame: .equatorialJ2000)
        let state = try await ephemeris.state(of: .earth, at: .j2000)
        
        #expect(state.frame == .equatorialJ2000)
        
        // Distance should be same regardless of frame
        #expect(abs(state.distanceAU - 1.0) < 0.02)
    }
    
    // MARK: - Error Handling
    
    @Test("Sun throws error (no orbital elements)")
    func sunThrowsError() async throws {
        let ephemeris = try Ephemeris()
        
        // Sun has no orbital elements - it's the central body
        do {
            _ = try await ephemeris.state(of: .sun, at: .j2000)
            Issue.record("Expected error for sun")
        } catch EphemerisError.bodyNotFound {
            // Expected - Sun is not a body that orbits anything
        }
    }
    
    // MARK: - Moon Tests
    
    @Test("Moon heliocentric position is near Earth")
    func moonHeliocentricPosition() async throws {
        let ephemeris = try Ephemeris()
        let moonState = try await ephemeris.state(of: .moon, at: .j2000)
        let earthState = try await ephemeris.state(of: .earth, at: .j2000)
        
        // Moon should be roughly 1 AU from Sun (same as Earth)
        #expect(moonState.distanceAU > 0.97)
        #expect(moonState.distanceAU < 1.03)
        
        // Moon should be within ~400,000 km of Earth
        let separation = simd_length(moonState.position - earthState.position)
        let separationKm = separation / 1000.0
        #expect(separationKm > 350_000)
        #expect(separationKm < 410_000)
    }
    
    @Test("Moon relative to Earth has correct distance")
    func moonRelativeToEarth() async throws {
        let ephemeris = try Ephemeris()
        let moonState = try await ephemeris.state(of: .moon, at: .j2000, relativeTo: .earth)
        
        // Moon's semi-major axis is ~384,400 km
        let distanceKm = simd_length(moonState.position) / 1000.0
        #expect(distanceKm > 350_000)
        #expect(distanceKm < 410_000)
        
        // Orbital velocity ~1 km/s
        let speedKmPerSec = simd_length(moonState.velocity) / 1000.0
        #expect(speedKmPerSec > 0.9)
        #expect(speedKmPerSec < 1.1)
    }
    
    @Test("All moons return valid states")
    func allMoonsHaveStates() async throws {
        let ephemeris = try Ephemeris()
        let moons = await ephemeris.availableMoons
        
        #expect(moons.count >= 10)  // We have 10 moons defined
        
        for moon in moons {
            let state = try await ephemeris.state(of: moon, at: .j2000)
            // All moons should be at reasonable solar system distances
            #expect(state.distanceAU > 0.5, "\(moon.name) too close to Sun")
            #expect(state.distanceAU < 35, "\(moon.name) too far from Sun")
        }
    }
    
    @Test("Mars moons orbit at correct distances")
    func marsMoonsDistances() async throws {
        let ephemeris = try Ephemeris()
        
        let phobosState = try await ephemeris.state(of: .phobos, at: .j2000, relativeTo: .mars)
        let deimosState = try await ephemeris.state(of: .deimos, at: .j2000, relativeTo: .mars)
        
        // Phobos: ~9,376 km from Mars center
        let phobosDistKm = simd_length(phobosState.position) / 1000.0
        #expect(phobosDistKm > 9_000)
        #expect(phobosDistKm < 10_000)
        
        // Deimos: ~23,460 km from Mars center
        let deimosDistKm = simd_length(deimosState.position) / 1000.0
        #expect(deimosDistKm > 22_000)
        #expect(deimosDistKm < 25_000)
    }
    
    @Test("Jupiter moons have correct relative ordering")
    func jupiterMoonsOrdering() async throws {
        let ephemeris = try Ephemeris()
        
        let ioState = try await ephemeris.state(of: .io, at: .j2000, relativeTo: .jupiter)
        let europaState = try await ephemeris.state(of: .europa, at: .j2000, relativeTo: .jupiter)
        let ganymedeState = try await ephemeris.state(of: .ganymede, at: .j2000, relativeTo: .jupiter)
        let callistoState = try await ephemeris.state(of: .callisto, at: .j2000, relativeTo: .jupiter)
        
        let ioDist = simd_length(ioState.position)
        let europaDist = simd_length(europaState.position)
        let ganymedeDist = simd_length(ganymedeState.position)
        let callistoDist = simd_length(callistoState.position)
        
        // Galilean moons should be in order: Io < Europa < Ganymede < Callisto
        #expect(ioDist < europaDist, "Io should be closer than Europa")
        #expect(europaDist < ganymedeDist, "Europa should be closer than Ganymede")
        #expect(ganymedeDist < callistoDist, "Ganymede should be closer than Callisto")
    }
    
    @Test("Saturn moons Titan and Enceladus at correct distances")
    func saturnMoonsDistances() async throws {
        let ephemeris = try Ephemeris()
        
        let titanState = try await ephemeris.state(of: .titan, at: .j2000, relativeTo: .saturn)
        let enceladusState = try await ephemeris.state(of: .enceladus, at: .j2000, relativeTo: .saturn)
        
        // Titan: ~1,221,870 km from Saturn
        let titanDistKm = simd_length(titanState.position) / 1000.0
        #expect(titanDistKm > 1_100_000)
        #expect(titanDistKm < 1_300_000)
        
        // Enceladus: ~238,000 km from Saturn  
        let enceladusDistKm = simd_length(enceladusState.position) / 1000.0
        #expect(enceladusDistKm > 200_000)
        #expect(enceladusDistKm < 280_000)
        
        // Enceladus should be closer than Titan
        #expect(enceladusDistKm < titanDistKm)
    }
    
    @Test("Phoebe is retrograde moon of Saturn")
    func phoebeRetrograde() async throws {
        let ephemeris = try Ephemeris()
        
        let phoebeState = try await ephemeris.state(of: .phoebe, at: .j2000, relativeTo: .saturn)
        
        // Phoebe: semi-major axis ~12,952,000 km, but eccentricity ~0.164
        // Distance ranges from ~10.8M km (periapsis) to ~15.1M km (apoapsis)
        let phoebeDistKm = simd_length(phoebeState.position) / 1000.0
        #expect(phoebeDistKm > 10_000_000)
        #expect(phoebeDistKm < 16_000_000)
        
        // Phoebe is much more distant than Titan (~1.2M km)
        let titanState = try await ephemeris.state(of: .titan, at: .j2000, relativeTo: .saturn)
        let titanDistKm = simd_length(titanState.position) / 1000.0
        #expect(phoebeDistKm > titanDistKm * 5, "Phoebe should be much farther than Titan")
    }
}

// MARK: - BundledEphemeris Tests

@Suite("BundledEphemeris Tests")
struct BundledEphemerisTests {
    
    @Test("Load bundled data")
    func loadBundledData() throws {
        let bundled = try BundledEphemeris.load()
        
        #expect(bundled.bodies.count >= 8)
        #expect(bundled.gmSun > 1.3e20)
    }
    
    @Test("All planets have elements")
    func allPlanetsHaveElements() throws {
        let bundled = try BundledEphemeris.load()
        
        for planet in CelestialBody.planets {
            let elements = bundled.elements(for: planet)
            #expect(elements != nil, "\(planet.name) missing elements")
        }
    }
    
    @Test("Elements have rates")
    func elementsHaveRates() throws {
        let bundled = try BundledEphemeris.load()
        
        let earthElements = bundled.elements(for: .earth)
        #expect(earthElements?.rates != nil)
        #expect(earthElements?.rates?.meanLongitudeRate ?? 0 > 35000)  // ~36000 deg/century
    }
    
    @Test("Propagated elements differ from base")
    func propagatedElementsDiffer() throws {
        let bundled = try BundledEphemeris.load()
        let epoch1 = Epoch.j2000
        let epoch2 = Epoch(julianDate: Epoch.j2000.julianDate + 36525)  // 1 century later
        
        let elements1 = bundled.elements(for: .earth, at: epoch1)
        let elements2 = bundled.elements(for: .earth, at: epoch2)
        
        #expect(elements1 != nil)
        #expect(elements2 != nil)
        
        // Mean longitude should have advanced significantly
        let diff = abs(elements2!.meanLongitude - elements1!.meanLongitude)
        #expect(diff > 1000)  // Should advance ~36000 degrees
    }
    
    @Test("GM values are physically reasonable")
    func gmValuesReasonable() throws {
        let bundled = try BundledEphemeris.load()
        
        // GM should scale roughly with mass
        let gmEarth = bundled.gm(for: .earth)
        let gmJupiter = bundled.gm(for: .jupiter)
        
        #expect(gmEarth != nil)
        #expect(gmJupiter != nil)
        #expect(gmJupiter! > gmEarth! * 100)  // Jupiter >> Earth
    }
}
