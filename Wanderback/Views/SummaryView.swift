import SwiftUI
import MapKit

struct SummaryView: View {
    let gameViewModel: GameViewModel
    /// Retour à l'accueil pour changer de mode
    let onChangeMode: () -> Void

    @FocusState private var replayFocused: Bool

    private var rounds: [GameRound] { gameViewModel.session?.rounds ?? [] }

    var body: some View {
        ZStack {
            worldMap
            mapVeil

            VStack(spacing: 36) {
                Spacer()

                VStack(spacing: 10) {
                    Text("Partie terminée !")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)

                    GradientText(text: finalScoreText, size: 96)

                    Text(scoreSubtitle)
                        .font(.system(size: 26))
                        .foregroundStyle(Theme.textSecondary)
                }

                statsLine

                HStack(spacing: 30) {
                    Button {
                        gameViewModel.replay()
                    } label: {
                        HStack(spacing: 14) {
                            Text("Rejouer")
                            Image(systemName: "play.fill")
                                .font(.system(size: 20))
                        }
                    }
                    .buttonStyle(GradientPillButtonStyle(horizontalPadding: 56, verticalPadding: 20, fontSize: 26))
                    .focused($replayFocused)

                    Button("Changer de mode") {
                        onChangeMode()
                    }
                    .buttonStyle(SecondaryPillButtonStyle())
                }
            }
            .padding(.bottom, 70)
        }
        .ignoresSafeArea()
        .defaultFocus($replayFocused, true)
    }

    // MARK: - Carte du monde avec les lieux joués

    private var worldMap: some View {
        Map(initialPosition: .automatic, interactionModes: []) {
            ForEach(Array(rounds.enumerated()), id: \.element.id) { index, round in
                Annotation("", coordinate: round.correctAnswer.centerCoordinate) {
                    summaryPin(color: index.isMultiple(of: 2) ? Theme.amber : Theme.rose)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
    }

    /// Pin ambre/rose alterné avec halo à 25 %.
    private func summaryPin(color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.25))
                .frame(width: 40, height: 40)
            Circle()
                .fill(color)
                .frame(width: 20, height: 20)
                .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 2))
        }
    }

    /// Voile sombre pour garder la carte en arrière-plan discret.
    private var mapVeil: some View {
        LinearGradient(
            stops: [
                .init(color: Theme.backgroundBottom.opacity(0.75), location: 0),
                .init(color: Theme.backgroundBottom.opacity(0.55), location: 0.4),
                .init(color: Theme.backgroundBottom.opacity(0.96), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    // MARK: - Score

    private var finalScoreText: String {
        if gameViewModel.mode == .challenge {
            return "\(gameViewModel.score.formatted(.number.grouping(.automatic))) pts"
        }
        return "\(gameViewModel.correctAnswersCount)/\(rounds.count)"
    }

    private var scoreSubtitle: String {
        gameViewModel.mode == .challenge
            ? "Score final — mode Challenge"
            : "Quel beau voyage — mode Souvenir"
    }

    private var statsLine: some View {
        HStack(spacing: 56) {
            Text("\(Text("\(gameViewModel.correctAnswersCount)/\(rounds.count)").bold()) bonnes réponses")
            Text("\(Text("\(gameViewModel.totalDistanceKm.formatted(.number.grouping(.automatic))) km").bold()) parcourus")
            Text("\(Text("\(gameViewModel.countriesVisitedCount)").bold()) \(gameViewModel.countriesVisitedCount > 1 ? "pays visités" : "pays visité")")
        }
        .font(.system(size: 25))
        .foregroundStyle(Theme.textSecondary)
    }
}
