import Foundation
import Photos
import CoreLocation
import os

class PhotoIndexer {
    private let logger = Logger(subsystem: "com.bastien.Wanderback", category: "PhotoIndexer")

    static let minimumDistinctLocations = 4

    struct IndexResult {
        let locations: [PhotoLocation]
        let totalCount: Int
    }

    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func indexPhotos() async -> IndexResult {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let results = PHAsset.fetchAssets(with: fetchOptions)
        let totalCount = results.count
        var locations: [PhotoLocation] = []

        results.enumerateObjects { [self] asset, _, _ in
            guard let location = asset.location else { return }
            let coord = location.coordinate
            guard isValidCoordinate(coord) else { return }

            locations.append(PhotoLocation(
                id: asset.localIdentifier,
                coordinate: coord,
                dateTaken: asset.creationDate ?? .now,
                assetIdentifier: asset.localIdentifier
            ))
        }

        logger.info("\(locations.count) photos with GPS / \(totalCount) total")
        return IndexResult(locations: locations, totalCount: totalCount)
    }

    private func isValidCoordinate(_ coord: CLLocationCoordinate2D) -> Bool {
        // Exclure (0,0) — point "Null Island"
        if abs(coord.latitude) < 0.001 && abs(coord.longitude) < 0.001 {
            return false
        }
        // Vérifier les bornes valides
        return coord.latitude >= -90 && coord.latitude <= 90
            && coord.longitude >= -180 && coord.longitude <= 180
    }
}
