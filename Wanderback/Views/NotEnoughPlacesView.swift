import SwiftUI

/// Écran d'erreur : pas assez de destinations distinctes pour jouer.
struct NotEnoughPlacesView: View {
    let viewModel: PhotoLibraryViewModel

    @State private var showingHelp = false
    @FocusState private var demoFocused: Bool

    var body: some View {
        ZStack {
            SceneBackground()

            VStack(spacing: 32.scaled) {
                badge

                Text("Pas assez de destinations trouvées")
                    .font(.system(size: 52.scaled, weight: .heavy))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(bodyText)
                    .font(.system(size: 28.scaled))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                tipCard

                HStack(spacing: 30.scaled) {
                    Button("Voir comment faire") {
                        withAnimation(Theme.focusAnimation) { showingHelp.toggle() }
                    }
                    .buttonStyle(SecondaryPillButtonStyle(horizontalPadding: 44, verticalPadding: 18, fontSize: 24))

                    Button {
                        viewModel.startDemoMode()
                    } label: {
                        HStack(spacing: 12.scaled) {
                            Text("Mode démo")
                            Image(systemName: "play.fill")
                                .font(.system(size: 18.scaled))
                        }
                    }
                    .buttonStyle(GradientPillButtonStyle(horizontalPadding: 44, verticalPadding: 18, fontSize: 24))
                    .focused($demoFocused)
                }
                .padding(.top, 8.scaled)
            }
            .padding(.horizontal, 200.scaled)
        }
        .defaultFocus($demoFocused, true)
    }

    /// Pastille 120 : cercle translucide + point erreur.
    private var badge: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 120.scaled, height: 120.scaled)
            Circle()
                .fill(Theme.error.opacity(0.3))
                .frame(width: 52.scaled, height: 52.scaled)
            Circle()
                .fill(Theme.error)
                .frame(width: 26.scaled, height: 26.scaled)
        }
    }

    private var bodyText: String {
        let found = viewModel.clusters.count
        let minimum = ClusteringService.minimumClusters
        if found > 0 {
            return "Wanderback a trouvé seulement \(found) lieu\(found > 1 ? "x" : "") dans tes photos.\nIl en faut au moins \(minimum) différents pour jouer."
        }
        return "Wanderback n'a pas trouvé de photos géolocalisées dans ta bibliothèque.\nIl faut au moins \(minimum) lieux différents pour jouer."
    }

    private var tipCard: some View {
        Text(showingHelp ? helpText : tipText)
            .font(.system(size: 24.scaled))
            .foregroundStyle(Theme.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 30.scaled)
            .padding(.vertical, 18.scaled)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16.scaled))
    }

    private var tipText: String {
        "Active « Localisation » sur ton iPhone pour tes prochaines photos, et reviens après ton prochain voyage !"
    }

    private var helpText: String {
        "Sur ton iPhone : Réglages → Confidentialité et sécurité → Service de localisation → Appareil photo → « Lorsque l'app est active ». Les photos prises ensuite seront géolocalisées et synchronisées via iCloud."
    }
}

#Preview {
    NotEnoughPlacesView(viewModel: PhotoLibraryViewModel())
}
