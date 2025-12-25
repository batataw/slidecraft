//
//  AppState.swift
//  SlideCraft
//

import Foundation
import SwiftUI
import Combine

enum AppScreen {
    case home
    case characters       // Manage character bank
    case backgrounds      // Manage background bank
    case projectSetup     // NEW: Combined character + background + subject selection
    case carouselEditor   // NEW: Combined text validation + image generation
}

@Observable
final class AppState {
    var currentScreen: AppScreen = .home
    var carouselViewModel: CarouselViewModel
    var showSettings: Bool = false

    private var cancellables = Set<AnyCancellable>()

    var isConfigured: Bool {
        KeychainService.shared.hasKey(.openAIAPIKey)
    }

    init() {
        self.carouselViewModel = AppState.createCarouselViewModel()
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .apiKeysUpdated)
            .sink { [weak self] _ in
                self?.refreshServices()
            }
            .store(in: &cancellables)
    }

    private func refreshServices() {
        carouselViewModel = AppState.createCarouselViewModel()
    }

    private static func createCarouselViewModel() -> CarouselViewModel {
        let keychain = KeychainService.shared

        let openAIKey = keychain.get(key: .openAIAPIKey) ?? ""
        let geminiKey = keychain.get(key: .geminiAPIKey) ?? ""

        let aiService: AIServiceProtocol = ChatGPTService(apiKey: openAIKey)

        let imageService: ImageGenerationServiceProtocol
        if geminiKey.isEmpty {
            imageService = MockImageGenerationService()
        } else {
            imageService = NanoBananaService(apiKey: geminiKey)
        }

        return CarouselViewModel(aiService: aiService, imageService: imageService)
    }

    // MARK: - Navigation

    func navigateToHome() {
        currentScreen = .home
        carouselViewModel = AppState.createCarouselViewModel()
    }

    func navigateToCharacters() {
        currentScreen = .characters
    }

    func navigateToBackgrounds() {
        currentScreen = .backgrounds
    }

    func navigateToProjectSetup() {
        currentScreen = .projectSetup
    }

    func navigateToCarouselEditor() {
        currentScreen = .carouselEditor
    }

    func openSettings() {
        showSettings = true
    }
}
