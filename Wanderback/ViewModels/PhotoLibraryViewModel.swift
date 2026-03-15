import Foundation
import Photos

@Observable
class PhotoLibraryViewModel {
    var authorizationStatus: PHAuthorizationStatus = .notDetermined
    var photoLocations: [PhotoLocation] = []
    var isLoading = false
}
