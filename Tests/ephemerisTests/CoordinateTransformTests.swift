import Testing
import Foundation
import simd
@testable import ephemeris

/// Tests for coordinate frame transformations
///
/// Reference: IAU SOFA Library, JPL Horizons
@Suite("CoordinateTransform Tests")
struct CoordinateTransformTests {
    
    // MARK: - Ecliptic to Equatorial Tests
    
    @Test("Ecliptic to equatorial at vernal equinox")
    func eclipticToEquatorialVernalEquinox() {
        // Point on vernal equinox (x-axis): should be unchanged
        let ecliptic = SIMD3<Double>(1.0, 0.0, 0.0)
        let equatorial = CoordinateTransform.eclipticToEquatorial(ecliptic)
        
        #expect(abs(equatorial.x - 1.0) < 1e-10)
        #expect(abs(equatorial.y) < 1e-10)
        #expect(abs(equatorial.z) < 1e-10)
    }
    
    @Test("Ecliptic to equatorial at summer solstice direction")
    func eclipticToEquatorialSummerSolstice() {
        // Point along y-axis in ecliptic (summer solstice direction)
        // Should be rotated by obliquity angle around x-axis
        let ecliptic = SIMD3<Double>(0.0, 1.0, 0.0)
        let equatorial = CoordinateTransform.eclipticToEquatorial(ecliptic)
        
        let obliquity = Constants.obliquityJ2000Radians
        let expectedY = cos(obliquity)
        let expectedZ = sin(obliquity)
        
        #expect(abs(equatorial.x) < 1e-10)
        #expect(abs(equatorial.y - expectedY) < 1e-8)
        #expect(abs(equatorial.z - expectedZ) < 1e-8)
    }
    
    @Test("Ecliptic to equatorial at ecliptic north pole")
    func eclipticToEquatorialNorthPole() {
        // Ecliptic north pole should transform to celestial coordinates
        let ecliptic = SIMD3<Double>(0.0, 0.0, 1.0)
        let equatorial = CoordinateTransform.eclipticToEquatorial(ecliptic)
        
        let obliquity = Constants.obliquityJ2000Radians
        let expectedY = -sin(obliquity)
        let expectedZ = cos(obliquity)
        
        #expect(abs(equatorial.x) < 1e-10)
        #expect(abs(equatorial.y - expectedY) < 1e-8)
        #expect(abs(equatorial.z - expectedZ) < 1e-8)
    }
    
    @Test("Ecliptic to equatorial preserves magnitude")
    func eclipticToEquatorialMagnitude() {
        let ecliptic = SIMD3<Double>(3.0, 4.0, 5.0)
        let equatorial = CoordinateTransform.eclipticToEquatorial(ecliptic)
        
        let originalMag = simd_length(ecliptic)
        let transformedMag = simd_length(equatorial)
        
        #expect(abs(originalMag - transformedMag) < 1e-10)
    }
    
    // MARK: - Equatorial to Ecliptic Tests
    
    @Test("Equatorial to ecliptic round trip")
    func equatorialToEclipticRoundTrip() {
        let original = SIMD3<Double>(1.5, 2.3, 0.7)
        let equatorial = CoordinateTransform.eclipticToEquatorial(original)
        let backToEcliptic = CoordinateTransform.equatorialToEcliptic(equatorial)
        
        #expect(abs(backToEcliptic.x - original.x) < 1e-10)
        #expect(abs(backToEcliptic.y - original.y) < 1e-10)
        #expect(abs(backToEcliptic.z - original.z) < 1e-10)
    }
    
    @Test("Equatorial to ecliptic at celestial north pole")
    func equatorialToEclipticCelestialNorthPole() {
        // Celestial north pole
        let equatorial = SIMD3<Double>(0.0, 0.0, 1.0)
        let ecliptic = CoordinateTransform.equatorialToEcliptic(equatorial)
        
        let obliquity = Constants.obliquityJ2000Radians
        let expectedY = sin(obliquity)
        let expectedZ = cos(obliquity)
        
        #expect(abs(ecliptic.x) < 1e-10)
        #expect(abs(ecliptic.y - expectedY) < 1e-8)
        #expect(abs(ecliptic.z - expectedZ) < 1e-8)
    }
    
    // MARK: - StateVector Transform Tests
    
    @Test("StateVector transform ecliptic to equatorial")
    func stateVectorEclipticToEquatorial() {
        let eclipticState = StateVector(
            position: SIMD3(Constants.au, 0, 0),
            velocity: SIMD3(0, 29780, 0),
            epoch: .j2000,
            frame: .eclipticJ2000
        )
        
        let equatorialState = CoordinateTransform.transform(
            eclipticState,
            to: .equatorialJ2000
        )
        
        // Position should be mostly unchanged (on vernal equinox)
        #expect(abs(equatorialState.position.x - Constants.au) < 1e6)
        
        // Velocity should be rotated
        #expect(equatorialState.frame == .equatorialJ2000)
        #expect(equatorialState.epoch == eclipticState.epoch)
        
        // Magnitude should be preserved
        #expect(abs(equatorialState.speed - eclipticState.speed) < 0.1)
    }
    
    @Test("StateVector transform preserves distance and speed")
    func stateVectorTransformPreservesMagnitudes() {
        let state = StateVector(
            position: SIMD3(1.2e11, -3.4e10, 5.6e9),
            velocity: SIMD3(25000, 12000, -3000),
            epoch: .j2000,
            frame: .eclipticJ2000
        )
        
        let transformed = CoordinateTransform.transform(state, to: .equatorialJ2000)
        
        #expect(abs(transformed.distance - state.distance) < 1.0)
        #expect(abs(transformed.speed - state.speed) < 0.001)
    }
    
