import Testing
import Foundation
import simd
@testable import ephemeris

/// Tests for Kepler equation solver
///
/// The Kepler equation: M = E - e*sin(E)
/// Given mean anomaly M and eccentricity e, solve for eccentric anomaly E
///
/// Reference: JPL Horizons documentation
/// https://ssd.jpl.nasa.gov/planets/approx_pos.html
@Suite("KeplerSolver Tests")
struct KeplerSolverTests {
    
    // MARK: - Basic Kepler Equation Tests
    
    @Test("Solve Kepler equation for circular orbit (e=0)")
    func circularOrbit() {
        // For e=0, E = M (trivial case)
        let M = 45.0  // degrees
        let e = 0.0
        
        let E = KeplerSolver.solveKepler(meanAnomaly: M, eccentricity: e)
        #expect(abs(E - M) < 1e-10)
    }
    
    @Test("Solve Kepler equation for low eccentricity")
    func lowEccentricity() {
        // Earth-like orbit e ≈ 0.017
        let M = 90.0  // degrees
        let e = 0.0167
        
        let E = KeplerSolver.solveKepler(meanAnomaly: M, eccentricity: e)
        
        // Verify: M = E - e*sin(E) (in degrees, e* = e * 180/π)
        let eStar = e * 180.0 / .pi
        let computedM = E - eStar * sin(E * .pi / 180.0)
        #expect(abs(computedM - M) < 1e-6)
    }
    
    @Test("Solve Kepler equation for moderate eccentricity")
    func moderateEccentricity() {
        // Mars-like orbit e ≈ 0.093
        let M = 45.0
        let e = 0.0934
        
        let E = KeplerSolver.solveKepler(meanAnomaly: M, eccentricity: e)
        
        // Verify solution
        let eStar = e * 180.0 / .pi
        let computedM = E - eStar * sin(E * .pi / 180.0)
        #expect(abs(computedM - M) < 1e-6)
    }
    
    @Test("Solve Kepler equation for high eccentricity")
    func highEccentricity() {
        // Mercury or comet-like e ≈ 0.2
        let M = 120.0
        let e = 0.2056
        
        let E = KeplerSolver.solveKepler(meanAnomaly: M, eccentricity: e)
        
        // Verify solution
        let eStar = e * 180.0 / .pi
        let computedM = E - eStar * sin(E * .pi / 180.0)
        #expect(abs(computedM - M) < 1e-6)
    }
    
    @Test("Solve Kepler equation for very high eccentricity")
    func veryHighEccentricity() {
        // Halley's comet-like e ≈ 0.967
        let M = 30.0
        let e = 0.967
        
        let E = KeplerSolver.solveKepler(meanAnomaly: M, eccentricity: e)
        
        // Verify solution
        let eStar = e * 180.0 / .pi
        let computedM = E - eStar * sin(E * .pi / 180.0)
        #expect(abs(computedM - M) < 1e-5)  // Slightly looser tolerance for high e
    }
    
    @Test("Solve Kepler equation for negative mean anomaly")
    func negativeMeanAnomaly() {
        let M = -45.0
        let e = 0.1
        
        let E = KeplerSolver.solveKepler(meanAnomaly: M, eccentricity: e)
        
        // Verify solution
        let eStar = e * 180.0 / .pi
        let computedM = E - eStar * sin(E * .pi / 180.0)
        #expect(abs(computedM - M) < 1e-6)
    }
    
    @Test("Solve Kepler equation at perihelion (M=0)")
    func atPerihelion() {
        let M = 0.0
        let e = 0.5
        
        let E = KeplerSolver.solveKepler(meanAnomaly: M, eccentricity: e)
        #expect(abs(E) < 1e-10)  // E should also be 0 at perihelion
    }
    
    @Test("Solve Kepler equation at aphelion (M=180)")
    func atAphelion() {
        let M = 180.0
        let e = 0.5
        
        let E = KeplerSolver.solveKepler(meanAnomaly: M, eccentricity: e)
        #expect(abs(E - 180.0) < 1e-6)  // E should also be 180 at aphelion
    }
    
    // MARK: - True Anomaly Tests
    
    @Test("True anomaly at perihelion")
    func trueAnomalyAtPerihelion() {
        let E = 0.0  // degrees
        let e = 0.5
        
        let nu = KeplerSolver.trueAnomaly(eccentricAnomaly: E, eccentricity: e)
        #expect(abs(nu) < 1e-10)  // True anomaly should be 0 at perihelion
    }
    
    @Test("True anomaly at aphelion")
    func trueAnomalyAtAphelion() {
        let E = 180.0  // degrees
        let e = 0.5
        
        let nu = KeplerSolver.trueAnomaly(eccentricAnomaly: E, eccentricity: e)
        #expect(abs(nu - 180.0) < 1e-6)  // True anomaly should be 180 at aphelion
    }
    
    @Test("True anomaly for circular orbit")
    func trueAnomalyCircular() {
        // For circular orbit, true anomaly = eccentric anomaly = mean anomaly
        let E = 90.0
        let e = 0.0
        
        let nu = KeplerSolver.trueAnomaly(eccentricAnomaly: E, eccentricity: e)
        #expect(abs(nu - E) < 1e-10)
    }
    
