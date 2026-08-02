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
    /// déjà éprouvé que `macCancelShortcut`/`macKeyboardShortcut` dans `KeyboardShortcuts.swift`)
    /// est volontairement conservée : `onMoveCommand` est à re-tester une fois le bug de bêta
    /// corrigé (`.defaultFocus` remplacé par `initialFocus` le réglerait sans doute aussi bien).
    /// Rien ne casse d'ici là ni le jour où la bêta sera corrigée : le contournement devient
    /// simplement inutile.
    ///
    /// Un seul `macMoveCommand` actif à la fois par fenêtre : les raccourcis flèches sont des
    /// équivalents-clavier à l'échelle de la fenêtre, pas des gestes locaux à la vue. Deux vues le
    /// portant simultanément entreraient en conflit à comportement indéfini, et tout futur champ
    /// texte ou vue défilante sur le même écran se verrait voler ses flèches.
    @ViewBuilder
    func macMoveCommand(_ action: @escaping (MoveCommandDirection) -> Void) -> some View {
        self
            .macShortcutAction(.leftArrow) { action(.left) }
            .macShortcutAction(.rightArrow) { action(.right) }
            .macShortcutAction(.upArrow) { action(.up) }
            .macShortcutAction(.downArrow) { action(.down) }
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
    ///
    /// **Doit précéder** `.focused(_:equals:)` dans la chaîne de modificateurs : posé après, le
    /// focus AppKit atterrit dans un wrapper distinct (anneau bleu visible) déconnecté du
    /// `@FocusState`, qui reste à `nil` et n'active jamais le style personnalisé.
    ///
    /// `focusEffectDisabled()` supprime l'anneau de focus bleu standard d'AppKit, qui sinon se
    /// dessine par-dessus notre propre surbrillance (fond blanc / bordure / scale pilotés par
    /// `isFocused`) — deux surbrillances concurrentes sur le même contrôle. Le focus lui-même
    /// (et donc `@FocusState`) reste intact, seul le rendu système est désactivé. Ne s'applique
    /// qu'à macOS : sur tvOS, désactiver l'effet de focus casserait les visuels natifs de la
    /// télécommande.
    @ViewBuilder
    func macFocusable() -> some View {
        #if os(macOS)
        self.focusable()
            .focusEffectDisabled()
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
