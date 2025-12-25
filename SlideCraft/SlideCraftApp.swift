//
//  SlideCraftApp.swift
//  SlideCraft
//

import SwiftUI
import SwiftData

@main
struct SlideCraftApp: App {
    @State private var appState = AppState()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Carousel.self,
            Slide.self,
            Character.self,
            Background.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.automatic)
        .defaultSize(width: 1200, height: 800)
    }
}