    @Test("True anomaly leads eccentric anomaly for e > 0")
    func trueAnomalyLeadsEccentric() {
        // In first half of orbit (0 < E < 180), true anomaly > eccentric anomaly
        let E = 90.0
        let e = 0.5
        
        let nu = KeplerSolver.trueAnomaly(eccentricAnomaly: E, eccentricity: e)
        #expect(nu > E)  // True anomaly should lead
    }
    
    // MARK: - Orbital Plane Position Tests
    
    @Test("Position in orbital plane at perihelion")
    func orbitalPlanePositionPerihelion() {
        let a = 1.0  // AU
        let e = 0.5
        let E = 0.0  // degrees (perihelion)
        
        let (xPrime, yPrime) = KeplerSolver.orbitalPlanePosition(
            semiMajorAxis: a,
            eccentricity: e,
            eccentricAnomaly: E
        )
        
        // At perihelion: x' = a(1-e), y' = 0
        let expectedX = a * (1 - e)
        #expect(abs(xPrime - expectedX) < 1e-10)
        #expect(abs(yPrime) < 1e-10)
    }
    
    @Test("Position in orbital plane at aphelion")
    func orbitalPlanePositionAphelion() {
        let a = 1.0  // AU
        let e = 0.5
        let E = 180.0  // degrees (aphelion)
        
        let (xPrime, yPrime) = KeplerSolver.orbitalPlanePosition(
            semiMajorAxis: a,
            eccentricity: e,
            eccentricAnomaly: E
        )
        
        // At aphelion: x' = -a(1+e), y' = 0
        let expectedX = -a * (1 + e)
        #expect(abs(xPrime - expectedX) < 1e-10)
        #expect(abs(yPrime) < 1e-10)
    }
    
    @Test("Position in orbital plane at E=90 degrees")
    func orbitalPlanePosition90() {
        let a = 1.0  // AU
        let e = 0.5
        let E = 90.0  // degrees
        
        let (xPrime, yPrime) = KeplerSolver.orbitalPlanePosition(
            semiMajorAxis: a,
            eccentricity: e,
            eccentricAnomaly: E
        )
        
        // x' = a(cos(E) - e) = a(0 - 0.5) = -0.5
        // y' = a*sqrt(1-e²)*sin(E) = 1 * sqrt(0.75) * 1 ≈ 0.866
        #expect(abs(xPrime - (-0.5)) < 1e-10)
        #expect(abs(yPrime - sqrt(0.75)) < 1e-10)
    }
    
    // MARK: - Full Position Calculation Tests
    
    @Test("Earth position at J2000 is approximately 1 AU from Sun")
    func earthPositionJ2000() {
        // Earth's orbital elements at J2000 (from JPL)
        let elements = OrbitalElements(
            semiMajorAxis: 1.00000261,
            eccentricity: 0.01671123,
            inclination: -0.00001531,
            meanLongitude: 100.46457166,
            longitudeOfPerihelion: 102.93768193,
            longitudeOfAscendingNode: 0.0,
            epoch: .j2000
        )
        
        let state = KeplerSolver.stateVector(from: elements, gm: Constants.gmSun)
        
        // Earth should be about 1 AU from Sun
        #expect(abs(state.distanceAU - 1.0) < 0.02)  // Within 2% (accounting for eccentricity)
        
        // Orbital velocity should be about 30 km/s
        #expect(state.speedKmPerSec > 29.0)
        #expect(state.speedKmPerSec < 31.0)
    }
    
    @Test("Mars position has correct semi-major axis distance range")
    func marsPositionRange() {
        // Mars orbital elements at J2000
        let elements = OrbitalElements(
            semiMajorAxis: 1.52371034,
            eccentricity: 0.09339410,
            inclination: 1.84969142,
            meanLongitude: -4.55343205,
            longitudeOfPerihelion: -23.94362959,
            longitudeOfAscendingNode: 49.55953891,
            epoch: .j2000
        )
        
        let state = KeplerSolver.stateVector(from: elements, gm: Constants.gmSun)
        
        // Mars distance should be between perihelion and aphelion
        let q = elements.perihelionDistance  // ~1.38 AU
        let Q = elements.aphelionDistance    // ~1.67 AU
        
        #expect(state.distanceAU >= q * 0.99)  // Allow small numerical error
        #expect(state.distanceAU <= Q * 1.01)
    }
    
    // MARK: - Convergence Tests
    
    @Test("Solver converges for all test cases")
    func convergenceAllCases() {
        let testCases: [(M: Double, e: Double)] = [
            (0, 0),
            (90, 0),
            (180, 0),
            (45, 0.1),
            (90, 0.5),
            (170, 0.9),
            (-45, 0.3),
            (1, 0.99),
        ]
        
        for (M, e) in testCases {
            let E = KeplerSolver.solveKepler(meanAnomaly: M, eccentricity: e)
            
            // Verify solution
            let eStar = e * 180.0 / .pi
            let computedM = E - eStar * sin(E * .pi / 180.0)
            #expect(abs(computedM - M) < 1e-5, "Failed for M=\(M), e=\(e)")
        }
    }
    
    @Test("Solver handles edge case e very close to 1")
    func nearParabolicOrbit() {
        let M = 10.0
        let e = 0.999
        
        let E = KeplerSolver.solveKepler(meanAnomaly: M, eccentricity: e)
        
        // Just verify it returns a finite result
        #expect(E.isFinite)
    }
}
