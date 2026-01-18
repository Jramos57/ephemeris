import Foundation

/// Client for fetching ephemeris data from JPL Horizons API.
///
/// JPL Horizons provides high-precision ephemeris data for solar system bodies.
/// This client allows querying state vectors for validation or higher accuracy.
///
/// ## Usage
///
/// ```swift
/// let client = HorizonsClient()
///
/// // Get Mars position at a specific date
/// let state = try await client.stateVector(
///     for: .mars,
///     at: Epoch(year: 2024, month: 6, day: 15),
///     relativeTo: .sun
/// )
///
/// // Get Moon position relative to Earth
/// let moonState = try await client.stateVector(
///     for: .moon,
///     at: .j2000,
///     relativeTo: .earth
/// )
/// ```
///
/// ## Rate Limits
///
/// JPL Horizons has rate limits. This client includes automatic retry with backoff.
/// For bulk queries, use batch methods.
///
/// ## API Documentation
///
/// https://ssd-api.jpl.nasa.gov/doc/horizons.html
public actor HorizonsClient {
    
    // MARK: - Constants
    
    /// JPL Horizons API endpoint.
    private static let baseURL = "https://ssd.jpl.nasa.gov/api/horizons.api"
    
    /// Maximum retries for rate-limited requests.
    private let maxRetries: Int
    
    /// Base delay for exponential backoff (seconds).
    private let baseDelay: TimeInterval
    
    /// URL session for requests.
    private let session: URLSession
    
    // MARK: - Initialization
    
    /// Creates a new Horizons client.
    ///
    /// - Parameters:
    ///   - maxRetries: Maximum number of retries for failed requests. Default is 3.
    ///   - baseDelay: Base delay for exponential backoff in seconds. Default is 1.0.
    ///   - session: Custom URL session. Default creates a new session.
    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        session: URLSession = .shared
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.session = session
    }
    
    // MARK: - Public API
    
    /// Fetches the state vector for a celestial body at a given epoch.
    ///
    /// - Parameters:
    ///   - body: The celestial body to query.
    ///   - epoch: The epoch at which to compute the state.
    ///   - center: The reference body (center). Default is Sun.
    ///   - frame: The output reference frame. Default is ecliptic J2000.
    /// - Returns: The state vector in the specified frame.
    /// - Throws: `EphemerisError.networkError` or `EphemerisError.parseError`.
    public func stateVector(
        for body: CelestialBody,
        at epoch: Epoch,
        relativeTo center: CelestialBody = .sun,
        frame: ReferenceFrame = .eclipticJ2000
    ) async throws -> StateVector {
        let request = try buildRequest(
            body: body,
            startEpoch: epoch,
            endEpoch: epoch.adding(days: 1),
            stepSize: "1d",
            center: center,
            frame: frame
        )
        
        let response = try await executeWithRetry(request)
        let states = try parseStateVectors(from: response, frame: frame)
        
        guard let state = states.first else {
            throw EphemerisError.parseError(HorizonsError.noDataReturned)
        }
        
        return state
    }
    
    /// Fetches state vectors for a celestial body over a time range.
    ///
    /// - Parameters:
    ///   - body: The celestial body to query.
    ///   - startEpoch: Start of the time range.
    ///   - endEpoch: End of the time range.
    ///   - stepDays: Step size in days. Default is 1.
    ///   - center: The reference body (center). Default is Sun.
    ///   - frame: The output reference frame. Default is ecliptic J2000.
    /// - Returns: Array of (epoch, state) tuples.
    /// - Throws: `EphemerisError.networkError` or `EphemerisError.parseError`.
    public func stateVectors(
        for body: CelestialBody,
        from startEpoch: Epoch,
        to endEpoch: Epoch,
        stepDays: Double = 1.0,
        relativeTo center: CelestialBody = .sun,
        frame: ReferenceFrame = .eclipticJ2000
    ) async throws -> [(epoch: Epoch, state: StateVector)] {
        let stepSize: String
        if stepDays >= 1.0 {
            stepSize = "\(Int(stepDays))d"
        } else {
            let hours = stepDays * 24.0
            stepSize = "\(Int(hours))h"
        }
        
        let request = try buildRequest(
            body: body,
            startEpoch: startEpoch,
            endEpoch: endEpoch,
            stepSize: stepSize,
            center: center,
            frame: frame
        )
        
        let response = try await executeWithRetry(request)
        let states = try parseStateVectors(from: response, frame: frame)
        
        // Generate epochs
        var epochs: [Epoch] = []
        var current = startEpoch
        while current.julianDate <= endEpoch.julianDate {
            epochs.append(current)
            current = current.adding(days: stepDays)
        }
        
        // Match epochs to states (they should align)
        return zip(epochs, states).map { ($0, $1) }
    }
    
    /// Fetches orbital elements for a celestial body at a given epoch.
    ///
    /// - Parameters:
    ///   - body: The celestial body to query.
    ///   - epoch: The epoch at which to compute elements.
    ///   - center: The reference body (center). Default is Sun.
    /// - Returns: The orbital elements.
    /// - Throws: `EphemerisError.networkError` or `EphemerisError.parseError`.
    public func orbitalElements(
        for body: CelestialBody,
        at epoch: Epoch,
        relativeTo center: CelestialBody = .sun
    ) async throws -> OrbitalElements {
        let request = try buildElementsRequest(
            body: body,
            epoch: epoch,
            center: center
        )
        
        let response = try await executeWithRetry(request)
        return try parseOrbitalElements(from: response, epoch: epoch)
    }
    
    // MARK: - Request Building
    
    /// Builds a Horizons API request for state vectors.
    private func buildRequest(
        body: CelestialBody,
        startEpoch: Epoch,
        endEpoch: Epoch,
        stepSize: String,
        center: CelestialBody,
        frame: ReferenceFrame
    ) throws -> URLRequest {
        var components = URLComponents(string: Self.baseURL)!
        
        // Format dates as YYYY-MM-DD
        let startDate = formatDate(startEpoch)
        let endDate = formatDate(endEpoch)
        
        // Reference frame code
        let refFrame = frame == .equatorialJ2000 ? "J2000" : "ECLIPJ2000"
        
        // Center code (NAIF ID with @ prefix)
        let centerCode = "@\(center.naifId)"
        
        components.queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "COMMAND", value: "'\(body.naifId)'"),
            URLQueryItem(name: "OBJ_DATA", value: "NO"),
            URLQueryItem(name: "MAKE_EPHEM", value: "YES"),
            URLQueryItem(name: "EPHEM_TYPE", value: "VECTORS"),
            URLQueryItem(name: "CENTER", value: centerCode),
            URLQueryItem(name: "REF_FRAME", value: refFrame),
            URLQueryItem(name: "REF_PLANE", value: "FRAME"),
            URLQueryItem(name: "VEC_TABLE", value: "2"),  // Position and velocity
            URLQueryItem(name: "VEC_LABELS", value: "NO"),
            URLQueryItem(name: "CSV_FORMAT", value: "YES"),
            URLQueryItem(name: "START_TIME", value: startDate),
            URLQueryItem(name: "STOP_TIME", value: endDate),
            URLQueryItem(name: "STEP_SIZE", value: stepSize),
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        
        return request
    }
    
    /// Builds a Horizons API request for orbital elements.
    private func buildElementsRequest(
        body: CelestialBody,
        epoch: Epoch,
        center: CelestialBody
    ) throws -> URLRequest {
        var components = URLComponents(string: Self.baseURL)!
        
        let date = formatDate(epoch)
        let endDate = formatDate(epoch.adding(days: 1))
        let centerCode = "@\(center.naifId)"
        
        components.queryItems = [
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "COMMAND", value: "'\(body.naifId)'"),
            URLQueryItem(name: "OBJ_DATA", value: "NO"),
            URLQueryItem(name: "MAKE_EPHEM", value: "YES"),
            URLQueryItem(name: "EPHEM_TYPE", value: "ELEMENTS"),
            URLQueryItem(name: "CENTER", value: centerCode),
            URLQueryItem(name: "REF_PLANE", value: "ECLIPTIC"),
            URLQueryItem(name: "START_TIME", value: date),
            URLQueryItem(name: "STOP_TIME", value: endDate),
            URLQueryItem(name: "STEP_SIZE", value: "1d"),
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        
        return request
    }
    
    // MARK: - Request Execution
    
    /// Executes a request with automatic retry and exponential backoff.
    private func executeWithRetry(_ request: URLRequest) async throws -> Data {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw HorizonsError.invalidResponse
                }
                
                switch httpResponse.statusCode {
                case 200:
                    return data
                case 429:
                    // Rate limited - retry with backoff
                    let delay = baseDelay * pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    lastError = HorizonsError.rateLimited
                    continue
                case 400...499:
                    throw HorizonsError.clientError(httpResponse.statusCode)
                case 500...599:
                    throw HorizonsError.serverError(httpResponse.statusCode)
                default:
                    throw HorizonsError.unexpectedStatus(httpResponse.statusCode)
                }
            } catch let error as HorizonsError {
                lastError = error
                if case .rateLimited = error {
                    continue
                }
                throw EphemerisError.networkError(error)
            } catch {
                throw EphemerisError.networkError(error)
            }
        }
        
        throw EphemerisError.networkError(lastError ?? HorizonsError.maxRetriesExceeded)
    }
    
    // MARK: - Response Parsing
    
    /// Parses state vectors from Horizons JSON response.
    private func parseStateVectors(from data: Data, frame: ReferenceFrame) throws -> [StateVector] {
        let response = try JSONDecoder().decode(HorizonsResponse.self, from: data)
        
        // Check for API error
        if let error = response.error {
            throw EphemerisError.parseError(HorizonsError.apiError(error))
        }
        
        guard let result = response.result else {
            throw EphemerisError.parseError(HorizonsError.noDataReturned)
        }
        
        // Parse the result string which contains CSV data
        return try parseVectorCSV(result, frame: frame)
    }
    
    /// Parses the CSV section of Horizons output for vectors.
    private func parseVectorCSV(_ result: String, frame: ReferenceFrame) throws -> [StateVector] {
        var states: [StateVector] = []
        
        // Find the data section between $$SOE and $$EOE markers
        guard let soeRange = result.range(of: "$$SOE"),
              let eoeRange = result.range(of: "$$EOE") else {
            throw HorizonsError.malformedResponse("Missing SOE/EOE markers")
        }
        
        let dataSection = result[soeRange.upperBound..<eoeRange.lowerBound]
        let lines = dataSection.split(separator: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            
            // CSV format: JDTDB, Calendar Date, X, Y, Z, VX, VY, VZ
            let components = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            
            guard components.count >= 8 else { continue }
            
            // Parse Julian Date (first column)
            guard let jd = Double(components[0]) else { continue }
            let epoch = Epoch(julianDate: jd)
            
            // Parse position (km) and velocity (km/s)
            // Horizons outputs in km and km/s, convert to m and m/s
            guard let x = Double(components[2]),
                  let y = Double(components[3]),
                  let z = Double(components[4]),
                  let vx = Double(components[5]),
                  let vy = Double(components[6]),
                  let vz = Double(components[7]) else {
                continue
            }
            
            // Convert km to m
            let position = SIMD3<Double>(x * 1000, y * 1000, z * 1000)
            let velocity = SIMD3<Double>(vx * 1000, vy * 1000, vz * 1000)
            
            states.append(StateVector(position: position, velocity: velocity, epoch: epoch, frame: frame))
        }
        
        return states
    }
    
    /// Parses orbital elements from Horizons response.
    private func parseOrbitalElements(from data: Data, epoch: Epoch) throws -> OrbitalElements {
        let response = try JSONDecoder().decode(HorizonsResponse.self, from: data)
        
        if let error = response.error {
            throw EphemerisError.parseError(HorizonsError.apiError(error))
        }
        
        guard let result = response.result else {
            throw EphemerisError.parseError(HorizonsError.noDataReturned)
        }
        
        return try parseElementsText(result, epoch: epoch)
    }
    
    /// Parses orbital elements from Horizons text output.
    private func parseElementsText(_ result: String, epoch: Epoch) throws -> OrbitalElements {
        // Find data section
        guard let soeRange = result.range(of: "$$SOE"),
              let eoeRange = result.range(of: "$$EOE") else {
            throw HorizonsError.malformedResponse("Missing SOE/EOE markers")
        }
        
        let dataSection = String(result[soeRange.upperBound..<eoeRange.lowerBound])
        
        // Parse key=value pairs
        var values: [String: Double] = [:]
        let pattern = #"([A-Z]{1,2})\s*=\s*([\d.E+-]+)"#
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: dataSection, options: [], range: NSRange(dataSection.startIndex..., in: dataSection))
        
        for match in matches {
            if let keyRange = Range(match.range(at: 1), in: dataSection),
               let valueRange = Range(match.range(at: 2), in: dataSection),
               let value = Double(dataSection[valueRange]) {
                let key = String(dataSection[keyRange])
                values[key] = value
            }
        }
        
        // Extract required elements
        // Horizons uses: EC=eccentricity, A=semi-major axis (km), IN=inclination,
        // OM=longitude of ascending node, W=argument of periapsis, MA=mean anomaly
        guard let a = values["A"],
              let ec = values["EC"],
              let inc = values["IN"],
              let om = values["OM"],
              let w = values["W"],
              let ma = values["MA"] else {
            throw HorizonsError.malformedResponse("Missing orbital element values")
        }
        
        // Convert semi-major axis from km to AU
        let aAU = a / Constants.au * 1000  // km -> m -> AU
        
        // Calculate mean longitude and longitude of perihelion
        let meanLongitude = om + w + ma
        let longitudeOfPerihelion = om + w
        
        return OrbitalElements(
            semiMajorAxis: aAU,
            eccentricity: ec,
            inclination: inc,
            meanLongitude: meanLongitude.truncatingRemainder(dividingBy: 360.0),
            longitudeOfPerihelion: longitudeOfPerihelion.truncatingRemainder(dividingBy: 360.0),
            longitudeOfAscendingNode: om,
            epoch: epoch
        )
    }
    
    // MARK: - Helpers
    
    /// Formats an epoch as YYYY-MM-DD for Horizons.
    private func formatDate(_ epoch: Epoch) -> String {
        // Convert Julian Date to calendar date
        let jd = epoch.julianDate
        
        // Algorithm from Meeus, "Astronomical Algorithms"
        let z = Int(jd + 0.5)
        let f = jd + 0.5 - Double(z)
        
        let a: Int
        if z < 2299161 {
            a = z
        } else {
            let alpha = Int((Double(z) - 1867216.25) / 36524.25)
            a = z + 1 + alpha - alpha / 4
        }
        
        let b = a + 1524
        let c = Int((Double(b) - 122.1) / 365.25)
        let d = Int(365.25 * Double(c))
        let e = Int(Double(b - d) / 30.6001)
        
        let day = b - d - Int(30.6001 * Double(e)) + Int(f)
        let month: Int
        if e < 14 {
            month = e - 1
        } else {
            month = e - 13
        }
        let year: Int
        if month > 2 {
            year = c - 4716
        } else {
            year = c - 4715
        }
        
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}

// MARK: - Supporting Types

/// Response structure from Horizons API.
private struct HorizonsResponse: Decodable {
    let result: String?
    let error: String?
    let signature: Signature?
    
    struct Signature: Decodable {
        let version: String?
        let source: String?
    }
}

/// Errors specific to Horizons API interactions.
public enum HorizonsError: Error, LocalizedError {
    case invalidResponse
    case rateLimited
    case maxRetriesExceeded
    case clientError(Int)
    case serverError(Int)
    case unexpectedStatus(Int)
    case noDataReturned
    case apiError(String)
    case malformedResponse(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Horizons API"
        case .rateLimited:
            return "Rate limited by Horizons API"
        case .maxRetriesExceeded:
            return "Maximum retries exceeded"
        case .clientError(let code):
            return "Client error: HTTP \(code)"
        case .serverError(let code):
            return "Server error: HTTP \(code)"
        case .unexpectedStatus(let code):
            return "Unexpected HTTP status: \(code)"
        case .noDataReturned:
            return "No data returned from Horizons API"
        case .apiError(let message):
            return "Horizons API error: \(message)"
        case .malformedResponse(let detail):
            return "Malformed response: \(detail)"
        }
    }
}
