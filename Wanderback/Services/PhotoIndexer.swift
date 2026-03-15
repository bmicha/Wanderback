import Foundation
import Photos
import os

class PhotoIndexer {
    private let logger = Logger(subsystem: "com.bastien.Wanderback", category: "PhotoIndexer")

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
}
