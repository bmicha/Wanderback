import SwiftUI

// Placement et déplacement du focus clavier sur macOS (flèches, survol souris, focus initial) ;
// no-op sur tvOS, où le moteur de focus natif de la télécommande s'en charge déjà.

extension View {
    /// Flèches du clavier sur macOS ; no-op sur tvOS, où le moteur de focus s'en charge.
    ///
    /// `onMoveCommand(perform:)` et `.focusable() + .onKeyPress(.leftArrow)` ont été essayés
    /// d'abord ; les deux semblaient ne jamais être délivrés. En creusant (cf. `initialFocus`
    /// ci-dessous), la vraie cause n'était pas le mécanisme de flèches mais `.defaultFocus` :
    /// tant qu'il reste posé sur la vue, toute réaffectation ultérieure du `@FocusState` — par
    /// n'importe quel mécanisme — est silencieusement annulée et retombe sur la valeur par
    /// défaut. Cette implémentation par bouton invisible + `keyboardShortcut` (même mécanisme
    /// déjà éprouvé que `macCancelShortcut`/`macKeyboardShortcut` ci-dessus) est conservée telle
    /// quelle car elle fonctionne et reste dans le style du fichier, mais `onMoveCommand` aurait
    /// sans doute fonctionné tout aussi bien une fois `.defaultFocus` remplacé par `initialFocus`.
    @ViewBuilder
    func macMoveCommand(_ action: @escaping (MoveCommandDirection) -> Void) -> some View {
        #if os(macOS)
        self.background {
            Group {
                Button("") { action(.left) }.keyboardShortcut(.leftArrow, modifiers: [])
                Button("") { action(.right) }.keyboardShortcut(.rightArrow, modifiers: [])
                Button("") { action(.up) }.keyboardShortcut(.upArrow, modifiers: [])
                Button("") { action(.down) }.keyboardShortcut(.downArrow, modifiers: [])
            }
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
        #else
        self
        #endif
    }

    /// Sur macOS, survoler un contrôle lui donne le focus clavier, pour que la surbrillance
    /// souris et la surbrillance clavier désignent toujours le même élément. No-op sur tvOS.
    @ViewBuilder
    func macFocusOnHover<Value: Hashable>(_ binding: FocusState<Value>.Binding, equals value: Value) -> some View {
        #if os(macOS)
        self.onHover { hovering in
            if hovering { binding.wrappedValue = value }
        }
        #else
        self
        #endif
    }

    /// Rend un contrôle focalisable au clavier sur macOS, indépendamment du réglage système
    /// « Navigation au clavier » (Réglages Système > Clavier > Navigation au clavier) — sans quoi
    /// `@FocusState` ne peut pas poser le focus sur un bouton. No-op sur tvOS, déjà focalisable
    /// nativement par le moteur de focus de la télécommande.
    @ViewBuilder
    func macFocusable() -> some View {
        #if os(macOS)
        self.focusable()
        #else
        self
        #endif
    }

    /// Focus initial d'un écran : `.defaultFocus` sur tvOS (inchangé), `.onAppear` sur macOS.
    ///
    /// Constat empirique : sur cette bêta, tant que `.defaultFocus(_:_:)` reste posé sur la vue,
    /// toute réaffectation ultérieure du même `@FocusState` (flèches, clic, n'importe quel
    /// mécanisme) est silencieusement annulée et la valeur retombe sur celle de `defaultFocus` —
    /// ce qui rendait toute navigation aux flèches impossible après le focus initial. Poser le
    /// focus de départ via `.onAppear` au lieu de `.defaultFocus` évite le problème : la valeur
    /// n'est écrite qu'une fois, sans rester « accrochée ».
    @ViewBuilder
    func initialFocus<Value: Hashable>(_ binding: FocusState<Value>.Binding, _ value: Value) -> some View {
        #if os(macOS)
        self.onAppear { binding.wrappedValue = value }
        #else
        self.defaultFocus(binding, value)
        #endif
    }
}
