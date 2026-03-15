import Foundation
import Photos
import SwiftData
import CoreLocation
import os

enum IndexingStep: Equatable {
    case requestingAccess
    case scanningPhotos
    case clusteringLocations(current: Int, total: Int)
    case geocoding(current: Int, total: Int)
    case ready

    var label: String {
        switch self {
        case .requestingAccess: return "Demande d'accès aux photos..."
        case .scanningPhotos: return "Analyse des photos..."
        case .clusteringLocations(let current, let total): return "Regroupement des lieux... (\(current)/\(total))"
        case .geocoding(let current, let total): return "Identification des lieux... (\(current)/\(total))"
        case .ready: return "Prêt !"
        }
    }

    var progress: Double? {
        switch self {
        case .clusteringLocations(let current, let total) where total > 0:
            return Double(current) / Double(total)
        case .geocoding(let current, let total) where total > 0:
            return Double(current) / Double(total)
        case .ready:
            return 1.0
        default:
            return nil
        }
    }
}

@MainActor
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
        logger.info("Step: requestingAccess")
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

        // Step 2: Index photos
        currentStep = .scanningPhotos
        logger.info("Step: scanningPhotos")
        await Task.yield()

        let indexer = photoIndexer
        let result = await Task.detached {
            await indexer.indexPhotos()
        }.value

        totalPhotoCount = result.totalCount
        photoLocations = result.locations
        logger.info("UI state: \(self.photoLocations.count) photos, \(self.totalPhotoCount) total")

        if photoLocations.count < PhotoIndexer.minimumDistinctLocations {
            notEnoughPhotos = true
            logger.warning("Not enough GPS photos: \(self.photoLocations.count)")
            return
        }

        // Step 3: Clustering
        let photoCount = photoLocations.count
        currentStep = .clusteringLocations(current: 0, total: photoCount)
        logger.info("Step: clusteringLocations (\(photoCount) photos)")
        await Task.yield()

        let startTime = CFAbsoluteTimeGetCurrent()
        clusters = await clusteringService.clusterPhotos(photoLocations) { [weak self] current, total in
            self?.currentStep = .clusteringLocations(current: current, total: total)
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("Clustering done in \(elapsed)s → \(self.clusters.count) clusters")

        if clusters.count < ClusteringService.minimumClusters {
            notEnoughPhotos = true
            logger.warning("Not enough clusters: \(self.clusters.count)")
            return
        }

        // Step 4: Geocoding — trier par taille (plus gros clusters d'abord)
        let sortedIndices = clusters.indices.sorted { clusters[$0].photoCount > clusters[$1].photoCount }
        let minimumGeocodedForPlay = 20
        let totalToGeocode = clusters.count
        var geocodedCount = 0

        currentStep = .geocoding(current: 0, total: totalToGeocode)
        logger.info("Step: geocoding \(totalToGeocode) clusters (play after \(minimumGeocodedForPlay))")

        for i in sortedIndices {
            let coord = clusters[i].centerCoordinate
            if let cache = await geocoderService.reverseGeocode(coordinate: coord, modelContext: modelContext) {
                clusters[i].displayName = cache.displayName
                clusters[i].country = cache.country
            }
            geocodedCount += 1
            currentStep = .geocoding(current: geocodedCount, total: totalToGeocode)

            // Dès qu'on a assez de clusters géocodés, passer en mode prêt
            if geocodedCount == minimumGeocodedForPlay {
                currentStep = .ready
                logger.info("Step: ready — \(geocodedCount)/\(totalToGeocode) geocoded, \(self.countryCount) countries")
            }
        }

        // Fin du geocoding complet en arrière-plan
        if geocodedCount > minimumGeocodedForPlay {
            logger.info("Background geocoding complete: \(geocodedCount)/\(totalToGeocode)")
        }

        // Si moins de 20 clusters au total, on est prêt maintenant
        if !isReady {
            currentStep = .ready
            logger.info("Step: ready — \(geocodedCount) clusters geocoded, \(self.countryCount) countries")
        }
    }
}
