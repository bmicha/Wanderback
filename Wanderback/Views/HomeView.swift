import SwiftUI

struct HomeView: View {
    let viewModel: PhotoLibraryViewModel
    let onPlay: (GameMode, Int) -> Void

    @State private var selectedMode: GameMode = .souvenir
    @State private var selectedRounds: Int = 10
    @State private var mosaicImages: [PlatformImage] = []
    @FocusState private var focusedElement: HomeElement?

    private let roundOptions = [5, 10, 20]

    enum HomeElement: Hashable {
        case mode(GameMode)
        case rounds(Int)
        case play
    }

    var body: some View {
        ZStack {
            SceneBackground()
            mosaicBackground

            VStack(spacing: 44.scaled) {
                header
                modeSelection
                roundsSelection
                statsRow
                playButton
            }
            .macMoveCommand(handleMoveCommand)
            // Constaté empiriquement : Espace n'active pas nativement un bouton focalisé ici
            // (contrairement à ce que suggérait le brief) — posé explicitement.
            .macShortcutAction(.space) { activateFocusedElement() }
        }
        .initialFocus($focusedElement, .play)
        .task {
            mosaicImages = await PhotoImageLoader.shared.loadRandomImages(
                from: viewModel.photoLocations,
                count: 10,
                targetSize: CGSize(width: 500, height: 400)
            )
        }
    }

    // MARK: - Navigation clavier macOS

