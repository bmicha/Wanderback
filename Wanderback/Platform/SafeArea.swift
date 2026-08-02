import SwiftUI

extension View {
    /// Ignore la safe area sur tvOS uniquement — le design TV gère ses marges d'overscan
    /// avec ses propres paddings. Sur macOS le contenu reste dans la safe area, sinon il
    /// passe sous la barre de titre de la fenêtre.
    @ViewBuilder
    func tvIgnoresSafeArea() -> some View {
        #if os(tvOS)
        self.ignoresSafeArea()
        #else
        self
        #endif
    }
}
