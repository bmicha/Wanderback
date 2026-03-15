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

    // MARK: - Spatial Grid

    private struct GridCell: Hashable {
        let row: Int
        let col: Int
    }

    private func buildGrid(photos: [PhotoLocation], cellDegrees: Double) -> [GridCell: [PhotoLocation]] {
        var grid: [GridCell: [PhotoLocation]] = [:]
        for photo in photos {
            let cell = gridCell(for: photo.coordinate, cellDegrees: cellDegrees)
            grid[cell, default: []].append(photo)
        }
        return grid
    }

    private func gridCell(for coordinate: CLLocationCoordinate2D, cellDegrees: Double) -> GridCell {
        GridCell(
            row: Int(floor(coordinate.latitude / cellDegrees)),
            col: Int(floor(coordinate.longitude / cellDegrees))
        )
    }

    private func neighborCells(for coordinate: CLLocationCoordinate2D, cellDegrees: Double, radius: CLLocationDistance) -> [GridCell] {
        let centerRow = Int(floor(coordinate.latitude / cellDegrees))
        let centerCol = Int(floor(coordinate.longitude / cellDegrees))

        // Nombre de cellules en longitude pour couvrir le rayon
        let cosLat = cos(coordinate.latitude * .pi / 180.0)
        let lonCells: Int
        if cosLat > 0.001 {
            let lonDegrees = radius / (111_000.0 * cosLat)
            lonCells = max(1, Int(ceil(lonDegrees / cellDegrees)))
        } else {
            // Près des pôles, vérifier une large bande
            lonCells = 10
        }

        var cells: [GridCell] = []
        for dr in -1...1 {
            for dc in -lonCells...lonCells {
                cells.append(GridCell(row: centerRow + dr, col: centerCol + dc))
            }
        }
        return cells
    }

    // MARK: - DBSCAN

    private func dbscan(photos: [PhotoLocation], radius: CLLocationDistance) -> [LocationCluster] {
        let cellDegrees = radius / 111_000.0
        let grid = buildGrid(photos: photos, cellDegrees: cellDegrees)

        var visited = Set<String>()
        var clusters: [LocationCluster] = []

        for photo in photos {
            guard !visited.contains(photo.id) else { continue }
            visited.insert(photo.id)

            let neighbors = regionQuery(photo: photo, grid: grid, cellDegrees: cellDegrees, radius: radius)
            var clusterPhotos = neighbors

            // Expand cluster
            var queue = neighbors.filter { !visited.contains($0.id) }
            while !queue.isEmpty {
                let current = queue.removeFirst()
                guard !visited.contains(current.id) else { continue }
                visited.insert(current.id)

                let currentNeighbors = regionQuery(photo: current, grid: grid, cellDegrees: cellDegrees, radius: radius)
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
        grid: [GridCell: [PhotoLocation]],
        cellDegrees: Double,
        radius: CLLocationDistance
    ) -> [PhotoLocation] {
        let location = CLLocation(latitude: photo.coordinate.latitude, longitude: photo.coordinate.longitude)
        let cells = neighborCells(for: photo.coordinate, cellDegrees: cellDegrees, radius: radius)

        var results: [PhotoLocation] = []
        for cell in cells {
            guard let candidates = grid[cell] else { continue }
            for candidate in candidates {
                let candidateLocation = CLLocation(latitude: candidate.coordinate.latitude, longitude: candidate.coordinate.longitude)
                if location.distance(from: candidateLocation) <= radius {
                    results.append(candidate)
                }
            }
        }
        return results
    }

    private func centroid(of photos: [PhotoLocation]) -> CLLocationCoordinate2D {
        let totalLat = photos.reduce(0.0) { $0 + $1.coordinate.latitude }
        let totalLon = photos.reduce(0.0) { $0 + $1.coordinate.longitude }
        let count = Double(photos.count)
        return CLLocationCoordinate2D(latitude: totalLat / count, longitude: totalLon / count)
    }
}
