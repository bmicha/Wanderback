import SwiftUI

struct GameView: View {
    let gameViewModel: GameViewModel

    @State private var roundImage: UIImage?
    @State private var loadedRoundId: UUID?

    private let scrimColor = Color(red: 10 / 255, green: 9 / 255, blue: 20 / 255)

    var body: some View {
        ZStack {
            photoBackground
            scrim

            VStack {
                topBar
                Spacer()
                bottomSection
            }
        }
        .ignoresSafeArea()
        .task(id: gameViewModel.currentRound?.id) {
            await loadRoundPhoto()
        }
    }

    // MARK: - Photo plein écran

    @ViewBuilder
    private var photoBackground: some View {
        if let roundImage, loadedRoundId == gameViewModel.currentRound?.id {
            // Photo entière (aspect fit) sur fond constitué de la même image
            // zoomée et floutée — indispensable pour les photos portrait
            GeometryReader { geometry in
                ZStack {
                    Image(uiImage: roundImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .scaleEffect(1.2)
                        .blur(radius: 45)
                        .overlay(Color.black.opacity(0.3))

                    Image(uiImage: roundImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .shadow(color: .black.opacity(0.5), radius: 40)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
            .transition(.opacity)
        } else {
            // Placeholder pendant le chargement (et pour le mode démo sans vraie photo)
            LinearGradient(
                colors: [Color(hex: 0x8FB6C9), Color(hex: 0xC9976B), Color(hex: 0x4A3428)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    /// Scrim vertical : sombre en haut, transparent au centre, très sombre en bas.
    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: scrimColor.opacity(0.6), location: 0),
                .init(color: .clear, location: 0.18),
                .init(color: .clear, location: 0.52),
                .init(color: scrimColor.opacity(0.92), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Barre haute

    private var topBar: some View {
        HStack {
            GradientText(text: "WANDERBACK", size: 28, tracking: -0.5)

            Spacer()

            HStack(spacing: 32) {
                Text("Round \(Text("\(currentRoundNumber)").bold())/\(totalRounds)")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.textSecondary)

                if gameViewModel.mode == .challenge {
                    timerRing

                    Text("\(gameViewModel.score.formatted(.number.grouping(.automatic))) pts")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.amber)
                }
            }
        }
        .padding(.horizontal, 56)
        .padding(.vertical, 36)
    }

    /// Anneau chrono 68×68 : l'arc ambre se vide avec le temps.
    private var timerRing: some View {
        let progress = gameViewModel.timerRemaining / GameViewModel.roundDuration
        return ZStack {
            Circle()
                .fill(Color(red: 10 / 255, green: 9 / 255, blue: 20 / 255).opacity(0.85))
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 5)
                .padding(3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.amber, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(3)
            Text("\(Int(gameViewModel.timerRemaining.rounded(.up)))")
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
        }
        .frame(width: 68, height: 68)
    }

    // MARK: - Question + réponses

    private var bottomSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Où cette photo a-t-elle été prise ?")
                .font(.system(size: 26))
                .foregroundStyle(.white)

            if let round = gameViewModel.currentRound {
                AnswerOptionsView(options: round.options) { option in
                    gameViewModel.answer(option)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 56)
        .padding(.bottom, 44)
    }

    private var currentRoundNumber: Int {
        guard let session = gameViewModel.session else { return 0 }
        return min(session.currentRoundIndex + 1, session.rounds.count)
    }

    private var totalRounds: Int {
        gameViewModel.session?.rounds.count ?? 0
    }

    private func loadRoundPhoto() async {
        guard let round = gameViewModel.currentRound else { return }
        roundImage = nil
        let image = await PhotoImageLoader.shared.loadImage(
            assetIdentifier: round.photo.assetIdentifier,
            targetSize: CGSize(width: 1920, height: 1080)
        )
        withAnimation(.easeIn(duration: 0.3)) {
            roundImage = image
            loadedRoundId = round.id
        }
    }
}
