import Foundation
import Photos
import UIKit

/// Charge les images PhotoKit (photo de round plein écran, mosaïque d'accueil, vignettes).
@MainActor
final class PhotoImageLoader {
    static let shared = PhotoImageLoader()

    private let cachingManager = PHCachingImageManager()

    private init() {}

    /// Charge l'image d'un asset par son identifiant local. Retourne nil si introuvable
    /// (cas du mode démo, où les rounds n'ont pas de vraie photo).
    func loadImage(assetIdentifier: String, targetSize: CGSize) async -> UIImage? {
        guard !assetIdentifier.isEmpty else { return nil }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = fetchResult.firstObject else { return nil }
        return await requestImage(for: asset, targetSize: targetSize)
    }

    /// Sélectionne `count` photos au hasard dans la bibliothèque pour la mosaïque d'accueil.
    func loadRandomImages(from locations: [PhotoLocation], count: Int, targetSize: CGSize) async -> [UIImage] {
        let picked = locations.shuffled().prefix(count)
        var images: [UIImage] = []
        for location in picked {
            if let image = await loadImage(assetIdentifier: location.assetIdentifier, targetSize: targetSize) {
                images.append(image)
            }
        }
        return images
    }

    private func requestImage(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .fast

        return await withCheckedContinuation { continuation in
            var didResume = false
            cachingManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                // Avec deliveryMode .highQualityFormat le callback n'est appelé qu'une fois,
                // sauf annulation/erreur — on se protège d'un double resume.
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: image)
            }
        }
    }
}
