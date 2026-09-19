import SwiftUI
import MapKit

struct RevealView: View {
    let gameViewModel: GameViewModel

    @State private var cameraPosition: MapCameraPosition
    @State private var contentRevealed = false
    @State private var sameDayImages: [PlatformImage] = []
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
                .ignoresSafeArea()
            vignette
                .ignoresSafeArea()

            VStack {
                resultBadge
                    .padding(.top, 44.scaled)
                Spacer()
            }
            .tvIgnoresSafeArea()

            centerContent
                .tvIgnoresSafeArea()

            VStack {
                Spacer()
                if Device.isPhone {
                    // 344 pt de vignettes + le bouton ne tiennent pas sur une rangée
                    VStack(spacing: 20.scaled) {
                        sameDayThumbnails
                        nextButton
                    }
                } else {
                    HStack(alignment: .bottom) {
                        sameDayThumbnails
                        Spacer()
                        nextButton
                    }
                }
            }
            .padding(.horizontal, (Device.isPhone ? 24 : 56).scaled)
            .padding(.bottom, 44.scaled)
            .tvIgnoresSafeArea()
        }
        .initialFocus($nextButtonFocused, true)
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
    /// Rayons en points bruts : ils doivent couvrir l'écran, pas le canvas de design.
    private var vignette: some View {
        RadialGradient(
            stops: [
                .init(color: Theme.backgroundBottom.opacity(0.25), location: 0),
                .init(color: Theme.backgroundBottom.opacity(0.4), location: 0.5),
                .init(color: Theme.backgroundBottom.opacity(0.88), location: 1)
            ],
            center: .center,
            startRadius: Device.isPhone ? 60 : 200,
            endRadius: Device.isPhone ? 440 : 1200
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
        HStack(spacing: 10.scaled) {
            Image(systemName: isCorrect ? "checkmark" : "xmark")
                .font(.system(size: 22.scaled, weight: .heavy))
            Text(isCorrect ? "Bonne réponse !" : "C'était…")
                .font(.system(size: 26.scaled, weight: .heavy))
        }
        .foregroundStyle(Theme.inkDark)
        .padding(.horizontal, 36.scaled)
        .padding(.vertical, 16.scaled)
        .background(isCorrect ? Theme.success : Theme.error, in: Capsule())
        .shadow(color: Theme.tileShadow, radius: 20, y: 12)
    }

    // MARK: - Contenu central

    private var centerContent: some View {
        VStack(spacing: 16.scaled) {
            Text(round?.correctAnswer.displayName.uppercased() ?? "")
                .font(.system(size: (Device.isPhone ? 76 : 104).scaled, weight: .heavy))
                .tracking(4)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(round?.correctAnswer.country ?? "")
                .font(.system(size: 32.scaled))
                .foregroundStyle(.white.opacity(0.85))

            Text(metaText)
                .font(.system(size: 24.scaled))
                .foregroundStyle(Theme.textSecondary)

            if gameViewModel.mode == .challenge {
                Text("+\(gameViewModel.lastPointsEarned) pts")
                    .font(.system(size: 30.scaled, weight: .heavy))
                    .foregroundStyle(Theme.amber)
                    .padding(.top, 8.scaled)
            }
        }
        .padding(.horizontal, (Device.isPhone ? 32 : 70).scaled)   // padding interne du cartouche
        .padding(.vertical, 40.scaled)
        .background {
            // Cartouche translucide : garde titre, lieu et date lisibles sur la carte
            RoundedRectangle(cornerRadius: 28.scaled)
                .fill(Color(red: 10 / 255, green: 9 / 255, blue: 20 / 255).opacity(0.55))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28.scaled))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28.scaled)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 2)
        )
        .shadow(color: Theme.tileShadow, radius: 30, y: 20)
        .padding(.top, (Device.isPhone ? 190 : 280).scaled)  // sous le pin
        .padding(.horizontal, (Device.isPhone ? 24 : 100).scaled)
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
            let side: (width: CGFloat, height: CGFloat) =
                Device.isPhone ? (110, 74) : (148, 100)

            let row = HStack(alignment: .bottom, spacing: 14.scaled) {
                ForEach(Array(sameDayImages.enumerated()), id: \.offset) { _, image in
                    Image(platformImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: side.width.scaled, height: side.height.scaled)
                        .clipShape(RoundedRectangle(cornerRadius: 14.scaled))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14.scaled)
                                .strokeBorder(.white.opacity(0.2), lineWidth: 2)
                        )
                }

                // Sur iPhone le libellé passe sous la rangée : à droite, il la
                // pousserait hors de l'écran.
                if !Device.isPhone {
                    Text("photos du\nmême jour")
                        .font(.system(size: 19.scaled))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.leading, 6.scaled)
                }
            }

            Group {
                if Device.isPhone {
                    VStack(spacing: 8.scaled) {
                        row
                        Text("photos du même jour")
                            .font(.system(size: 19.scaled))
                            .foregroundStyle(Theme.textTertiary)
                    }
                } else {
                    row
                }
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

        var images: [PlatformImage] = []
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
            HStack(spacing: 12.scaled) {
                Text(gameViewModel.isLastRound ? "Voir le récap" : "Round suivant")
                Image(systemName: "arrow.right")
                    .font(.system(size: 22.scaled, weight: .bold))
            }
        }
        .buttonStyle(GradientPillButtonStyle(horizontalPadding: 48, verticalPadding: 20, fontSize: 26))
        .macFocusable()
        .focused($nextButtonFocused)
        .macFocusOnHover($nextButtonFocused, equals: true)
        .macDefaultActionShortcut()
    }
}
