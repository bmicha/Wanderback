import SwiftUI

extension View {
    /// Raccourci clavier macOS sans modificateur ; no-op sur tvOS.
    @ViewBuilder
    func macKeyboardShortcut(_ key: Character) -> some View {
        #if os(macOS)
        self.keyboardShortcut(KeyEquivalent(key), modifiers: [])
        #else
        self
        #endif
    }

    /// Touche Entrée (action par défaut) sur macOS ; no-op sur tvOS.
    @ViewBuilder
    func macDefaultActionShortcut() -> some View {
        #if os(macOS)
        self.keyboardShortcut(.defaultAction)
        #else
        self
        #endif
    }

    /// Touche Échap (action d'annulation) sur macOS ; no-op sur tvOS, où `onExitCommand`
    /// gère déjà le bouton Menu de la télécommande.
    @ViewBuilder
    func macCancelShortcut(_ action: @escaping () -> Void) -> some View {
        #if os(macOS)
        self.background {
            Button("", action: action)
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        #else
        self
        #endif
    }

}
