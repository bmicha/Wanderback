import SwiftUI

struct ContentView: View {
    @State private var viewModel = PhotoLibraryViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Chargement des photos...")
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else if viewModel.hasAccess {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
                    Text("\(viewModel.assets.count) photos trouvées")
                        .font(.headline)
                }
            } else {
                Text("Wanderback")
                    .font(.largeTitle)
            }
        }
        .task {
            await viewModel.requestAccessAndLoadPhotos()
        }
    }
}

#Preview {
    ContentView()
}