    /// Ordre des rangées : tuiles de mode → rounds → bouton « C'EST PARTI ».
    /// Appelé uniquement sur macOS (cf. `macMoveCommand`) ; tvOS garde son moteur de focus natif.
    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        guard let current = focusedElement else { return }
        switch current {
        case .mode(let mode):
            switch direction {
            case .left, .right:
                let modes = GameMode.allCases
                guard let index = modes.firstIndex(of: mode) else { return }
                let newIndex = direction == .left ? index - 1 : index + 1
                if modes.indices.contains(newIndex) { focusedElement = .mode(modes[newIndex]) }
            case .down:
                focusedElement = .rounds(selectedRounds)
            default:
                break
            }
        case .rounds(let count):
            switch direction {
            case .left, .right:
                guard let index = roundOptions.firstIndex(of: count) else { return }
                let newIndex = direction == .left ? index - 1 : index + 1
                if roundOptions.indices.contains(newIndex) { focusedElement = .rounds(roundOptions[newIndex]) }
            case .up:
                focusedElement = .mode(selectedMode)
            case .down:
                focusedElement = .play
            default:
                break
            }
        case .play:
            if direction == .up {
                focusedElement = .rounds(selectedRounds)
            }
        }
    }

    /// Active l'élément actuellement en surbrillance (Espace) : même effet que cliquer dessus.
    private func activateFocusedElement() {
        guard let current = focusedElement else { return }
        activate(current)
    }

    /// Ce que fait un élément de l'accueil quand on l'active — bouton de tuile cliqué ou
    /// handler Espace : une seule définition, pour que les deux chemins restent identiques.
    private func activate(_ element: HomeElement) {
        switch element {
        case .mode(let mode):
            withAnimation(Theme.focusAnimation) { selectedMode = mode }
        case .rounds(let count):
            withAnimation(Theme.focusAnimation) { selectedRounds = count }
        case .play:
            onPlay(selectedMode, selectedRounds)
        }
    }

    // MARK: - Fond mosaïque

    /// Mosaïque 5×2 des photos de l'utilisateur, opacité 0,6, sous un voile radial sombre.
    private var mosaicBackground: some View {
        GeometryReader { geometry in
            let columns = 5, rows = 2
            let gap: CGFloat = 6
            let cellWidth = (geometry.size.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
            let cellHeight = (geometry.size.height - gap) / CGFloat(rows)

            VStack(spacing: gap) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<columns, id: \.self) { column in
                            mosaicCell(index: row * columns + column)
                                .frame(width: cellWidth, height: cellHeight)
                                .clipped()
                        }
                    }
                }
            }
            .opacity(0.6)
            .overlay(
                RadialGradient(
                    colors: [
                        Color(hex: 0x232048).opacity(0.88),
                        Color(hex: 0x131226).opacity(0.96)
                    ],
                    center: .center,
                    startRadius: 200,
                    endRadius: 1300
                )
            )
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func mosaicCell(index: Int) -> some View {
        if index < mosaicImages.count {
            Image(platformImage: mosaicImages[index])
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            LinearGradient(
                colors: [Theme.backgroundTop, Theme.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14.scaled) {
            GradientText(text: "WANDERBACK", size: 84, tracking: -2)
            Text("Le quiz de VOS voyages")
                .font(.system(size: 27.scaled))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Tuiles mode

    private var modeSelection: some View {
        HStack(spacing: 34.scaled) {
            ForEach(GameMode.allCases) { mode in
                Button {
                    activate(.mode(mode))
                } label: {
                    modeTileLabel(mode)
                }
                .buttonStyle(ModeTileButtonStyle(isSelected: selectedMode == mode, mode: mode))
                .macFocusable()
                .focused($focusedElement, equals: .mode(mode))
                .macFocusOnHover($focusedElement, equals: .mode(mode))
            }
        }
    }

    private func modeTileLabel(_ mode: GameMode) -> some View {
        VStack(alignment: .leading, spacing: 16.scaled) {
            Image(systemName: mode.icon)
                .font(.system(size: 24.scaled))
                .foregroundStyle(.white)
                .frame(width: 52.scaled, height: 52.scaled)
                .background(Color.white.opacity(0.25), in: Circle())

            VStack(alignment: .leading, spacing: 6.scaled) {
                Text(mode.title)
                    .font(.system(size: 34.scaled, weight: .heavy))
                Text(mode.subtitle)
                    .font(.system(size: 22.scaled))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .foregroundStyle(.white)
        .frame(width: (500 - 2 * 34).scaled, alignment: .leading)
        .padding(34.scaled)
    }

    // MARK: - Rounds

    private var roundsSelection: some View {
        HStack(spacing: 28.scaled) {
            Text("Rounds")
                .font(.system(size: 24.scaled))
                .foregroundStyle(Theme.textSecondary)

            ForEach(roundOptions, id: \.self) { count in
                Button {
                    activate(.rounds(count))
                } label: {
                    Text("\(count)")
                        .font(.system(size: 32.scaled, weight: .heavy))
                }
                .buttonStyle(RoundCircleButtonStyle(isSelected: selectedRounds == count))
                .macFocusable()
                .focused($focusedElement, equals: .rounds(count))
                .macFocusOnHover($focusedElement, equals: .rounds(count))
            }
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        VStack(spacing: 10.scaled) {
            HStack(spacing: 52.scaled) {
                Text("\(viewModel.photoLocations.count) photos GPS")
                Text("\(viewModel.geocodedClusters.count) lieux")
                Text("\(viewModel.countryCount) pays")
            }
            .font(.system(size: 22.scaled))
            .foregroundStyle(Theme.textTertiary)

            // Le geocoding continue derrière l'accueil : le compteur de lieux grossit tout seul
            if let progress = viewModel.backgroundGeocodingProgress {
                HStack(spacing: 10.scaled) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Theme.textTertiary)
                    Text("Identification des lieux en cours… \(progress.done)/\(progress.total)")
                }
                .font(.system(size: 19.scaled))
                .foregroundStyle(Theme.textTertiary)
            }
        }
    }

    // MARK: - CTA

    private var playButton: some View {
        Button {
            activate(.play)
        } label: {
            HStack(spacing: 16.scaled) {
                Text("C'EST PARTI")
                    .tracking(2)
                Image(systemName: "play.fill")
                    .font(.system(size: 24.scaled))
            }
        }
        .buttonStyle(GradientPillButtonStyle())
        .macFocusable()
        .focused($focusedElement, equals: .play)
        .macFocusOnHover($focusedElement, equals: .play)
        .macDefaultActionShortcut()
    }
}

// MARK: - Styles

/// Tuile mode 500pt : dégradé sombre par mode, bordure blanche 4pt si sélectionnée.
private struct ModeTileButtonStyle: ButtonStyle {
    let isSelected: Bool
    let mode: GameMode

    func makeBody(configuration: Configuration) -> some View {
        ModeTileLabel(configuration: configuration, isSelected: isSelected, mode: mode)
    }

    private struct ModeTileLabel: View {
        @Environment(\.isFocused) private var isFocused
        @State private var isHovered = false
        let configuration: ButtonStyle.Configuration
        let isSelected: Bool
        let mode: GameMode

        private var isHighlighted: Bool { isFocused || isHovered }

        var body: some View {
            configuration.label
                .background(
                    mode == .souvenir ? Theme.souvenirTileGradient : Theme.challengeTileGradient,
                    in: RoundedRectangle(cornerRadius: 28.scaled)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28.scaled)
                        .strokeBorder(
                            Color.white.opacity(isSelected ? 1 : (isHighlighted ? 0.5 : 0)),
                            lineWidth: 4
                        )
                )
                .opacity(isSelected || isHighlighted ? 1 : 0.65)
                .shadow(color: Theme.tileShadow, radius: 30, y: 24)
                .scaleEffect(isHighlighted ? 1.08 : (isSelected ? 1.04 : 1.0))
                .animation(Theme.focusAnimation, value: isHighlighted)
                .animation(Theme.focusAnimation, value: isSelected)
                #if os(macOS)
                .onHover { isHovered = $0 }
                #endif
        }
    }
}

/// Cercle rounds 96×96 : fond blanc + texte sombre si sélectionné.
private struct RoundCircleButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        RoundCircleLabel(configuration: configuration, isSelected: isSelected)
    }

    private struct RoundCircleLabel: View {
        @Environment(\.isFocused) private var isFocused
        @State private var isHovered = false
        let configuration: ButtonStyle.Configuration
        let isSelected: Bool

        var body: some View {
            let highlighted = isSelected || isFocused || isHovered
            configuration.label
                .foregroundStyle(highlighted ? Theme.inkDark : .white)
                .frame(width: 96.scaled, height: 96.scaled)
                .background(
                    highlighted ? Color.white : Color.white.opacity(0.08),
                    in: Circle()
                )
                .opacity(highlighted ? 1 : 0.6)
                .shadow(color: (isFocused || isHovered) ? Theme.focusShadow : .clear, radius: 25, y: 20)
                .scaleEffect((isFocused || isHovered) ? 1.1 : 1.0)
                .animation(Theme.focusAnimation, value: isFocused)
                .animation(Theme.focusAnimation, value: isSelected)
                .animation(Theme.focusAnimation, value: isHovered)
                #if os(macOS)
                .onHover { isHovered = $0 }
                #endif
        }
    }
}

#Preview {
    HomeView(viewModel: PhotoLibraryViewModel()) { _, _ in }
}
