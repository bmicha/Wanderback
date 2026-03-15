import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var viewModel = PhotoLibraryViewModel()
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Group {
            if let error = viewModel.errorMessage {
                errorView(message: error)
            } else if viewModel.notEnoughPhotos {
                notEnoughPhotosView
            } else if viewModel.isReady {
                HomeView()
            } else {
                LoadingView(viewModel: viewModel)
            }
        }
        .task {
            await viewModel.requestAccessAndLoadPhotos(modelContext: modelContext)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.system(size: 32))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 80)
        }
    }

    private var notEnoughPhotosView: some View {
        VStack(spacing: 24) {
            Image(systemName: "map.circle")
                .font(.system(size: 80))
                .foregroundStyle(.orange)
            Text("Pas assez de photos géolocalisées")
                .font(.system(size: 38, weight: .semibold))
            Text("Wanderback a besoin d'au moins \(PhotoIndexer.minimumDistinctLocations) lieux distincts pour fonctionner.")
                .font(.system(size: 28))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 80)
            Text(viewModel.gpsStatsText)
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: LocationCache.self)
}
