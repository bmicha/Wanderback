import Foundation
import CoreLocation

struct LocationCluster: Identifiable {
    let id: UUID
    let centerCoordinate: CLLocationCoordinate2D
    let photos: [PhotoLocation]
    var displayName: String
    var country: String

    var photoCount: Int { photos.count }

    func distance(to other: LocationCluster) -> CLLocationDistance {
        let a = CLLocation(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude)
        let b = CLLocation(latitude: other.centerCoordinate.latitude, longitude: other.centerCoordinate.longitude)
        return a.distance(from: b)
    }
}
