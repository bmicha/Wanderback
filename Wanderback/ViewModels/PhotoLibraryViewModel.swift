import Foundation
import Photos
import os

@Observable
class PhotoLibraryViewModel {
    var authorizationStatus: PHAuthorizationStatus = .notDetermined
    var assets: [PHAsset] = []
    var isLoading = false
    var errorMessage: String?

    private let photoIndexer = PhotoIndexer()
    private let logger = Logger(subsystem: "com.bastien.Wanderback", category: "PhotoLibraryVM")

    var hasAccess: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    func requestAccessAndLoadPhotos() async {
        isLoading = true
        defer { isLoading = false }

        authorizationStatus = await photoIndexer.requestAuthorization()
        logger.info("Authorization status: \(self.authorizationStatus.rawValue)")

        switch authorizationStatus {
        case .authorized, .limited:
            assets = await photoIndexer.fetchPhotos()
        case .denied, .restricted:
            errorMessage = "Wanderback a besoin d'accéder à vos photos pour fonctionner. Autorisez l'accès dans Réglages > Confidentialité > Photos."
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}
