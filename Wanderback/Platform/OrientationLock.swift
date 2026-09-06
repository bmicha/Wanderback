#if os(iOS)
import UIKit

/// L'Info.plist déclare les 4 orientations pour l'iPad — exigence App Store pour le
/// multitâche (ITMS-90474) — et le portrait seul pour l'iPhone. Ce délégué verrouille
/// l'orientation à l'exécution en plein écran : portrait sur iPhone, paysage sur iPad,
/// chaque design n'étant dessiné que pour l'une des deux. En fenêtre iPadOS 26,
/// l'orientation ne s'applique pas et le redimensionnement reste libre.
final class OrientationLockDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        Device.isPhone ? .portrait : .landscape
    }
}
#endif
