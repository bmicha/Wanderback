import SwiftUI
import MapKit

struct RevealView: View {
    let gameViewModel: GameViewModel

    @State private var cameraPosition: MapCameraPosition
    @State private var contentRevealed = false
    @State private var sameDayImages: [UIImage] = []
    @FocusState private var nextButtonFocused: Bool

    init(gameViewModel: GameViewModel) {
        self.gameViewModel = gameViewModel
        // Départ du zoom cinématique : vue très éloignée centrée sur le lieu
        if let coordinate = gameViewModel.currentRound?.correctAnswer.centerCoordinate {
            _cameraPosition = State(initialValue: .camera(
                MapCamera(centerCoordinate: coordinate, distance: 18_000_000)
            ))
        } else {
            _cameraPosition = State(initialValue: .automatic)
        }
    }

    private var round: GameRound? { gameViewModel.currentRound }
    private var isCorrect: Bool { round?.isCorrect == true }

    var body: some View {
        ZStack {
            // Sous la carte : évite un écran vide pendant l'initialisation MapKit
            SceneBackground()
            map
            vignette

            VStack {
                resultBadge
                    .padding(.top, 44)
                Spacer()
            }

            centerContent

            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    sameDayThumbnails
                    Spacer()
                    nextButton
                }
                .padding(.horizontal, 56)
                .padding(.bottom, 44)
            }
        }
        .ignoresSafeArea()
        .defaultFocus($nextButtonFocused, true)
        .onAppear { startCinematicZoom() }
        .task { await loadSameDayPhotos() }
    }

    // MARK: - Carte + zoom cinématique

    private var map: some View {
        Map(position: $cameraPosition, interactionModes: []) {
            if let coordinate = round?.correctAnswer.centerCoordinate {
                Annotation("", coordinate: coordinate) {
                    pin
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        // Empêche la carte plein écran de capter le focus tvOS (cf. SummaryView)
        .disabled(true)
    }

    /// Pin 28pt : cercle erreur + halo à 30 %.
    private var pin: some View {
        ZStack {
            Circle()
                .fill(Theme.error.opacity(0.3))
                .frame(width: 56, height: 56)
            Circle()
                .fill(Theme.error)
                .frame(width: 28, height: 28)
                .overlay(Circle().strokeBorder(.white.opacity(0.85), lineWidth: 3))
        }
    }

    /// Vignette radiale sombre sur les bords de la carte.
    private var vignette: some View {
        RadialGradient(
            stops: [
                .init(color: Theme.backgroundBottom.opacity(0.25), location: 0),
                .init(color: Theme.backgroundBottom.opacity(0.4), location: 0.5),
                .init(color: Theme.backgroundBottom.opacity(0.88), location: 1)
            ],
            center: .center,
            startRadius: 200,
            endRadius: 1200
        )
        .allowsHitTesting(false)
    }

    private func startCinematicZoom() {
        guard let coordinate = round?.correctAnswer.centerCoordinate else { return }

        // Centre de caméra décalé au sud du lieu : le pin s'affiche dans le tiers
        // haut de l'écran, bien séparé du cartouche titre/date
        let offsetCenter = CLLocationCoordinate2D(
            latitude: coordinate.latitude - 0.3,
            longitude: coordinate.longitude
        )

        // Zoom ~2–3 s en Souvenir, abrégé en Challenge
        let duration: TimeInterval = gameViewModel.mode == .challenge ? 1.6 : 2.6
        withAnimation(.easeInOut(duration: duration)) {
            cameraPosition = .camera(
                MapCamera(centerCoordinate: offsetCenter, distance: 250_000, pitch: 0)
            )
        }
        withAnimation(.easeOut(duration: 0.5).delay(duration * 0.4)) {
            contentRevealed = true
        }
    }

    // MARK: - Badge résultat

    private var resultBadge: some View {
        HStack(spacing: 10) {
            Image(systemName: isCorrect ? "checkmark" : "xmark")
                .font(.system(size: 22, weight: .heavy))
            Text(isCorrect ? "Bonne réponse !" : "C'était…")
                .font(.system(size: 26, weight: .heavy))
        }
        .foregroundStyle(Theme.inkDark)
        .padding(.horizontal, 36)
        .padding(.vertical, 16)
        .background(isCorrect ? Theme.success : Theme.error, in: Capsule())
        .shadow(color: Theme.tileShadow, radius: 20, y: 12)
    }

    // MARK: - Contenu central

    private var centerContent: some View {
        VStack(spacing: 16) {
            Text(round?.correctAnswer.displayName.uppercased() ?? "")
                .font(.system(size: 104, weight: .heavy))
                .tracking(4)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(round?.correctAnswer.country ?? "")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.85))

            Text(metaText)
                .font(.system(size: 24))
                .foregroundStyle(Theme.textSecondary)

            if gameViewModel.mode == .challenge {
                Text("+\(gameViewModel.lastPointsEarned) pts")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(Theme.amber)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 70)
        .padding(.vertical, 40)
        .background {
            // Cartouche translucide : garde titre, lieu et date lisibles sur la carte
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(red: 10 / 255, green: 9 / 255, blue: 20 / 255).opacity(0.55))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 2)
        )
        .shadow(color: Theme.tileShadow, radius: 30, y: 20)
        .padding(.top, 280) // sous le pin, remonté dans le tiers haut de la carte
        .padding(.horizontal, 100)
        .opacity(contentRevealed ? 1 : 0)
        .offset(y: contentRevealed ? 0 : 30)
    }

    private var metaText: String {
        var parts: [String] = []
        if let date = round?.photo.dateTaken {
            parts.append(date.formatted(
                Date.FormatStyle(date: .long, time: .omitted, locale: Locale(identifier: "fr_FR"))
            ))
        }
        if let km = gameViewModel.distanceFromHomeKm {
            parts.append("\(km.formatted(.number.grouping(.automatic))) km de chez vous")
        }
        return parts.joined(separator: "  ·  ")
    }

    // MARK: - Vignettes du même jour

    @ViewBuilder
    private var sameDayThumbnails: some View {
        if !sameDayImages.isEmpty {
            HStack(alignment: .bottom, spacing: 14) {
                ForEach(Array(sameDayImages.enumerated()), id: \.offset) { _, image in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 148, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 2)
                        )
                }

                Text("photos du\nmême jour")
                    .font(.system(size: 19))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.leading, 6)
            }
            .opacity(contentRevealed ? 1 : 0)
        }
    }

    private func loadSameDayPhotos() async {
        guard let round else { return }
        let calendar = Calendar.current
        let sameDay = round.correctAnswer.photos
            .filter { calendar.isDate($0.dateTaken, inSameDayAs: round.photo.dateTaken) }
            .prefix(3)

        var images: [UIImage] = []
        for photo in sameDay {
            if let image = await PhotoImageLoader.shared.loadImage(
                assetIdentifier: photo.assetIdentifier,
                targetSize: CGSize(width: 296, height: 200)
            ) {
                images.append(image)
            }
        }
        sameDayImages = images
    }

    // MARK: - Bouton suivant

    private var nextButton: some View {
        Button {
            gameViewModel.nextRound()
        } label: {
            HStack(spacing: 12) {
                Text(gameViewModel.isLastRound ? "Voir le récap" : "Round suivant")
                Image(systemName: "arrow.right")
                    .font(.system(size: 22, weight: .bold))
            }
        }
        .buttonStyle(GradientPillButtonStyle(horizontalPadding: 48, verticalPadding: 20, fontSize: 26))
        .focused($nextButtonFocused)
    }
}
