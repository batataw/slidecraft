//
//  AIService.swift
//  SlideCraft
//

import Foundation

// MARK: - Data Transfer Objects

struct GeneratedSlide: Codable {
    let text: String
}

struct CarouselScenario: Codable {
    let setting: String              // Description du lieu/décor
    let characters: String           // Description visuelle des personnages
    let slides: [GeneratedSlide]
}

struct SocialContent: Codable {
    let title: String                // Titre accrocheur
    let description: String          // Description avec hashtags
}

// MARK: - AI Service Protocol

struct CharacterInfo {
    let name: String
    let role: CharacterRole
}

protocol AIServiceProtocol {
    func generateScenario(subject: String, characters: [CharacterInfo]) async throws -> CarouselScenario
    func regenerateScenario(subject: String, characters: [CharacterInfo], currentSlides: [String], feedback: String) async throws -> CarouselScenario
    func regenerateSlideText(subject: String, currentText: String, feedback: String, allSlides: [String], slideIndex: Int, setting: String?) async throws -> String
    func generateVisualPrompt(slideText: String, slideIndex: Int, totalSlides: Int, subject: String, setting: String) async throws -> String
    func generateSocialContent(subject: String, slides: [String]) async throws -> SocialContent
}

// MARK: - Image Generation Protocol

struct ReferenceImage {
    let data: Data
    let mimeType: String
    let name: String
}

protocol ImageGenerationServiceProtocol {
    func generateImage(prompt: String, size: CGSize, referenceImages: [ReferenceImage]) async throws -> Data
}

// MARK: - AI Service Errors

enum AIServiceError: LocalizedError {
    case invalidResponse
    case networkError(Error)
    case apiError(String)
    case decodingError(Error)
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Réponse invalide du service IA"
        case .networkError(let error):
            return "Erreur réseau: \(error.localizedDescription)"
        case .apiError(let message):
            return "Erreur API: \(message)"
        case .decodingError(let error):
            return "Erreur de décodage: \(error.localizedDescription)"
        case .missingAPIKey:
            return "Clé API manquante"
        }
    }
}
