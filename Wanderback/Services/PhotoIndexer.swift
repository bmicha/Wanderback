import Foundation
import Photos
import CoreLocation
import os

class PhotoIndexer {
    private let logger = Logger(subsystem: "com.bastien.Wanderback", category: "PhotoIndexer")

    static let minimumDistinctLocations = 4

    func requestAuthorization() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    func fetchPhotos() async -> [PHAsset] {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let results = PHAsset.fetchAssets(with: fetchOptions)
        var assets: [PHAsset] = []
        results.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        logger.info("Found \(assets.count) photos in library")
        return assets
    }

    func filterPhotosWithGPS(from assets: [PHAsset]) -> [PhotoLocation] {
        var locations: [PhotoLocation] = []

        for asset in assets {
            guard let location = asset.location else { continue }
            let coord = location.coordinate

            // Exclure coordonnées (0,0) ou aberrantes
            guard isValidCoordinate(coord) else { continue }

            let photoLocation = PhotoLocation(
                id: asset.localIdentifier,
                coordinate: coord,
                dateTaken: asset.creationDate ?? .now,
                assetIdentifier: asset.localIdentifier
            )
            locations.append(photoLocation)
        }

        logger.info("\(locations.count) photos with GPS / \(assets.count) total")
        return locations
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
