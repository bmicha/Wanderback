import Foundation
import SwiftData
import CoreLocation

@Model
class LocationCache {
    var latitude: Double
    var longitude: Double
    var city: String?
    var country: String
    var countryCode: String
    var region: String?
    var cachedAt: Date

    init(latitude: Double, longitude: Double, city: String? = nil, country: String, countryCode: String, region: String? = nil, cachedAt: Date = .now) {
        self.latitude = latitude
        self.longitude = longitude
        self.city = city
        self.country = country
        self.countryCode = countryCode
        self.region = region
        self.cachedAt = cachedAt
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var displayName: String {
        [city, region, country].compactMap { $0 }.joined(separator: ", ")
    }

    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let cached = CLLocation(latitude: latitude, longitude: longitude)
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return cached.distance(from: target)
    }
}
