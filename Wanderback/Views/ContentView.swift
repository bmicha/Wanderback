import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var photoViewModel = PhotoLibraryViewModel()
    @State private var gameViewModel = GameViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            SceneBackground()
            content
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.35), value: gameViewModel.phase)
        .task {
            await photoViewModel.requestAccessAndLoadPhotos(modelContext: modelContext)
            jumpToScreenIfRequested()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let error = photoViewModel.errorMessage {
            errorView(message: error)
        } else if photoViewModel.notEnoughPhotos {
            NotEnoughPlacesView(viewModel: photoViewModel)
        } else if gameViewModel.session != nil {
            gameFlow
        } else if photoViewModel.isReady {
            HomeView(viewModel: photoViewModel) { mode, roundCount in
                // Seuls les lieux déjà identifiés peuvent servir de question ou d'option
                gameViewModel.startGame(
                    mode: mode,
                    roundCount: roundCount,
                    clusters: photoViewModel.geocodedClusters
                )
            }
        } else {
            LoadingView(viewModel: photoViewModel)
        }
    }

    /// Boucle de jeu : GameView → RevealView (par round) → SummaryView.
    /// Le bouton Menu de la télécommande ramène à l'accueil.
    @ViewBuilder
    private var gameFlow: some View {
        Group {
            switch gameViewModel.phase {
            case .playing:
                GameView(gameViewModel: gameViewModel)
                    .transition(.opacity)
            case .revealing:
                RevealView(gameViewModel: gameViewModel)
                    .transition(.opacity)
            case .finished:
                SummaryView(gameViewModel: gameViewModel) {
                    gameViewModel.quit()
                }
                .transition(.opacity)
            }
        }
        #if !os(iOS)
        .onExitCommand {
            gameViewModel.quit()
        }
        #endif
        #if os(macOS)
        .macCancelShortcut {
            gameViewModel.quit()
        }
        #endif
        #if os(iOS)
        // Ni bouton Menu ni touche Échap sur iPad : croix discrète pour quitter la partie.
        .overlay(alignment: .topLeading) {
            Button {
                gameViewModel.quit()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20.scaled, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(16.scaled)
                    .background(Theme.answerSurface, in: Circle())
                    .overlay(Circle().strokeBorder(Theme.answerBorder, lineWidth: 1))
            }
            .accessibilityLabel("Quitter la partie")
            .padding(24.scaled)
        }
        #endif
    }

    /// Dev uniquement : `-screen game|reveal|summary` saute directement à un écran
    /// (à combiner avec `-demoMode`) pour vérifier visuellement les rendus.
    private func jumpToScreenIfRequested() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "-screen"),
              arguments.count > flagIndex + 1,
              photoViewModel.isReady else { return }

        let target = arguments[flagIndex + 1]
        gameViewModel.startGame(mode: .challenge, roundCount: 3, clusters: photoViewModel.geocodedClusters)

        switch target {
        case "reveal":
            if let round = gameViewModel.currentRound {
                gameViewModel.answer(round.correctAnswer)
            }
        case "summary":
            while gameViewModel.phase != .finished, let round = gameViewModel.currentRound {
                gameViewModel.answer(round.correctAnswer)
                gameViewModel.nextRound()
            }
        default:
            break // "game" : rien à faire, la partie est lancée
        }
        #endif
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 32.scaled) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 120.scaled, height: 120.scaled)
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 48.scaled))
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(message)
                .font(.system(size: 28.scaled))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 200.scaled)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: LocationCache.self)
}
