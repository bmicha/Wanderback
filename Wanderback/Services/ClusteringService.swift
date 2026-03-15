import Foundation
import CoreLocation
import os

class ClusteringService {
    private let logger = Logger(subsystem: "com.bastien.Wanderback", category: "ClusteringService")

    /// Rayon DBSCAN en mètres (5 km)
    static let clusterRadius: CLLocationDistance = 5_000

    /// Minimum de clusters requis pour jouer
    static let minimumClusters = 4

    func clusterPhotos(_ photos: [PhotoLocation]) -> [LocationCluster] {
        let clusters = dbscan(photos: photos, radius: Self.clusterRadius)
        logger.info("Created \(clusters.count) clusters from \(photos.count) photos")
        return clusters
    }

    // MARK: - DBSCAN

    private func dbscan(photos: [PhotoLocation], radius: CLLocationDistance) -> [LocationCluster] {
        var visited = Set<String>()
        var clusters: [LocationCluster] = []

        for photo in photos {
            guard !visited.contains(photo.id) else { continue }
            visited.insert(photo.id)

            let neighbors = regionQuery(photo: photo, photos: photos, radius: radius)
            var clusterPhotos = neighbors

            // Expand cluster
            var queue = neighbors.filter { !visited.contains($0.id) }
            while !queue.isEmpty {
                let current = queue.removeFirst()
                guard !visited.contains(current.id) else { continue }
                visited.insert(current.id)

                let currentNeighbors = regionQuery(photo: current, photos: photos, radius: radius)
                for neighbor in currentNeighbors {
                    if !visited.contains(neighbor.id) {
                        queue.append(neighbor)
                    }
                    if !clusterPhotos.contains(where: { $0.id == neighbor.id }) {
                        clusterPhotos.append(neighbor)
                    }
                }
            }

            let center = centroid(of: clusterPhotos)
            let cluster = LocationCluster(
                id: UUID(),
                centerCoordinate: center,
                photos: clusterPhotos,
                displayName: "",
                country: ""
            )
            clusters.append(cluster)
        }

        return clusters
    }

    private func regionQuery(
        photo: PhotoLocation,
        photos: [PhotoLocation],
        radius: CLLocationDistance
    ) -> [PhotoLocation] {
        let location = CLLocation(latitude: photo.coordinate.latitude, longitude: photo.coordinate.longitude)
        return photos.filter { other in
            let otherLocation = CLLocation(latitude: other.coordinate.latitude, longitude: other.coordinate.longitude)
            return location.distance(from: otherLocation) <= radius
        }
    }

    private func centroid(of photos: [PhotoLocation]) -> CLLocationCoordinate2D {
        let totalLat = photos.reduce(0.0) { $0 + $1.coordinate.latitude }
        let totalLon = photos.reduce(0.0) { $0 + $1.coordinate.longitude }
        let count = Double(photos.count)
        return CLLocationCoordinate2D(latitude: totalLat / count, longitude: totalLon / count)
    }
}
