#if os(iOS)
import UIKit

/// L'Info.plist déclare les 4 orientations — exigence App Store pour le multitâche
/// iPad (ITMS-90474) — mais le design est paysage seul : ce délégué verrouille le
/// paysage à l'exécution en plein écran. En fenêtre iPadOS 26, l'orientation ne
/// s'applique pas et le redimensionnement reste libre.
final class OrientationLockDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .landscape
    }
}
#endif
