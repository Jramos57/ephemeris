import Testing
import Foundation
import simd
@testable import ephemeris

/// Tests for StateVector type
@Suite("StateVector Tests")
struct StateVectorTests {
    
    // MARK: - Initialization Tests
    
    @Test("Create state vector with SIMD3 values")
    func simdInitialization() {
        let pos = SIMD3<Double>(1e11, 2e11, 3e10)
        let vel = SIMD3<Double>(1000, 2000, 500)
        
        let state = StateVector(
            position: pos,
            velocity: vel,
            epoch: .j2000,
            frame: .eclipticJ2000
        )
        
        #expect(state.position == pos)
        #expect(state.velocity == vel)
        #expect(state.epoch == .j2000)
        #expect(state.frame == .eclipticJ2000)
    }
    
    @Test("Create state vector with component values")
    func componentInitialization() {
        let state = StateVector(
            x: 1e11, y: 0, z: 0,
            vx: 0, vy: 29780, vz: 0,
            epoch: .j2000,
            frame: .eclipticJ2000
        )
        
        #expect(state.x == 1e11)
        #expect(state.y == 0)
        #expect(state.vx == 0)
        #expect(state.vy == 29780)
    }
    
    // MARK: - Distance Tests
    
    @Test("Distance calculation")
    func distanceCalculation() {
        // 1 AU along x-axis
        let state = StateVector(
            position: SIMD3(Constants.au, 0, 0),
            velocity: SIMD3(0, 0, 0),
            epoch: .j2000,
            frame: .eclipticJ2000
        )
        
        #expect(abs(state.distance - Constants.au) < 1.0)
        #expect(abs(state.distanceAU - 1.0) < 1e-10)
    }
    
    @Test("Distance in different units")
    func distanceUnits() {
        // 1 million km
        let state = StateVector(
            position: SIMD3(1e9, 0, 0),
            velocity: SIMD3(0, 0, 0),
            epoch: .j2000,
            frame: .eclipticJ2000
        )
        
        #expect(abs(state.distanceKm - 1e6) < 1.0)
    }
    
    // MARK: - Speed Tests
    
    @Test("Speed calculation")
    func speedCalculation() {
        // ~30 km/s orbital velocity (Earth-like)
        let state = StateVector(
            position: SIMD3(Constants.au, 0, 0),
            velocity: SIMD3(0, 29780, 0),
            epoch: .j2000,
            frame: .eclipticJ2000
        )
        
        #expect(abs(state.speed - 29780) < 0.1)
        #expect(abs(state.speedKmPerSec - 29.78) < 0.001)
    }
    
    @Test("3D velocity magnitude")
    func velocity3DMagnitude() {
        let state = StateVector(
            position: SIMD3(0, 0, 0),
            velocity: SIMD3(3000, 4000, 0),  // 3-4-5 triangle
            epoch: .j2000,
            frame: .eclipticJ2000
        )
        
        #expect(abs(state.speed - 5000) < 0.1)
    }
    
    // MARK: - Direction Tests
    
    @Test("Position direction is unit vector")
    func positionDirection() {
        let state = StateVector(
            position: SIMD3(100, 200, 300),
            velocity: SIMD3(0, 0, 0),
            epoch: .j2000,
            frame: .eclipticJ2000
        )
        
        let dir = state.positionDirection
        let magnitude = simd_length(dir)
        #expect(abs(magnitude - 1.0) < 1e-10)
    }
    
    @Test("Velocity direction is unit vector")
    func velocityDirection() {
        let state = StateVector(
            position: SIMD3(0, 0, 0),
            velocity: SIMD3(1000, 2000, 3000),
            epoch: .j2000,
            frame: .eclipticJ2000
        )
        
        let dir = state.velocityDirection
        let magnitude = simd_length(dir)
        #expect(abs(magnitude - 1.0) < 1e-10)
    }
    
    // MARK: - Angular Momentum Tests
    
