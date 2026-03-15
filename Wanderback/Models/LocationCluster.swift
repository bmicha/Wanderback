import Foundation
import CoreLocation

struct LocationCluster: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let photos: [PhotoLocation]
    var placeName: String?
    var country: String?
}
