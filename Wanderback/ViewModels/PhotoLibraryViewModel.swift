import Foundation
import Photos
import os

@Observable
class PhotoLibraryViewModel {
    var authorizationStatus: PHAuthorizationStatus = .notDetermined
    var photoLocations: [PhotoLocation] = []
    var totalPhotoCount = 0
    var isLoading = false
    var errorMessage: String?
    var notEnoughPhotos = false

    private let photoIndexer = PhotoIndexer()
    private let logger = Logger(subsystem: "com.bastien.Wanderback", category: "PhotoLibraryVM")

    var hasAccess: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    var gpsStatsText: String {
        "\(photoLocations.count) photos avec GPS / \(totalPhotoCount) total"
    }

    func requestAccessAndLoadPhotos() async {
        isLoading = true
        defer { isLoading = false }

        authorizationStatus = await photoIndexer.requestAuthorization()
        logger.info("Authorization status: \(self.authorizationStatus.rawValue)")

        switch authorizationStatus {
        case .authorized, .limited:
            let assets = await photoIndexer.fetchPhotos()
            totalPhotoCount = assets.count
            photoLocations = photoIndexer.filterPhotosWithGPS(from: assets)

            if photoLocations.count < PhotoIndexer.minimumDistinctLocations {
                notEnoughPhotos = true
                logger.warning("Not enough GPS photos: \(self.photoLocations.count) < \(PhotoIndexer.minimumDistinctLocations)")
            }
        case .denied, .restricted:
            errorMessage = "Wanderback a besoin d'accéder à vos photos pour fonctionner. Autorisez l'accès dans Réglages > Confidentialité > Photos."
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}
