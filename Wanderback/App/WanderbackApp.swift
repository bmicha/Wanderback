import SwiftUI
import SwiftData

@main
struct WanderbackApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                #if os(macOS)
                .frame(minWidth: 1024, minHeight: 640)
                #endif
        }
        .modelContainer(for: LocationCache.self)
        #if os(macOS)
        .defaultSize(width: 1280, height: 720)
        #endif
    }
}
