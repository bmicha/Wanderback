# LoadingView Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer le ProgressView basique par un vrai ecran d'indexation avec progression par etape, compteur, et transition automatique vers HomeView.

**Architecture:** PhotoLibraryViewModel orchestre le pipeline complet (permission -> index -> cluster -> geocode) avec reporting de progression par etape. LoadingView affiche la progression. ContentView devient un routeur d'etat.

**Tech Stack:** SwiftUI, @Observable, SwiftData (ModelContext pour geocoding cache), PhotoKit, CoreLocation

---

## File Structure

| Action | File | Responsibility |
|--------|------|---------------|
| Modify | `Wanderback/ViewModels/PhotoLibraryViewModel.swift` | Pipeline complet + progression |
| Create | `Wanderback/Views/LoadingView.swift` | UI de progression tvOS |
| Modify | `Wanderback/Views/ContentView.swift` | Routeur d'etat (error/loading/home) |

---

### Task 1: Enhance PhotoLibraryViewModel with full pipeline and progress

**Files:**
- Modify: `Wanderback/ViewModels/PhotoLibraryViewModel.swift`

**Context:** Actuellement le ViewModel fait seulement permission + indexation. Il faut ajouter clustering + geocoding avec reporting de progression.

- [ ] **Step 1: Add IndexingStep enum and progress properties**

```swift
import Foundation
import Photos
import SwiftData
import CoreLocation
import os

enum IndexingStep: Equatable {
    case requestingAccess
    case scanningPhotos
    case clusteringLocations
    case geocoding(current: Int, total: Int)
    case ready

    var label: String {
        switch self {
        case .requestingAccess: return "Demande d'acces aux photos..."
        case .scanningPhotos: return "Analyse des photos..."
        case .clusteringLocations: return "Regroupement des lieux..."
        case .geocoding(let current, let total): return "Identification des lieux... (\(current)/\(total))"
        case .ready: return "Pret !"
        }
    }

    var progress: Double? {
        switch self {
        case .geocoding(let current, let total) where total > 0:
            return Double(current) / Double(total)
        case .ready:
            return 1.0
        default:
            return nil
        }
    }
}

@Observable
class PhotoLibraryViewModel {
    var authorizationStatus: PHAuthorizationStatus = .notDetermined
    var photoLocations: [PhotoLocation] = []
    var clusters: [LocationCluster] = []
    var totalPhotoCount = 0
    var isLoading = false
    var currentStep: IndexingStep = .requestingAccess
    var errorMessage: String?
    var notEnoughPhotos = false

    private let photoIndexer = PhotoIndexer()
    private let clusteringService = ClusteringService()
    private let geocoderService = GeocoderService()
    private let logger = Logger(subsystem: "com.bastien.Wanderback", category: "PhotoLibraryVM")

    var hasAccess: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    var isReady: Bool {
        if case .ready = currentStep { return true }
        return false
    }

    var gpsStatsText: String {
        "\(photoLocations.count) photos avec GPS / \(totalPhotoCount) total"
    }

    var clusterCount: Int { clusters.count }

    var countryCount: Int {
        Set(clusters.map(\.country)).subtracting([""]).count
    }

    func requestAccessAndLoadPhotos(modelContext: ModelContext) async {
        isLoading = true
        defer { isLoading = false }

        // Step 1: Permission
        currentStep = .requestingAccess
        authorizationStatus = await photoIndexer.requestAuthorization()
        logger.info("Authorization status: \(self.authorizationStatus.rawValue)")

        switch authorizationStatus {
        case .authorized, .limited:
            break
        case .denied, .restricted:
            errorMessage = "Wanderback a besoin d'acceder a vos photos pour fonctionner. Autorisez l'acces dans Reglages > Confidentialite > Photos."
            return
        case .notDetermined:
            return
        @unknown default:
            return
        }

        // Step 2: Index photos
        currentStep = .scanningPhotos
        let result = await photoIndexer.indexPhotos()
        totalPhotoCount = result.totalCount
        photoLocations = result.locations

        if photoLocations.count < PhotoIndexer.minimumDistinctLocations {
            notEnoughPhotos = true
            logger.warning("Not enough GPS photos: \(self.photoLocations.count)")
            return
        }

        // Step 3: Clustering
        currentStep = .clusteringLocations
        clusters = clusteringService.clusterPhotos(photoLocations)

        if clusters.count < ClusteringService.minimumClusters {
            notEnoughPhotos = true
            logger.warning("Not enough clusters: \(self.clusters.count)")
            return
        }

        // Step 4: Geocoding (le plus long — progress par cluster)
        currentStep = .geocoding(current: 0, total: clusters.count)
        for i in clusters.indices {
            let coord = clusters[i].centerCoordinate
            if let cache = await geocoderService.reverseGeocode(coordinate: coord, modelContext: modelContext) {
                clusters[i].displayName = cache.displayName
                clusters[i].country = cache.country
            }
            currentStep = .geocoding(current: i + 1, total: clusters.count)
        }

        // Step 5: Ready
        currentStep = .ready
        logger.info("Indexing complete: \(self.clusters.count) clusters, \(self.countryCount) countries")
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `xcodebuild -project Wanderback.xcodeproj -scheme Wanderback -destination 'platform=tvOS Simulator,name=Apple TV' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Wanderback/ViewModels/PhotoLibraryViewModel.swift
git commit -m "feat: add full indexing pipeline with progress to PhotoLibraryViewModel"
```

---

### Task 2: Create LoadingView with tvOS UI

**Files:**
- Create: `Wanderback/Views/LoadingView.swift`

**Context:** Ecran d'indexation visible pendant le pipeline. Doit respecter les guidelines tvOS 10-foot UI (polices larges, espacement genereux). Affiche etape, barre de progression, compteur.

- [ ] **Step 1: Create LoadingView**

```swift
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

            VStack(spacing: 20) {
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
                        .frame(width: 500)
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
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -project Wanderback.xcodeproj -scheme Wanderback -destination 'platform=tvOS Simulator,name=Apple TV' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Wanderback/Views/LoadingView.swift
git commit -m "feat: add LoadingView with progress bar and step labels"
```

---

### Task 3: Refactor ContentView as state router

**Files:**
- Modify: `Wanderback/Views/ContentView.swift`

**Context:** ContentView devient le routeur principal. Il passe le ModelContext au ViewModel pour le geocoding. Il affiche: erreur, pas assez de photos, loading (LoadingView), ou pret (HomeView stub).

- [ ] **Step 1: Refactor ContentView**

```swift
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
                LoadingView(
                    currentStep: viewModel.currentStep,
                    gpsStatsText: viewModel.isLoading ? viewModel.gpsStatsText : ""
                )
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
            Text("Pas assez de photos geolocalisees")
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
```

- [ ] **Step 2: Build and verify**

Run: `xcodebuild -project Wanderback.xcodeproj -scheme Wanderback -destination 'platform=tvOS Simulator,name=Apple TV' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Wanderback/Views/ContentView.swift
git commit -m "feat: refactor ContentView as state router with LoadingView transition"
```
