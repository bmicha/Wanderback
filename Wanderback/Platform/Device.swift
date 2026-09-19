#if os(iOS)
import UIKit
#endif

/// Distinctions d'appareil qui ne peuvent pas se faire à la compilation : depuis le
/// portage iPhone, iPhone et iPad partagent le même binaire iOS, donc aucun `#if` ne
/// les sépare. Un seul point de vérité, pour que les vues partagées puissent écrire
/// `if Device.isPhone` sans `#if` autour et garder des branches de layout lisibles.
enum Device {
    /// Vrai uniquement sur iPhone. Faux sur iPad, Mac et Apple TV.
    static let isPhone: Bool = {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }()
}
