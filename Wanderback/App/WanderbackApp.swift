import SwiftUI
import SwiftData

@main
struct WanderbackApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: LocationCache.self)
    }
}
