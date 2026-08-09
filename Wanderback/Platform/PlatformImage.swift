import SwiftUI

#if os(macOS)
import AppKit
/// Type d'image natif de la plateforme (NSImage sur macOS, UIImage ailleurs).
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

extension Image {
    /// Construit une Image SwiftUI depuis le type d'image natif de la plateforme.
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}
