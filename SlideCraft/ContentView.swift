//
//  ContentView.swift
//  SlideCraft
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        switch appState.currentScreen {
        case .home:
            HomeView()
        case .characters:
            CharactersView()
        case .backgrounds:
            BackgroundsView()
        case .projectSetup:
            ProjectSetupView()
        case .carouselEditor:
            CarouselEditorView()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
        .modelContainer(for: [Character.self, Carousel.self, Slide.self])
}
