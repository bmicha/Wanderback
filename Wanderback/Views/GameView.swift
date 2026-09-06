import SwiftUI

struct GameView: View {
    let gameViewModel: GameViewModel

    @State private var roundImage: PlatformImage?
    @State private var loadedRoundId: UUID?

    private let scrimColor = Color(red: 10 / 255, green: 9 / 255, blue: 20 / 255)

    var body: some View {
        ZStack {
            photoBackground
                .ignoresSafeArea()
            scrim
                .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                bottomSection
            }
            .tvIgnoresSafeArea()
        }
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
                    Image(platformImage: roundImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .scaleEffect(1.2)
                        .blur(radius: 45)
                        .overlay(Color.black.opacity(0.3))

                    Image(platformImage: roundImage)
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
    /// En portrait la zone de réponses occupe une part plus haute de l'écran : le
    /// dégradé bas démarre plus tard pour ne pas voiler le centre de la photo.
    private var scrim: some View {
        LinearGradient(
            stops: [
                .init(color: scrimColor.opacity(0.6), location: 0),
                .init(color: .clear, location: Device.isPhone ? 0.10 : 0.18),
                .init(color: .clear, location: Device.isPhone ? 0.66 : 0.52),
                .init(color: scrimColor.opacity(0.92), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Barre haute

    private var topBar: some View {
        HStack {
            // Sur iPhone, la largeur est comptée : le logo cède la place au chrono
            // et au score, et la croix « fermer » (overlay de ContentView) occupe
            // seule le coin haut gauche.
            if !Device.isPhone {
                GradientText(text: "WANDERBACK", size: 28, tracking: -0.5)
                    // Sur iPad, la croix « fermer » flotte en overlay top-leading
                    // (ContentView) par-dessus cette barre : marge additionnelle
                    // pour éviter qu'elle ne chevauche le "W" du logo. Cette
                    // branche n'est jamais atteinte sur iPhone (logo absent) ni
                    // sur tvOS/macOS (pas de croix), donc le `#if os(iOS)` ne
                    // vise ici que l'iPad.
                    #if os(iOS)
                    .padding(.leading, 44.scaled)
                    #endif
            }

            Spacer()

            HStack(spacing: Device.isPhone ? 18.scaled : 32.scaled) {
                // Le numéro courant reste en gras dans les deux variantes
                Text(Device.isPhone
                     ? "\(Text("\(currentRoundNumber)").bold())/\(totalRounds)"
                     : "Round \(Text("\(currentRoundNumber)").bold())/\(totalRounds)")
                    .font(.system(size: 24.scaled))
                    .foregroundStyle(Theme.textSecondary)

                if gameViewModel.mode == .challenge {
                    timerRing

                    Text("\(gameViewModel.score.formatted(.number.grouping(.automatic))) pts")
                        .font(.system(size: 24.scaled, weight: .bold))
                        .foregroundStyle(Theme.amber)
                }
            }
        }
        .padding(.horizontal, Device.isPhone ? 24.scaled : 56.scaled)
        .padding(.vertical, 36.scaled)
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
                .font(.system(size: 24.scaled, weight: .heavy))
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
        }
        .frame(width: 68.scaled, height: 68.scaled)
    }

    // MARK: - Question + réponses

    private var bottomSection: some View {
        VStack(alignment: .leading, spacing: 24.scaled) {
            Text("Où cette photo a-t-elle été prise ?")
                .font(.system(size: 26.scaled))
                .foregroundStyle(.white)

            if let round = gameViewModel.currentRound {
                AnswerOptionsView(options: round.options) { option in
                    gameViewModel.answer(option)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Device.isPhone ? 24.scaled : 56.scaled)
        .padding(.bottom, 44.scaled)
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
        // Préchauffe MapKit et les tuiles du lieu pendant que le joueur réfléchit
        MapPrefetcher.shared.prefetch(for: round.correctAnswer)
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
