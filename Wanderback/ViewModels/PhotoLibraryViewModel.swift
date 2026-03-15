import Foundation
import Photos
import SwiftData
import CoreLocation
import os

enum IndexingStep: Equatable {
    case requestingAccess
    case scanningPhotos
    case clusteringLocations
    case geocoding(current: Int, total: Int)
    case ready

    var label: String {
        switch self {
        case .requestingAccess: return "Demande d'accès aux photos..."
        case .scanningPhotos: return "Analyse des photos..."
        case .clusteringLocations: return "Regroupement des lieux..."
        case .geocoding(let current, let total): return "Identification des lieux... (\(current)/\(total))"
        case .ready: return "Prêt !"
        }
    }

    var progress: Double? {
        switch self {
        case .geocoding(let current, let total) where total > 0:
            return Double(current) / Double(total)
        case .ready:
            return 1.0
        default:
            return nil
        }
    }
}

@Observable
class PhotoLibraryViewModel {
    var authorizationStatus: PHAuthorizationStatus = .notDetermined
    var photoLocations: [PhotoLocation] = []
    var clusters: [LocationCluster] = []
    var totalPhotoCount = 0
    var isLoading = false
    var currentStep: IndexingStep = .requestingAccess
    var errorMessage: String?
    var notEnoughPhotos = false

    private let photoIndexer = PhotoIndexer()
    private let clusteringService = ClusteringService()
    private let geocoderService = GeocoderService()
    private let logger = Logger(subsystem: "com.bastien.Wanderback", category: "PhotoLibraryVM")

    var hasAccess: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    var isReady: Bool {
        if case .ready = currentStep { return true }
        return false
    }

    var gpsStatsText: String {
        "\(photoLocations.count) photos avec GPS / \(totalPhotoCount) total"
    }

    var clusterCount: Int { clusters.count }

    var countryCount: Int {
        Set(clusters.map(\.country)).subtracting([""]).count
    }

    func requestAccessAndLoadPhotos(modelContext: ModelContext) async {
        isLoading = true
        defer { isLoading = false }

        // Step 1: Permission
        currentStep = .requestingAccess
        authorizationStatus = await photoIndexer.requestAuthorization()
        logger.info("Authorization status: \(self.authorizationStatus.rawValue)")

        switch authorizationStatus {
        case .authorized, .limited:
            break
        case .denied, .restricted:
            errorMessage = "Wanderback a besoin d'accéder à vos photos pour fonctionner. Autorisez l'accès dans Réglages > Confidentialité > Photos."
            return
        case .notDetermined:
            return
        @unknown default:
            return
        }

        // Step 2: Index photos (heavy sync work — run off main thread)
        currentStep = .scanningPhotos
        let result = await Task.detached { [photoIndexer] in
            await photoIndexer.indexPhotos()
        }.value
        totalPhotoCount = result.totalCount
        photoLocations = result.locations

        if photoLocations.count < PhotoIndexer.minimumDistinctLocations {
            notEnoughPhotos = true
            logger.warning("Not enough GPS photos: \(self.photoLocations.count)")
            return
        }

        // Step 3: Clustering (heavy sync work — run off main thread)
        currentStep = .clusteringLocations
        let photos = photoLocations
        clusters = await Task.detached { [clusteringService] in
            clusteringService.clusterPhotos(photos)
        }.value

        if clusters.count < ClusteringService.minimumClusters {
            notEnoughPhotos = true
            logger.warning("Not enough clusters: \(self.clusters.count)")
            return
        }

        // Step 4: Geocoding (le plus long — progress par cluster)
        currentStep = .geocoding(current: 0, total: clusters.count)
        for i in clusters.indices {
            let coord = clusters[i].centerCoordinate
            if let cache = await geocoderService.reverseGeocode(coordinate: coord, modelContext: modelContext) {
                clusters[i].displayName = cache.displayName
                clusters[i].country = cache.country
            }
            currentStep = .geocoding(current: i + 1, total: clusters.count)
        }

        // Step 5: Ready
        currentStep = .ready
        logger.info("Indexing complete: \(self.clusters.count) clusters, \(self.countryCount) countries")
    }
}