    @Test("Specific angular momentum for circular orbit")
    func specificAngularMomentum() {
        // Circular orbit: position perpendicular to velocity
        let r = Constants.au
        let v = 29780.0  // Approximate Earth orbital velocity
        
        let state = StateVector(
            position: SIMD3(r, 0, 0),
            velocity: SIMD3(0, v, 0),
            epoch: .j2000,
            frame: .eclipticJ2000
        )
        
        let h = state.specificAngularMomentum
        
        // h should point in +z direction for this configuration
        #expect(abs(h.x) < 1e-10)
        #expect(abs(h.y) < 1e-10)
        #expect(h.z > 0)
        
        // Magnitude should be r * v
        let expectedMagnitude = r * v
        #expect(abs(state.specificAngularMomentumMagnitude - expectedMagnitude) < 1e6)
    }
    
    // MARK: - Radial/Transverse Velocity Tests
    
    @Test("Radial velocity for circular orbit")
    func radialVelocityCircular() {
        // Circular orbit: velocity perpendicular to position
        let state = StateVector(
            position: SIMD3(Constants.au, 0, 0),
            velocity: SIMD3(0, 29780, 0),
            epoch: .j2000,
            frame: .eclipticJ2000
        )
        
        // Radial velocity should be zero (moving tangentially)
        #expect(abs(state.radialVelocity) < 0.1)
        
        // Transverse velocity should equal total velocity
        #expect(abs(state.transverseVelocity - 29780) < 0.1)
    }
    
    @Test("Radial velocity for radial motion")
    func radialVelocityRadial() {
        // Moving directly outward from origin
        let state = StateVector(
            position: SIMD3(1e11, 0, 0),
            velocity: SIMD3(10000, 0, 0),
            epoch: .j2000,
            frame: .eclipticJ2000
        )
        
        // All velocity is radial
        #expect(abs(state.radialVelocity - 10000) < 0.1)
        #expect(abs(state.transverseVelocity) < 0.1)
    }
    
    // MARK: - Codable Tests
    
    @Test("StateVector is Codable")
    func codableRoundTrip() throws {
        let original = StateVector(
            position: SIMD3(1.5e11, -2.3e10, 4.1e9),
            velocity: SIMD3(25000, 12000, -3000),
            epoch: .j2000,
            frame: .eclipticJ2000
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(StateVector.self, from: data)
        
        #expect(decoded.x == original.x)
        #expect(decoded.y == original.y)
        #expect(decoded.z == original.z)
        #expect(decoded.vx == original.vx)
        #expect(decoded.vy == original.vy)
        #expect(decoded.vz == original.vz)
        #expect(decoded.epoch == original.epoch)
        #expect(decoded.frame == original.frame)
    }
    
    // MARK: - Sendable Tests
    
    @Test("StateVector can be passed across actor boundaries")
    func sendableConformance() async {
        let state = StateVector(
            position: SIMD3(1e11, 0, 0),
            velocity: SIMD3(0, 30000, 0),
            epoch: .j2000,
            frame: .eclipticJ2000
        )
        
        let result = await Task.detached {
            return state.distanceAU
        }.value
        
        #expect(abs(result - state.distanceAU) < 1e-10)
    }
}

// MARK: - Constants Tests

@Suite("Constants Tests")
struct ConstantsTests {
    
    @Test("AU has correct value")
    func auValue() {
        // IAU 2012 definition: exactly 149,597,870,700 m
        #expect(Constants.au == 149_597_870_700.0)
    }
    
    @Test("Speed of light has correct value")
    func speedOfLight() {
        #expect(Constants.c == 299_792_458.0)
    }
    
    @Test("GM Sun is approximately correct")
    func gmSun() {
        // Should be around 1.327e20 m³/s²
        #expect(Constants.gmSun > 1.32e20)
        #expect(Constants.gmSun < 1.33e20)
    }
    
    @Test("Degree-radian conversion")
    func degreeRadianConversion() {
        let degrees: Double = 180.0
        let radians = degrees.degreesToRadians
        #expect(abs(radians - .pi) < 1e-10)
        
        let backToDegrees = radians.radiansToDegrees
        #expect(abs(backToDegrees - 180.0) < 1e-10)
    }
    
    @Test("AU-meter conversion")
    func auMeterConversion() {
        let au: Double = 1.0
        let meters = au.auToMeters
        #expect(meters == Constants.au)
        
        let backToAU = meters.metersToAU
        #expect(abs(backToAU - 1.0) < 1e-10)
    }
}
