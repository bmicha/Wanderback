import SwiftUI

struct HomeView: View {
    let viewModel: PhotoLibraryViewModel

    @State private var selectedMode: GameMode = .souvenir
    @State private var selectedRounds: Int = 10
    @FocusState private var focusedElement: HomeElement?

    private let roundOptions = [5, 10, 20]

    enum HomeElement: Hashable {
        case mode(GameMode)
        case rounds(Int)
        case play
    }

    var body: some View {
        VStack(spacing: 50) {
            // Header
            header

            // Stats
            statsRow

            // Mode selection
            modeSelection

            // Rounds selection
            roundsSelection

            // Play button
            playButton
        }
        .padding(80)
        .defaultFocus($focusedElement, .play)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Text("Wanderback")
                .font(.system(size: 60, weight: .bold))
            Text("Devinez où ont été prises vos photos")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 60) {
            statItem(
                icon: "photo.fill",
                value: "\(viewModel.photoLocations.count)",
                label: "photos GPS"
            )
            statItem(
                icon: "mappin.and.ellipse",
                value: "\(viewModel.clusterCount)",
                label: "lieux"
            )
            statItem(
                icon: "flag.fill",
                value: "\(viewModel.countryCount)",
                label: "pays"
            )
        }
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.blue)
            Text(value)
                .font(.system(size: 40, weight: .bold))
            Text(label)
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Mode Selection

    private var modeSelection: some View {
        VStack(spacing: 16) {
            Text("Mode de jeu")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 30) {
                ForEach(GameMode.allCases) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 28))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.title)
                                    .font(.system(size: 28, weight: .semibold))
                                Text(mode.subtitle)
                                    .font(.system(size: 20))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.vertical, 20)
                    }
                    .focused($focusedElement, equals: .mode(mode))
                    .opacity(selectedMode == mode ? 1.0 : 0.5)
                }
            }
        }
    }

    // MARK: - Rounds Selection

    private var roundsSelection: some View {
        VStack(spacing: 16) {
            Text("Nombre de rounds")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 30) {
                ForEach(roundOptions, id: \.self) { count in
                    Button {
                        selectedRounds = count
                    } label: {
                        Text("\(count)")
                            .font(.system(size: 36, weight: .bold))
                            .frame(width: 120, height: 80)
                    }
                    .focused($focusedElement, equals: .rounds(count))
                    .opacity(selectedRounds == count ? 1.0 : 0.5)
                }
            }
        }
    }

    // MARK: - Play Button

    private var playButton: some View {
        Button {
            // TODO: Navigation vers GameView (issue #8)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.system(size: 28))
                Text("Jouer")
                    .font(.system(size: 32, weight: .bold))
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 20)
        }
        .focused($focusedElement, equals: .play)
    }
}
