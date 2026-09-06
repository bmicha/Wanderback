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

    // MARK: - Échelle plateforme

    /// L'UI est calibrée pour un canvas TV 1920×1080 regardé à 3 m ; en fenêtre
    /// Mac (~1280 pt) et sur iPad (~1200-1400 pt) typo et espacements sont
    /// réduits d'un facteur global.
    ///
    /// Sur iPhone, l'homothétie ne tient plus : 393 / 1920 donnerait un titre de
    /// carte réponse à 6 pt. Un téléphone se regarde d'aussi près qu'un iPad, donc
    /// sa typo reste dans les mêmes eaux ; ce qui manque, c'est la largeur — traitée
    /// écran par écran par des layouts fluides, pas par le facteur d'échelle.
    #if os(macOS)
    static let scale: CGFloat = 0.62
    #elseif os(iOS)
    static let scale: CGFloat = Device.isPhone ? 0.58 : 0.7
    #else
    static let scale: CGFloat = 1.0
    #endif
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

extension CGFloat {
    /// Valeur de design (canvas TV) ramenée à l'échelle de la plateforme.
    var scaled: CGFloat { self * Theme.scale }
}

extension Int {
    var scaled: CGFloat { CGFloat(self) * Theme.scale }
}

// MARK: - Fond de scène

/// Fond radial commun à tous les écrans : #232048 (haut) vers #131226.
struct SceneBackground: View {
    var body: some View {
        RadialGradient(
            colors: [Theme.backgroundTop, Theme.backgroundBottom],
            center: .init(x: 0.5, y: 0.25),
            startRadius: 0,
            // Rayon en points bruts : il doit couvrir l'écran, pas le canvas de design
            endRadius: Device.isPhone ? 520 : 1400
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
        @State private var isHovered = false
        let configuration: ButtonStyle.Configuration
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let fontSize: CGFloat

        private var isHighlighted: Bool { isFocused || isHovered || configuration.isPressed }

        var body: some View {
            configuration.label
                .font(.system(size: fontSize.scaled, weight: .heavy))
                .foregroundStyle(Theme.inkDark)
                .padding(.horizontal, horizontalPadding.scaled)
                .padding(.vertical, verticalPadding.scaled)
                .background(Theme.signatureGradient, in: Capsule())
                .shadow(
                    color: isHighlighted ? Theme.ctaHalo : Theme.ctaHalo.opacity(0.5),
                    radius: 25, y: 20
                )
                .scaleEffect(isHighlighted ? 1.08 : 1.0)
                .animation(Theme.focusAnimation, value: isHighlighted)
                #if os(macOS)
                .onHover { isHovered = $0 }
                #endif
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
        @State private var isHovered = false
        let configuration: ButtonStyle.Configuration
        let horizontalPadding: CGFloat
        let verticalPadding: CGFloat
        let fontSize: CGFloat

        private var isHighlighted: Bool { isFocused || isHovered || configuration.isPressed }

        var body: some View {
            configuration.label
                .font(.system(size: fontSize.scaled, weight: .bold))
                .foregroundStyle(isHighlighted ? Theme.inkDark : .white)
                .padding(.horizontal, horizontalPadding.scaled)
                .padding(.vertical, verticalPadding.scaled)
                .background(
                    isHighlighted ? Color.white : Color.white.opacity(0.1),
                    in: Capsule()
                )
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(isHighlighted ? 0 : 0.2), lineWidth: 3)
                )
                .shadow(color: isHighlighted ? Theme.focusShadow : .clear, radius: 25, y: 20)
                .scaleEffect(isHighlighted ? 1.08 : 1.0)
                .animation(Theme.focusAnimation, value: isHighlighted)
                #if os(macOS)
                .onHover { isHovered = $0 }
                #endif
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
            .font(.system(size: size.scaled, weight: weight))
            .tracking(tracking)
            .foregroundStyle(Theme.signatureGradient)
    }
}
