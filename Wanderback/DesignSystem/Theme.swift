import SwiftUI

/// Tokens du design system Wanderback (handoff « game-show » indigo / ambre→rose).
/// Mesures définies sur canvas 1920×1080 (tvOS standard).
enum Theme {
    // MARK: - Couleurs

    /// Haut du fond de scène
    static let backgroundTop = Color(hex: 0x232048)
    /// Bas du fond de scène
    static let backgroundBottom = Color(hex: 0x131226)
    /// Accent ambre (chrono, score, dégradés)
    static let amber = Color(hex: 0xE3A44F)
    /// Accent rose (toujours pairé avec l'ambre)
    static let rose = Color(hex: 0xE88BC4)
    /// Badge bonne réponse
    static let success = Color(hex: 0x4CC98A)
    /// Badge mauvaise réponse, pins de carte
    static let error = Color(hex: 0xE86A5A)
    /// Texte sombre sur fond clair (focus, CTA)
    static let inkDark = Color(hex: 0x131226)

    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.45)

    /// Surface des cartes réponse — volontairement très translucide pour laisser
    /// transparaître la photo du round (le blur du matériau assure la lisibilité)
    static let answerSurface = Color(red: 22 / 255, green: 20 / 255, blue: 42 / 255).opacity(0.4)
    static let answerBorder = Color.white.opacity(0.14)

    // MARK: - Dégradés

    /// Dégradé signature ambre → rose (90°)
    static let signatureGradient = LinearGradient(
        colors: [amber, rose],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Tuile mode Souvenir : violet-rose sombre, 160°
    static let souvenirTileGradient = LinearGradient(
        colors: [Color(hex: 0x8A4A78), Color(hex: 0x5A3050)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Tuile mode Challenge : ambre sombre, 160°
    static let challengeTileGradient = LinearGradient(
        colors: [Color(hex: 0x9A6B2A), Color(hex: 0x63451B)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Ombres

    static let focusShadow = Color.black.opacity(0.6)
    static let tileShadow = Color.black.opacity(0.45)
    static let ctaHalo = rose.opacity(0.4)

    /// Durée standard des transitions de focus (180 ms)
    static let focusAnimation = Animation.easeOut(duration: 0.18)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Fond de scène

/// Fond radial commun à tous les écrans : #232048 (haut) vers #131226.
struct SceneBackground: View {
    var body: some View {
        RadialGradient(
            colors: [Theme.backgroundTop, Theme.backgroundBottom],
            center: .init(x: 0.5, y: 0.25),
            startRadius: 0,
            endRadius: 1400
        )
        .ignoresSafeArea()
    }
}

// MARK: - Styles de boutons

/// Pilule dégradé signature (CTA « C'EST PARTI », « Round suivant », « Rejouer »).
struct GradientPillButtonStyle: ButtonStyle {
    var horizontalPadding: CGFloat = 104
    var verticalPadding: CGFloat = 24
    var fontSize: CGFloat = 32

    func makeBody(configuration: Configuration) -> some View {
        GradientPillLabel(
            configuration: configuration,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            fontSize: fontSize
        )
    }

    private struct GradientPillLabel: View {
        @Environment(\.isFocused) private var isFocused
        let configuration: ButtonStyle.Configuration
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let fontSize: CGFloat

        var body: some View {
            configuration.label
                .font(.system(size: fontSize, weight: .heavy))
                .foregroundStyle(Theme.inkDark)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .background(Theme.signatureGradient, in: Capsule())
                .shadow(
                    color: isFocused ? Theme.ctaHalo : Theme.ctaHalo.opacity(0.5),
                    radius: 25, y: 20
                )
                .scaleEffect(isFocused ? 1.08 : 1.0)
                .animation(Theme.focusAnimation, value: isFocused)
        }
    }
}

/// Pilule secondaire translucide (« Changer de mode », « Voir comment faire »).
struct SecondaryPillButtonStyle: ButtonStyle {
    var horizontalPadding: CGFloat = 60
    var verticalPadding: CGFloat = 22
    var fontSize: CGFloat = 26

    func makeBody(configuration: Configuration) -> some View {
        SecondaryPillLabel(
            configuration: configuration,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            fontSize: fontSize
        )
    }

    private struct SecondaryPillLabel: View {
        @Environment(\.isFocused) private var isFocused
        let configuration: ButtonStyle.Configuration
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let fontSize: CGFloat

        var body: some View {
            configuration.label
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(isFocused ? Theme.inkDark : .white)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .background(
                    isFocused ? Color.white : Color.white.opacity(0.1),
                    in: Capsule()
                )
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(isFocused ? 0 : 0.2), lineWidth: 3)
                )
                .shadow(color: isFocused ? Theme.focusShadow : .clear, radius: 25, y: 20)
                .scaleEffect(isFocused ? 1.08 : 1.0)
                .animation(Theme.focusAnimation, value: isFocused)
        }
    }
}

/// Texte avec le dégradé signature en masque (logo, score final).
struct GradientText: View {
    let text: String
    let size: CGFloat
    var weight: Font.Weight = .heavy
    var tracking: CGFloat = 0

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: weight))
            .tracking(tracking)
            .foregroundStyle(Theme.signatureGradient)
    }
}
