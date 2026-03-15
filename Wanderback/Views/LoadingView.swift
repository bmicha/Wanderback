import SwiftUI

struct LoadingView: View {
    let currentStep: IndexingStep
    let gpsStatsText: String

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Image(systemName: "globe.desk")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse)

            Text("Wanderback")
                .font(.system(size: 56, weight: .bold))

            VStack(spacing: 30) {
                Text(currentStep.label)
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut, value: currentStep)

                if let progress = currentStep.progress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(width: 500)
                        .animation(.easeInOut, value: progress)
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }

            if !gpsStatsText.isEmpty {
                Text(gpsStatsText)
                    .font(.system(size: 24))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(80)
    }
}
