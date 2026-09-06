import SwiftUI

struct LoadingView: View {
    let viewModel: PhotoLibraryViewModel

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            SceneBackground()

            VStack(spacing: 44.scaled) {
                globe

                GradientText(text: "WANDERBACK", size: 76, tracking: -2)

                Text("Analyse de vos photos…")
                    .font(.system(size: 28.scaled))
                    .foregroundStyle(Theme.textSecondary)

                progressBar

                VStack(spacing: 20.scaled) {
                    Text(viewModel.currentStep.label)
                        .font(.system(size: 24.scaled))
                        .foregroundStyle(Theme.textSecondary)
                        .contentTransition(.numericText())
                        .animation(.default, value: viewModel.currentStep.label)

                    if viewModel.totalPhotoCount > 0 {
                        Text(viewModel.gpsStatsText)
                            .font(.system(size: 24.scaled))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .onAppear { isPulsing = true }
    }

    /// Globe 140×140 : cercle dégradé ambre→rose, halo rose, pulsation 2,2 s
    private var globe: some View {
        Circle()
            .fill(Theme.signatureGradient)
            .frame(width: 140.scaled, height: 140.scaled)
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 8)
                    .frame(width: 64.scaled, height: 64.scaled)
            )
            .shadow(color: Theme.rose.opacity(0.5), radius: 90)
            .scaleEffect(isPulsing ? 1.12 : 1.0)
            .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: isPulsing)
    }

    /// Barre 900×12, pilule, remplissage dégradé signature
    private var progressBar: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.1))

            if let progress = viewModel.currentStep.progress {
                GeometryReader { geometry in
                    Capsule()
                        .fill(Theme.signatureGradient)
                        .frame(width: max(12, geometry.size.width * progress))
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            } else {
                // Progression indéterminée : segment qui pulse
                Capsule()
                    .fill(Theme.signatureGradient)
                    .frame(width: 200.scaled)
                    .opacity(isPulsing ? 0.9 : 0.3)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: isPulsing)
            }
        }
        .frame(width: Device.isPhone ? nil : 900.scaled, height: 12.scaled)
        .frame(maxWidth: Device.isPhone ? .infinity : nil)
        .padding(.horizontal, Device.isPhone ? 40.scaled : 0)
    }
}

#Preview {
    LoadingView(viewModel: PhotoLibraryViewModel())
}
