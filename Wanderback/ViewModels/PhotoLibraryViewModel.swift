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

    /// Clusters dont le nom de lieu est connu — les seuls utilisables pour une partie.
    var geocodedClusters: [LocationCluster] {
        clusters.filter { !$0.displayName.isEmpty }
    }

    /// Progression du geocoding qui continue derrière l'écran d'accueil.
    /// Nil quand tout est identifié (ou pas encore commencé).
    private(set) var backgroundGeocodingProgress: (done: Int, total: Int)?

    /// Bascule en mode démo avec des destinations fictives (écran « Pas assez de destinations »).
    func startDemoMode() {
        clusters = DemoData.clusters
        photoLocations = clusters.flatMap(\.photos)
        totalPhotoCount = photoLocations.count
        notEnoughPhotos = false
        errorMessage = nil
        currentStep = .ready
        logger.info("Demo mode started with \(self.clusters.count) fake clusters")
    }

    var countryCount: Int {
        Set(clusters.map(\.country)).subtracting([""]).count
    }

    func requestAccessAndLoadPhotos(modelContext: ModelContext) async {
        // Lancement direct en mode démo (dev / démonstration sans bibliothèque photo)
        if ProcessInfo.processInfo.arguments.contains("-demoMode") {
            startDemoMode()
            return
        }

        #if DEBUG
        // Dev uniquement : fige l'écran de chargement pour vérification visuelle
        if let flagIndex = ProcessInfo.processInfo.arguments.firstIndex(of: "-screen"),
           ProcessInfo.processInfo.arguments.dropFirst(flagIndex + 1).first == "loading" {
            totalPhotoCount = 1247
            photoLocations = DemoData.clusters.flatMap(\.photos)
            currentStep = .geocoding(current: 14, total: 23)
            return
        }
        #endif

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

        // Step 4: Geocoding — trier par taille (plus gros clusters d'abord).
        // Dès que `minimumGeocodedForPlay` lieux sont identifiés on passe en `.ready`
        // (l'accueil s'affiche) et le reste continue en arrière-plan : la progression
        // va alors dans `backgroundGeocodingProgress`, plus jamais dans `currentStep`.
        let sortedIndices = clusters.indices.sorted { clusters[$0].photoCount > clusters[$1].photoCount }
        let minimumGeocodedForPlay = 10
        let totalToGeocode = clusters.count
        var attemptedCount = 0

        currentStep = .geocoding(current: 0, total: totalToGeocode)
        logger.info("Step: geocoding \(totalToGeocode) clusters (play after \(minimumGeocodedForPlay))")

        for i in sortedIndices {
            let coord = clusters[i].centerCoordinate
            if let cache = await geocoderService.reverseGeocode(coordinate: coord, modelContext: modelContext) {
                clusters[i].displayName = cache.displayName
                clusters[i].country = cache.country
            }
            attemptedCount += 1

            if isReady {
                backgroundGeocodingProgress = (done: attemptedCount, total: totalToGeocode)
            } else {
                currentStep = .geocoding(current: attemptedCount, total: totalToGeocode)
                // Assez de lieux identifiés (les échecs ne comptent pas) : on peut jouer
                if geocodedClusters.count >= minimumGeocodedForPlay {
                    currentStep = .ready
                    backgroundGeocodingProgress = (done: attemptedCount, total: totalToGeocode)
                    logger.info("Step: ready — \(attemptedCount)/\(totalToGeocode) geocoded, \(self.countryCount) countries")
                }
            }
        }

        backgroundGeocodingProgress = nil
        logger.info("Geocoding complete: \(self.geocodedClusters.count)/\(totalToGeocode) identified")

        // Moins de `minimumGeocodedForPlay` clusters au total : on est prêt maintenant
        if !isReady {
            // Trop d'échecs de geocoding pour générer des questions (4 options minimum)
            if geocodedClusters.count < ClusteringService.minimumClusters {
                notEnoughPhotos = true
                logger.warning("Not enough geocoded clusters: \(self.geocodedClusters.count)")
                return
            }
            currentStep = .ready
            logger.info("Step: ready — \(self.geocodedClusters.count) clusters geocoded, \(self.countryCount) countries")
        }
    }
}
