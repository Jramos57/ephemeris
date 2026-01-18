import Testing
import Foundation
@testable import ephemeris

/// Tests for OrbitalElements type
///
/// Reference data from JPL:
/// https://ssd.jpl.nasa.gov/planets/approx_pos.html
@Suite("OrbitalElements Tests")
struct OrbitalElementsTests {
    
    // MARK: - Test Data (JPL Table 1: 1800-2050 AD)
    
    /// Earth's orbital elements at J2000 (from JPL)
    static let earthElementsJ2000 = OrbitalElements(
        semiMajorAxis: 1.00000261,           // AU
        eccentricity: 0.01671123,
        inclination: -0.00001531,            // degrees
        meanLongitude: 100.46457166,         // degrees
        longitudeOfPerihelion: 102.93768193, // degrees
        longitudeOfAscendingNode: 0.0,       // degrees
        epoch: .j2000
    )
    
    /// Mars orbital elements at J2000 (from JPL)
    static let marsElementsJ2000 = OrbitalElements(
        semiMajorAxis: 1.52371034,
        eccentricity: 0.09339410,
        inclination: 1.84969142,
        meanLongitude: -4.55343205,
        longitudeOfPerihelion: -23.94362959,
        longitudeOfAscendingNode: 49.55953891,
        epoch: .j2000
    )
    
    // MARK: - Initialization Tests
    
    @Test("Create orbital elements with basic initializer")
    func basicInitialization() {
        let elements = OrbitalElements(
            semiMajorAxis: 1.0,
            eccentricity: 0.0167,
            inclination: 0.0,
            meanLongitude: 100.0,
            longitudeOfPerihelion: 103.0,
            longitudeOfAscendingNode: 0.0,
            epoch: .j2000
        )
        
        #expect(elements.semiMajorAxis == 1.0)
        #expect(elements.eccentricity == 0.0167)
        #expect(elements.epoch == .j2000)
    }
    
    @Test("Create orbital elements with rates")
    func initializationWithRates() {
        let rates = OrbitalElementRates(
            semiMajorAxisRate: 0.00000562,
            eccentricityRate: -0.00004392,
            inclinationRate: -0.01294668,
            meanLongitudeRate: 35999.37244981,
            longitudeOfPerihelionRate: 0.32327364,
            longitudeOfAscendingNodeRate: 0.0
        )
        
        let elements = OrbitalElements(
            semiMajorAxis: 1.00000261,
            eccentricity: 0.01671123,
            inclination: -0.00001531,
            meanLongitude: 100.46457166,
            longitudeOfPerihelion: 102.93768193,
            longitudeOfAscendingNode: 0.0,
            epoch: .j2000,
            rates: rates
        )
        
        #expect(elements.rates != nil)
        #expect(elements.rates?.meanLongitudeRate == 35999.37244981)
    }
    
    // MARK: - Computed Properties Tests
    
    @Test("Argument of perihelion calculation")
    func argumentOfPerihelion() {
        // omega = longitude of perihelion - longitude of ascending node
        let elements = Self.marsElementsJ2000
        let omega = elements.argumentOfPerihelion
        
        // Expected: -23.94362959 - 49.55953891 = -73.5031685
        let expected = -23.94362959 - 49.55953891
        #expect(abs(omega - expected) < 0.0001)
    }
    
    @Test("Mean anomaly calculation")
    func meanAnomaly() {
        // M = L - longitude of perihelion
        let elements = Self.earthElementsJ2000
        let M = elements.meanAnomaly
        
        // Expected: 100.46457166 - 102.93768193 = -2.47311027
        let expected = 100.46457166 - 102.93768193
        #expect(abs(M - expected) < 0.0001)
    }
    
    @Test("Perihelion distance calculation")
    func perihelionDistance() {
        // q = a * (1 - e)
        let elements = Self.marsElementsJ2000
        let q = elements.perihelionDistance
        
        let expected = 1.52371034 * (1 - 0.09339410)
        #expect(abs(q - expected) < 0.0001)
    }
    
    @Test("Aphelion distance calculation")
    func aphelionDistance() {
        // Q = a * (1 + e)
        let elements = Self.marsElementsJ2000
        let Q = elements.aphelionDistance
        
        let expected = 1.52371034 * (1 + 0.09339410)
        #expect(abs(Q - expected) < 0.0001)
    }
    
    @Test("Orbital period calculation")
    func orbitalPeriod() {
        // T = sqrt(a^3) years (for heliocentric orbits)
        let elements = Self.marsElementsJ2000
        let T = elements.orbitalPeriodYears
        
        // Mars orbital period ~1.88 years
        let expected = sqrt(pow(1.52371034, 3))
        #expect(abs(T - expected) < 0.0001)
        #expect(abs(T - 1.88) < 0.01)
    }
    
    // MARK: - Propagation Tests
    
