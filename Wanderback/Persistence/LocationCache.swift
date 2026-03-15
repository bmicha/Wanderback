import Foundation
import SwiftData

@Model
class LocationCache {
    var assetIdentifier: String
    var latitude: Double
    var longitude: Double
    var placeName: String?
    var country: String?
    var lastUpdated: Date

    init(assetIdentifier: String, latitude: Double, longitude: Double, placeName: String? = nil, country: String? = nil, lastUpdated: Date = .now) {
        self.assetIdentifier = assetIdentifier
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.country = country
        self.lastUpdated = lastUpdated
    }
}
