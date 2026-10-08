import CoreLocation

struct PlaceLookupResult {
    let name: String
    let city: String
    let country: String
}

struct CityLookupResult {
    let city: String
    let country: String
    let coordinate: CLLocationCoordinate2D
}

/// Each request owns its geocoder, so overlapping map/editor requests cannot
/// cancel each other. The actor protects the small in-memory result cache.
actor ReverseGeocodingService {
    static let shared = ReverseGeocodingService()

    private var cache: [String: PlaceLookupResult] = [:]

    func lookUp(coordinate: CLLocationCoordinate2D) async -> PlaceLookupResult? {
        let key = cacheKey(for: coordinate)
        if let cached = cache[key] { return cached }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else {
            return nil
        }

        let result = PlaceLookupResult(
            name: placemark.name ?? placemark.locality ?? "未命名地点",
            city: Self.cityName(for: placemark),
            country: placemark.country ?? ""
        )
        cache[key] = result
        return result
    }

    /// Forward-geocodes a free-typed city name so "新建城市" can drop a
    /// reasonable map center without needing coordinates from the user.
    func lookUp(cityName: String) async -> CityLookupResult? {
        guard let placemark = try? await CLGeocoder().geocodeAddressString(cityName).first,
              let coordinate = placemark.location?.coordinate else {
            return nil
        }
        return CityLookupResult(
            city: placemark.locality ?? cityName,
            country: placemark.country ?? "",
            coordinate: coordinate
        )
    }

    nonisolated static func cityName(for placemark: CLPlacemark) -> String {
        let name = placemark.locality ?? placemark.administrativeArea ?? ""
        // Match the app's existing Chinese city names (上海, 武汉, 长沙).
        if placemark.isoCountryCode == "CN", name.hasSuffix("市") {
            return String(name.dropLast())
        }
        return name
    }

    private func cacheKey(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.4f,%.4f", coordinate.latitude, coordinate.longitude)
    }
}
