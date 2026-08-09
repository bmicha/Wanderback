import SwiftUI
import MapKit

struct SummaryView: View {
    let gameViewModel: GameViewModel
    /// Retour à l'accueil pour changer de mode
    let onChangeMode: () -> Void

    @FocusState private var focusedButton: SummaryButton?

    /// Deux boutons de l'écran de résumé, pour piloter la surbrillance clavier sur macOS.
    private enum SummaryButton: Hashable {
        case replay
        case changeMode
    }

    private var rounds: [GameRound] { gameViewModel.session?.rounds ?? [] }

    var body: some View {
        ZStack {
            // Sous la carte : évite un écran vide pendant l'initialisation MapKit
            SceneBackground()
            worldMap
                .ignoresSafeArea()
            mapVeil
                .ignoresSafeArea()

            VStack(spacing: 36.scaled) {
                Spacer()

                VStack(spacing: 10.scaled) {
                    Text("Partie terminée !")
                        .font(.system(size: 30.scaled, weight: .bold))
                        .foregroundStyle(.white)

                    GradientText(text: finalScoreText, size: 96)

                    Text(scoreSubtitle)
                        .font(.system(size: 26.scaled))
                        .foregroundStyle(Theme.textSecondary)
                }

                statsLine

                HStack(spacing: 30.scaled) {
                    Button {
                        gameViewModel.replay()
                    } label: {
                        HStack(spacing: 14.scaled) {
                            Text("Rejouer")
                            Image(systemName: "play.fill")
                                .font(.system(size: 20.scaled))
                        }
                    }
                    .buttonStyle(GradientPillButtonStyle(horizontalPadding: 56, verticalPadding: 20, fontSize: 26))
                    .macFocusable()
                    .focused($focusedButton, equals: .replay)
                    .macFocusOnHover($focusedButton, equals: .replay)
                    .macDefaultActionShortcut()

                    Button("Changer de mode") {
                        onChangeMode()
                    }
                    .buttonStyle(SecondaryPillButtonStyle())
                    .macFocusable()
                    .focused($focusedButton, equals: .changeMode)
                    .macFocusOnHover($focusedButton, equals: .changeMode)
                }
                .focusSection()
                .macMoveCommand { direction in
                    switch (focusedButton, direction) {
                    case (.replay, .right):
                        focusedButton = .changeMode
                    case (.changeMode, .left):
                        focusedButton = .replay
                    default:
                        break
                    }
                }
            }
            .padding(.bottom, 70.scaled)
            .tvIgnoresSafeArea()
        }
        .initialFocus($focusedButton, .replay)
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
        // Sans ça, la carte plein écran capte le focus tvOS et empêche
        // de naviguer de « Rejouer » vers « Changer de mode »
        .disabled(true)
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
        HStack(spacing: 56.scaled) {
            Text("\(Text("\(gameViewModel.correctAnswersCount)/\(rounds.count)").bold()) bonnes réponses")
            Text("\(Text("\(gameViewModel.totalDistanceKm.formatted(.number.grouping(.automatic))) km").bold()) parcourus")
            Text("\(Text("\(gameViewModel.countriesVisitedCount)").bold()) \(gameViewModel.countriesVisitedCount > 1 ? "pays visités" : "pays visité")")
        }
        .font(.system(size: 25.scaled))
        .foregroundStyle(Theme.textSecondary)
    }
}
