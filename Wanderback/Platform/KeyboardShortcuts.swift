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
}