    @Test("Elements at different epoch with rates")
    func elementsAtEpoch() {
        // Earth elements with rates
        let rates = OrbitalElementRates(
            semiMajorAxisRate: 0.00000562,
            eccentricityRate: -0.00004392,
            inclinationRate: -0.01294668,
            meanLongitudeRate: 35999.37244981,
            longitudeOfPerihelionRate: 0.32327364,
            longitudeOfAscendingNodeRate: 0.0
        )
        
        let elements = OrbitalElements(
            semiMajorAxis: 1.00000261,
            eccentricity: 0.01671123,
            inclination: -0.00001531,
            meanLongitude: 100.46457166,
            longitudeOfPerihelion: 102.93768193,
            longitudeOfAscendingNode: 0.0,
            epoch: .j2000,
            rates: rates
        )
        
        // Get elements 1 century later
        let futureEpoch = Epoch(julianDate: Epoch.j2000.julianDate + 36525.0)
        let futureElements = elements.at(epoch: futureEpoch)
        
        // Semi-major axis should change by rate * 1 century
        let expectedA = 1.00000261 + 0.00000562 * 1.0
        #expect(abs(futureElements.semiMajorAxis - expectedA) < 0.0000001)
        
        // Mean longitude should advance significantly
        let expectedL = 100.46457166 + 35999.37244981 * 1.0
        #expect(abs(futureElements.meanLongitude - expectedL) < 0.001)
    }
    
    @Test("Elements without rates return self at different epoch")
    func elementsWithoutRates() {
        let elements = Self.earthElementsJ2000
        let futureEpoch = Epoch(julianDate: Epoch.j2000.julianDate + 365.25)
        let futureElements = elements.at(epoch: futureEpoch)
        
        // Without rates, elements should be unchanged except epoch
        #expect(futureElements.semiMajorAxis == elements.semiMajorAxis)
        #expect(futureElements.eccentricity == elements.eccentricity)
        #expect(futureElements.epoch == futureEpoch)
    }
    
    // MARK: - Validation Tests
    
    @Test("Eccentricity bounds")
    func eccentricityBounds() {
        // Circular orbit
        let circular = OrbitalElements(
            semiMajorAxis: 1.0, eccentricity: 0.0,
            inclination: 0.0, meanLongitude: 0.0,
            longitudeOfPerihelion: 0.0, longitudeOfAscendingNode: 0.0,
            epoch: .j2000
        )
        #expect(circular.isElliptical)
        #expect(circular.isCircular)
        
        // Elliptical orbit
        let elliptical = OrbitalElements(
            semiMajorAxis: 1.0, eccentricity: 0.5,
            inclination: 0.0, meanLongitude: 0.0,
            longitudeOfPerihelion: 0.0, longitudeOfAscendingNode: 0.0,
            epoch: .j2000
        )
        #expect(elliptical.isElliptical)
        #expect(!elliptical.isCircular)
        
        // Parabolic orbit
        let parabolic = OrbitalElements(
            semiMajorAxis: 1.0, eccentricity: 1.0,
            inclination: 0.0, meanLongitude: 0.0,
            longitudeOfPerihelion: 0.0, longitudeOfAscendingNode: 0.0,
            epoch: .j2000
        )
        #expect(parabolic.isParabolic)
        
        // Hyperbolic orbit
        let hyperbolic = OrbitalElements(
            semiMajorAxis: -1.0, eccentricity: 1.5,
            inclination: 0.0, meanLongitude: 0.0,
            longitudeOfPerihelion: 0.0, longitudeOfAscendingNode: 0.0,
            epoch: .j2000
        )
        #expect(hyperbolic.isHyperbolic)
    }
    
    // MARK: - Codable Tests
    
    @Test("OrbitalElements is Codable")
    func codableRoundTrip() throws {
        let original = Self.marsElementsJ2000
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(OrbitalElements.self, from: data)
        
        #expect(decoded.semiMajorAxis == original.semiMajorAxis)
        #expect(decoded.eccentricity == original.eccentricity)
        #expect(decoded.epoch == original.epoch)
    }
    
    // MARK: - Angle Normalization Tests
    
    @Test("Mean anomaly normalized to -180 to 180")
    func meanAnomalyNormalization() {
        let elements = OrbitalElements(
            semiMajorAxis: 1.0, eccentricity: 0.1,
            inclination: 0.0, meanLongitude: 500.0,  // > 360
            longitudeOfPerihelion: 100.0, longitudeOfAscendingNode: 0.0,
            epoch: .j2000
        )
        
        let M = elements.meanAnomalyNormalized
        #expect(M >= -180.0 && M <= 180.0)
    }
}

// MARK: - OrbitalElementRates Tests

@Suite("OrbitalElementRates Tests")
struct OrbitalElementRatesTests {
    
    @Test("Create rates from values")
    func createRates() {
        let rates = OrbitalElementRates(
            semiMajorAxisRate: 0.00000562,
            eccentricityRate: -0.00004392,
            inclinationRate: -0.01294668,
            meanLongitudeRate: 35999.37244981,
            longitudeOfPerihelionRate: 0.32327364,
            longitudeOfAscendingNodeRate: 0.0
        )
        
        #expect(rates.semiMajorAxisRate == 0.00000562)
        #expect(rates.meanLongitudeRate == 35999.37244981)
    }
    
    @Test("Rates are Codable")
    func codableRoundTrip() throws {
        let original = OrbitalElementRates(
            semiMajorAxisRate: 0.001,
            eccentricityRate: -0.0001,
            inclinationRate: 0.01,
            meanLongitudeRate: 360.0,
            longitudeOfPerihelionRate: 0.1,
            longitudeOfAscendingNodeRate: -0.05
        )
        
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OrbitalElementRates.self, from: data)
        
        #expect(decoded.semiMajorAxisRate == original.semiMajorAxisRate)
    }
}
