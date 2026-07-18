import Foundation
import MapKit

/// Préchauffe MapKit pendant que le joueur regarde la photo du round :
/// la première création d'une carte dans le process (shaders Metal,
/// ressources GeoCodec) et le téléchargement des tuiles de la région
/// révélée se font en avance, au lieu de provoquer un écran vide à
/// l'apparition de RevealView.
@MainActor
final class MapPrefetcher {
    static let shared = MapPrefetcher()

    private var currentTask: Task<Void, Never>?

    private init() {}

    /// Lance en tâche de fond un snapshot de la région du lieu à révéler.
    /// Le résultat est jeté — seul l'effet de cache compte.
    func prefetch(for cluster: LocationCluster) {
        currentTask?.cancel()
        currentTask = Task {
            let configuration = MKStandardMapConfiguration(elevationStyle: .realistic)
            configuration.pointOfInterestFilter = .excludingAll

            let options = MKMapSnapshotter.Options()
            options.region = MKCoordinateRegion(
                center: cluster.centerCoordinate,
                latitudinalMeters: 300_000,
                longitudinalMeters: 300_000
            )
            options.size = CGSize(width: 480, height: 270)
            options.preferredConfiguration = configuration

            _ = try? await MKMapSnapshotter(options: options).start()
        }
    }
}
