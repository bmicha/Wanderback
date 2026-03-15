import Foundation
import CoreLocation
import os

class ClusteringService {
    private let logger = Logger(subsystem: "com.bastien.Wanderback", category: "ClusteringService")

    /// Rayon DBSCAN en mètres (5 km)
    static let clusterRadius: CLLocationDistance = 5_000

    /// Minimum de clusters requis pour jouer
    static let minimumClusters = 4

    /// Fréquence des yields pendant le DBSCAN (toutes les N photos visitées)
    private static let yieldInterval = 200

    func clusterPhotos(
        _ photos: [PhotoLocation],
        onProgress: ((Int, Int) -> Void)? = nil
    ) async -> [LocationCluster] {
        let clusters = await dbscan(photos: photos, radius: Self.clusterRadius, onProgress: onProgress)
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

    private func neighborCells(for coordinate: CLLocationCoordinate2D, cellDegrees: Double, radiusMeters: CLLocationDistance) -> [GridCell] {
        let centerRow = Int(floor(coordinate.latitude / cellDegrees))
        let centerCol = Int(floor(coordinate.longitude / cellDegrees))

        let cosLat = cos(coordinate.latitude * .pi / 180.0)
        let lonCells: Int
        if cosLat > 0.001 {
            let lonDegrees = radiusMeters / (111_000.0 * cosLat)
            lonCells = max(1, Int(ceil(lonDegrees / cellDegrees)))
        } else {
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

    private func dbscan(
        photos: [PhotoLocation],
        radius: CLLocationDistance,
        onProgress: ((Int, Int) -> Void)?
    ) async -> [LocationCluster] {
        let cellDegrees = radius / 111_000.0
        let radiusSquaredDeg = cellDegrees * cellDegrees
        let grid = buildGrid(photos: photos, cellDegrees: cellDegrees)
        let total = photos.count

        var visited = Set<String>()
        var clusters: [LocationCluster] = []
        var progressCount = 0

        for photo in photos {
            guard !visited.contains(photo.id) else { continue }
            visited.insert(photo.id)

            let neighbors = regionQuery(photo: photo, grid: grid, cellDegrees: cellDegrees, radiusSquaredDeg: radiusSquaredDeg)
            var clusterPhotos = neighbors
            var clusterIds = Set(neighbors.map(\.id))

            // Expand cluster (with dedup to avoid queue explosion)
            var queued = Set(neighbors.filter { !visited.contains($0.id) }.map(\.id))
            var queue = neighbors.filter { queued.contains($0.id) }
            var expandCount = 0
            while !queue.isEmpty {
                let current = queue.removeFirst()
                guard !visited.contains(current.id) else { continue }
                visited.insert(current.id)

                let currentNeighbors = regionQuery(photo: current, grid: grid, cellDegrees: cellDegrees, radiusSquaredDeg: radiusSquaredDeg)
                for neighbor in currentNeighbors {
                    if !visited.contains(neighbor.id) && !queued.contains(neighbor.id) {
                        queue.append(neighbor)
                        queued.insert(neighbor.id)
                    }
                    if !clusterIds.contains(neighbor.id) {
                        clusterIds.insert(neighbor.id)
                        clusterPhotos.append(neighbor)
                    }
                }

                // Yield during large cluster expansion
                expandCount += 1
                if expandCount % Self.yieldInterval == 0 {
                    onProgress?(visited.count, total)
                    await Task.yield()
                }
            }

            let center = centroid(of: clusterPhotos)
            clusters.append(LocationCluster(
                id: UUID(),
                centerCoordinate: center,
                photos: clusterPhotos,
                displayName: "",
                country: ""
            ))

            // Report progress and yield periodically
            progressCount += clusterPhotos.count
            if progressCount % Self.yieldInterval < clusterPhotos.count {
                onProgress?(visited.count, total)
                await Task.yield()
            }
        }

        onProgress?(total, total)
        return clusters
    }

    private func regionQuery(
        photo: PhotoLocation,
        grid: [GridCell: [PhotoLocation]],
        cellDegrees: Double,
        radiusSquaredDeg: Double
    ) -> [PhotoLocation] {
        let lat1 = photo.coordinate.latitude
        let lon1 = photo.coordinate.longitude
        let cosLat = cos(lat1 * .pi / 180.0)
        let cells = neighborCells(for: photo.coordinate, cellDegrees: cellDegrees, radiusMeters: sqrt(radiusSquaredDeg) * 111_000)

        var results: [PhotoLocation] = []
        for cell in cells {
            guard let candidates = grid[cell] else { continue }
            for candidate in candidates {
                let dLat = candidate.coordinate.latitude - lat1
                let dLon = (candidate.coordinate.longitude - lon1) * cosLat
                if dLat * dLat + dLon * dLon <= radiusSquaredDeg {
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
