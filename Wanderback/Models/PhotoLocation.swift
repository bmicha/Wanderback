import Foundation
import CoreLocation

struct PhotoLocation: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let dateTaken: Date
    let assetIdentifier: String
}