    @Test("StateVector transform same frame returns copy")
    func stateVectorTransformSameFrame() {
        let state = StateVector(
            position: SIMD3(1e11, 2e11, 3e10),
            velocity: SIMD3(10000, 20000, 5000),
            epoch: .j2000,
            frame: .eclipticJ2000
        )
        
        let same = CoordinateTransform.transform(state, to: .eclipticJ2000)
        
        #expect(same.position == state.position)
        #expect(same.velocity == state.velocity)
    }
    
    // MARK: - Rotation Matrix Tests
    
    @Test("Rotation matrix Rx properties")
    func rotationMatrixRxProperties() {
        // Rx(0) should be identity
        let identity = CoordinateTransform.rotationMatrixX(angle: 0)
        #expect(abs(identity[0][0] - 1) < 1e-10)
        #expect(abs(identity[1][1] - 1) < 1e-10)
        #expect(abs(identity[2][2] - 1) < 1e-10)
        
        // Rx(90°) should rotate y to z
        let rx90 = CoordinateTransform.rotationMatrixX(angle: .pi / 2)
        let yAxis = SIMD3<Double>(0, 1, 0)
        let rotated = rx90 * yAxis
        #expect(abs(rotated.x) < 1e-10)
        #expect(abs(rotated.y) < 1e-10)
        #expect(abs(rotated.z - 1) < 1e-10)
    }
    
    @Test("Rotation matrix Rz properties")
    func rotationMatrixRzProperties() {
        // Rz(90°) should rotate x to y
        let rz90 = CoordinateTransform.rotationMatrixZ(angle: .pi / 2)
        let xAxis = SIMD3<Double>(1, 0, 0)
        let rotated = rz90 * xAxis
        #expect(abs(rotated.x) < 1e-10)
        #expect(abs(rotated.y - 1) < 1e-10)
        #expect(abs(rotated.z) < 1e-10)
    }
    
    // MARK: - Spherical Coordinate Tests
    
    @Test("Cartesian to spherical at x-axis")
    func cartesianToSphericalXAxis() {
        let cartesian = SIMD3<Double>(1.0, 0.0, 0.0)
        let (r, lon, lat) = CoordinateTransform.cartesianToSpherical(cartesian)
        
        #expect(abs(r - 1.0) < 1e-10)
        #expect(abs(lon) < 1e-10)       // 0° longitude
        #expect(abs(lat) < 1e-10)       // 0° latitude
    }
    
    @Test("Cartesian to spherical at y-axis")
    func cartesianToSphericalYAxis() {
        let cartesian = SIMD3<Double>(0.0, 1.0, 0.0)
        let (r, lon, lat) = CoordinateTransform.cartesianToSpherical(cartesian)
        
        #expect(abs(r - 1.0) < 1e-10)
        #expect(abs(lon - 90.0) < 1e-10)  // 90° longitude
        #expect(abs(lat) < 1e-10)          // 0° latitude
    }
    
    @Test("Cartesian to spherical at north pole")
    func cartesianToSphericalNorthPole() {
        let cartesian = SIMD3<Double>(0.0, 0.0, 1.0)
        let (r, _, lat) = CoordinateTransform.cartesianToSpherical(cartesian)
        
        #expect(abs(r - 1.0) < 1e-10)
        #expect(abs(lat - 90.0) < 1e-10)  // 90° latitude (north pole)
    }
    
    @Test("Spherical to cartesian round trip")
    func sphericalToCartesianRoundTrip() {
        let original = SIMD3<Double>(3.0, 4.0, 5.0)
        let (r, lon, lat) = CoordinateTransform.cartesianToSpherical(original)
        let back = CoordinateTransform.sphericalToCartesian(r: r, longitude: lon, latitude: lat)
        
        #expect(abs(back.x - original.x) < 1e-10)
        #expect(abs(back.y - original.y) < 1e-10)
        #expect(abs(back.z - original.z) < 1e-10)
    }
    
    // MARK: - Precession Tests
    
    @Test("Precession at J2000 is identity")
    func precessionAtJ2000() {
        // At J2000, T=0, so precession matrix should be identity
        let original = SIMD3<Double>(1.0, 0.0, 0.0)
        let converted = CoordinateTransform.convertJ2000ToJNow(original, at: .j2000)
        
        #expect(abs(converted.x - 1.0) < 1e-12)
        #expect(abs(converted.y) < 1e-12)
        #expect(abs(converted.z) < 1e-12)
    }
    
    @Test("Precession moves vernal equinox drift")
    func precessionDrift() {
        // General precession in longitude is about 50.3 arcseconds per year
        // In 50 years, this is ~2500 arcseconds ≈ 0.7 degrees
        
        // Epoch: J2050 (50 years after J2000)
        // Julian Date = 2451545.0 + 50 * 365.25 = 2469807.5
        let j2050 = Epoch(julianDate: 2469807.5)
        
        let vernalEquinoxJ2000 = SIMD3<Double>(1.0, 0.0, 0.0)
        let converted = CoordinateTransform.convertJ2000ToJNow(vernalEquinoxJ2000, at: j2050)
        
        // We expect the x-axis to have moved.
        // It shouldn't be (1,0,0) anymore.
        #expect(abs(converted.x - 1.0) > 1e-5)
        
        // Roughly check the magnitude of the shift
        // angle ≈ acos(x)
        let angleRad = acos(converted.x)
        let angleDeg = angleRad * 180.0 / .pi
        
        // Expected shift is roughly 0.7°, let's say between 0.5° and 1.0°
        #expect(angleDeg > 0.5 && angleDeg < 1.0)
    }
}
