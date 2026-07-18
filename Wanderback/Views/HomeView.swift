import SwiftUI

struct HomeView: View {
    let viewModel: PhotoLibraryViewModel
    let onPlay: (GameMode, Int) -> Void

    @State private var selectedMode: GameMode = .souvenir
    @State private var selectedRounds: Int = 10
    @State private var mosaicImages: [UIImage] = []
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

            VStack(spacing: 44) {
                header
                modeSelection
                roundsSelection
                statsRow
                playButton
            }
        }
        .defaultFocus($focusedElement, .play)
        .task {
            mosaicImages = await PhotoImageLoader.shared.loadRandomImages(
                from: viewModel.photoLocations,
                count: 10,
                targetSize: CGSize(width: 500, height: 400)
            )
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
            Image(uiImage: mosaicImages[index])
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
        VStack(spacing: 14) {
            GradientText(text: "WANDERBACK", size: 84, tracking: -2)
            Text("Le quiz de VOS voyages")
                .font(.system(size: 27))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Tuiles mode

    private var modeSelection: some View {
        HStack(spacing: 34) {
            ForEach(GameMode.allCases) { mode in
                Button {
                    withAnimation(Theme.focusAnimation) { selectedMode = mode }
                } label: {
                    modeTileLabel(mode)
                }
                .buttonStyle(ModeTileButtonStyle(isSelected: selectedMode == mode, mode: mode))
                .focused($focusedElement, equals: .mode(mode))
            }
        }
    }

    private func modeTileLabel(_ mode: GameMode) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: mode.icon)
                .font(.system(size: 24))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(0.25), in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(mode.title)
                    .font(.system(size: 34, weight: .heavy))
                Text(mode.subtitle)
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .foregroundStyle(.white)
        .frame(width: 500 - 2 * 34, alignment: .leading)
        .padding(34)
    }

    // MARK: - Rounds

    private var roundsSelection: some View {
        HStack(spacing: 28) {
            Text("Rounds")
                .font(.system(size: 24))
                .foregroundStyle(Theme.textSecondary)

            ForEach(roundOptions, id: \.self) { count in
                Button {
                    withAnimation(Theme.focusAnimation) { selectedRounds = count }
                } label: {
                    Text("\(count)")
                        .font(.system(size: 32, weight: .heavy))
                }
                .buttonStyle(RoundCircleButtonStyle(isSelected: selectedRounds == count))
                .focused($focusedElement, equals: .rounds(count))
            }
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 52) {
            Text("\(viewModel.photoLocations.count) photos GPS")
            Text("\(viewModel.clusterCount) lieux")
            Text("\(viewModel.countryCount) pays")
        }
        .font(.system(size: 22))
        .foregroundStyle(Theme.textTertiary)
    }

    // MARK: - CTA

    private var playButton: some View {
        Button {
            onPlay(selectedMode, selectedRounds)
        } label: {
            HStack(spacing: 16) {
                Text("C'EST PARTI")
                    .tracking(2)
                Image(systemName: "play.fill")
                    .font(.system(size: 24))
            }
        }
        .buttonStyle(GradientPillButtonStyle())
        .focused($focusedElement, equals: .play)
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
        let configuration: ButtonStyle.Configuration
        let isSelected: Bool
        let mode: GameMode

        var body: some View {
            configuration.label
                .background(
                    mode == .souvenir ? Theme.souvenirTileGradient : Theme.challengeTileGradient,
                    in: RoundedRectangle(cornerRadius: 28)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(
                            Color.white.opacity(isSelected ? 1 : (isFocused ? 0.5 : 0)),
                            lineWidth: 4
                        )
                )
                .opacity(isSelected || isFocused ? 1 : 0.65)
                .shadow(color: Theme.tileShadow, radius: 30, y: 24)
                .scaleEffect(isFocused ? 1.08 : (isSelected ? 1.04 : 1.0))
                .animation(Theme.focusAnimation, value: isFocused)
                .animation(Theme.focusAnimation, value: isSelected)
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
        let configuration: ButtonStyle.Configuration
        let isSelected: Bool

        var body: some View {
            let highlighted = isSelected || isFocused
            configuration.label
                .foregroundStyle(highlighted ? Theme.inkDark : .white)
                .frame(width: 96, height: 96)
                .background(
                    highlighted ? Color.white : Color.white.opacity(0.08),
                    in: Circle()
                )
                .opacity(highlighted ? 1 : 0.6)
                .shadow(color: isFocused ? Theme.focusShadow : .clear, radius: 25, y: 20)
                .scaleEffect(isFocused ? 1.1 : 1.0)
                .animation(Theme.focusAnimation, value: isFocused)
                .animation(Theme.focusAnimation, value: isSelected)
        }
    }
}

#Preview {
    HomeView(viewModel: PhotoLibraryViewModel()) { _, _ in }
}
