import Foundation

/// Physical and astronomical constants used throughout the ephemeris calculations.
///
/// All values are in SI units unless otherwise specified.
///
/// ## References
///
/// - IAU 2012 Resolution B2 (defining constants)
/// - IERS Conventions (2010)
/// - CODATA 2018 (physical constants)
public enum Constants {
    
    // MARK: - Defining Constants (exact by definition)
    
    /// Speed of light in vacuum (m/s).
    ///
    /// This is an exact defined constant as of 2019.
    public static let c: Double = 299_792_458.0
    
    /// Astronomical Unit (m).
    ///
    /// The IAU 2012 definition: exactly 149,597,870,700 meters.
    /// This is the approximate mean Earth-Sun distance.
    public static let au: Double = 149_597_870_700.0
    
    /// Light-time for 1 AU (seconds).
    ///
    /// The time for light to travel one astronomical unit.
    public static let auLightTime: Double = au / c
    
    // MARK: - Time Constants
    
    /// Seconds per day.
    public static let secondsPerDay: Double = 86_400.0
    
    /// Days per Julian year.
    public static let daysPerJulianYear: Double = 365.25
    
    /// Days per Julian century.
    public static let daysPerJulianCentury: Double = 36_525.0
    
    /// Seconds per Julian year.
    public static let secondsPerJulianYear: Double = secondsPerDay * daysPerJulianYear
    
    // MARK: - Gravitational Constants
    
    /// Newtonian gravitational constant G (m³ kg⁻¹ s⁻²).
    ///
    /// CODATA 2018 recommended value.
    public static let G: Double = 6.67430e-11
    
    /// Heliocentric gravitational constant GM_Sun (m³/s²).
    ///
    /// The product of G and the Sun's mass, known more precisely than either individually.
    /// Value from DE440/441.
    public static let gmSun: Double = 1.327_124_400_41_94e20
    
    /// Geocentric gravitational constant GM_Earth (m³/s²).
    ///
    /// Value from IERS Conventions (2010).
    public static let gmEarth: Double = 3.986_004_418e14
    
    // MARK: - GM Values for Planets (m³/s²)
    
    /// Mercury's gravitational parameter.
    public static let gmMercury: Double = 2.203_187e13
    
    /// Venus's gravitational parameter.
    public static let gmVenus: Double = 3.248_585_9e14
    
    /// Mars's gravitational parameter.
    public static let gmMars: Double = 4.282_837e13
    
    /// Jupiter's gravitational parameter.
    public static let gmJupiter: Double = 1.266_865_319_0e17
    
    /// Saturn's gravitational parameter.
    public static let gmSaturn: Double = 3.793_120_623e16
    
    /// Uranus's gravitational parameter.
    public static let gmUranus: Double = 5.793_951_322e15
    
    /// Neptune's gravitational parameter.
    public static let gmNeptune: Double = 6.836_527_100_58e15
    
    // MARK: - Angle Conversion
    
    /// Degrees to radians conversion factor.
    public static let degreesToRadians: Double = .pi / 180.0
    
    /// Radians to degrees conversion factor.
    public static let radiansToDegrees: Double = 180.0 / .pi
    
    /// Arcseconds per radian.
    public static let arcsecPerRadian: Double = 206_264.806_247_096_36
    
    // MARK: - Reference Values
    
    /// J2000.0 epoch as Julian Date.
    public static let j2000JulianDate: Double = 2_451_545.0
    
    /// Obliquity of the ecliptic at J2000.0 (degrees).
    ///
    /// IAU 2006 value.
    public static let obliquityJ2000Degrees: Double = 23.439_291_111
    
    /// Obliquity of the ecliptic at J2000.0 (radians).
    public static let obliquityJ2000Radians: Double = obliquityJ2000Degrees * degreesToRadians
}

// MARK: - Convenience Extensions

public extension Double {
    /// Converts degrees to radians.
    var degreesToRadians: Double {
        self * Constants.degreesToRadians
    }
    
    /// Converts radians to degrees.
    var radiansToDegrees: Double {
        self * Constants.radiansToDegrees
    }
    
    /// Converts astronomical units to meters.
    var auToMeters: Double {
        self * Constants.au
    }
    
    /// Converts meters to astronomical units.
    var metersToAU: Double {
        self / Constants.au
    }
    
    /// Converts kilometers to meters.
    var kmToMeters: Double {
        self * 1000.0
    }
    
    /// Converts meters to kilometers.
    var metersToKm: Double {
        self / 1000.0
    }
}
