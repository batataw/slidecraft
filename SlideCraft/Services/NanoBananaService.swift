//
//  NanoBananaService.swift
//  SlideCraft
//
//  Uses Google Gemini API for image generation
//

import Foundation
import AppKit

// MARK: - Gemini API Models

struct GeminiRequest: Encodable, Sendable {
    let contents: [GeminiContent]
    let generationConfig: GeminiGenerationConfig

    struct GeminiContent: Encodable, Sendable {
        let parts: [GeminiPart]
    }

    struct GeminiPart: Encodable, Sendable {
        let text: String?
        let inlineData: GeminiInlineData?

        enum CodingKeys: String, CodingKey {
            case text
            case inlineData = "inline_data"
        }

        init(text: String) {
            self.text = text
            self.inlineData = nil
        }

        init(imageData: Data, mimeType: String) {
            self.text = nil
            self.inlineData = GeminiInlineData(
                mimeType: mimeType,
                data: imageData.base64EncodedString()
            )
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            if let text = text {
                try container.encode(text, forKey: .text)
            }
            if let inlineData = inlineData {
                try container.encode(inlineData, forKey: .inlineData)
            }
        }
    }

    struct GeminiInlineData: Encodable, Sendable {
        let mimeType: String
        let data: String

        enum CodingKeys: String, CodingKey {
            case mimeType = "mime_type"
            case data
        }
    }

    struct GeminiGenerationConfig: Encodable, Sendable {
        let responseModalities: [String]

        init(responseModalities: [String] = ["TEXT", "IMAGE"]) {
            self.responseModalities = responseModalities
        }
    }
}

struct GeminiResponse: Decodable, Sendable {
    let candidates: [Candidate]?
    let error: GeminiError?

    struct Candidate: Decodable, Sendable {
        let content: Content?
    }

    struct Content: Decodable, Sendable {
        let parts: [Part]?
    }

    struct Part: Decodable, Sendable {
        let text: String?
        let inlineData: InlineData?
    }

    struct InlineData: Decodable, Sendable {
        let mimeType: String
        let data: String
    }

    struct GeminiError: Decodable, Sendable {
        let message: String
        let code: Int?
    }
}

// MARK: - Imagen Request/Response Models

struct ImagenRequest: Encodable, Sendable {
    let instances: [ImagenInstance]
    let parameters: ImagenParameters

    struct ImagenInstance: Encodable, Sendable {
        let prompt: String
    }

    struct ImagenParameters: Encodable, Sendable {
        let sampleCount: Int
        let aspectRatio: String?

        init(sampleCount: Int = 1, aspectRatio: String? = "4:5") {
            self.sampleCount = sampleCount
            self.aspectRatio = aspectRatio
        }
    }
}

struct ImagenResponse: Decodable, Sendable {
    let predictions: [ImagenPrediction]?
    let error: ImagenError?

    struct ImagenPrediction: Decodable, Sendable {
        let bytesBase64Encoded: String
        let mimeType: String?
    }

    struct ImagenError: Decodable, Sendable {
        let message: String
        let code: Int?
    }
}

// MARK: - NanoBanana Service (Gemini 3 Pro Image)

final class NanoBananaService: ImageGenerationServiceProtocol, Sendable {
    private let apiKey: String
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta"
    private let model = "gemini-3-pro-image-preview"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func generateImage(prompt: String, size: CGSize, referenceImages: [ReferenceImage] = []) async throws -> Data {
        guard !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }

        // Build endpoint URL
        guard let endpoint = URL(string: "\(baseURL)/models/\(model):generateContent") else {
            throw AIServiceError.invalidResponse
        }

        // Build request with API key in header
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = 180

        // Build parts array with reference images and prompt
        var parts: [GeminiRequest.GeminiPart] = []

        // Add reference images first
        for refImage in referenceImages {
            parts.append(GeminiRequest.GeminiPart(imageData: refImage.data, mimeType: refImage.mimeType))
        }

        // Build the comic panel prompt
        // Separate background from character reference
        let backgroundRefs = referenceImages.filter { $0.name.hasPrefix("background_") }
        let characterRef = referenceImages.first { $0.name == "characters_reference" }

        var enhancedPrompt = """
        Génère une CASE DE BANDE DESSINÉE (comic panel) au format paysage 16:9 (1920x1080).

        """

        // Add character reference instruction - CRITICAL for consistency
        if characterRef != nil {
            enhancedPrompt += """
        ⚠️ INSTRUCTION CRITIQUE - COHÉRENCE DES PERSONNAGES :
        L'IMAGE DE RÉFÉRENCE fournie montre EXACTEMENT les personnages à reproduire.

        TU DOIS IMPÉRATIVEMENT :
        1. COPIER EXACTEMENT l'apparence de chaque personnage (même visage, mêmes couleurs, mêmes vêtements, même style de dessin)
        2. GARDER les mêmes proportions et caractéristiques distinctives
        3. REPRODUIRE le même style graphique cartoon que l'image de référence
        4. INCLURE TOUS les personnages de la référence dans chaque image

        SEULE DIFFÉRENCE AUTORISÉE : les poses et expressions peuvent varier selon le dialogue.

        C'EST UNE SÉRIE D'IMAGES - La cohérence visuelle entre les images est ESSENTIELLE.

        """
        }

        // Add background instruction - STRONG emphasis
        if !backgroundRefs.isEmpty {
            if characterRef != nil {
                // For slide images: use background image, IGNORE background from reference image
                enhancedPrompt += """
                ⚠️ INSTRUCTION CRITIQUE - ARRIÈRE-PLAN :
                Une image de FOND est fournie séparément (en plus de l'image de référence des personnages).
                Tu DOIS utiliser UNIQUEMENT cette image de fond comme arrière-plan.
                IGNORE l'arrière-plan visible dans l'image de référence des personnages.
                Reproduis EXACTEMENT le décor de l'image de fond fournie.

                """
            } else {
                // For reference image: use background image strictly
                enhancedPrompt += """
                ⚠️ INSTRUCTION CRITIQUE - ARRIÈRE-PLAN :
                Une image de FOND est fournie. Tu DOIS reproduire EXACTEMENT cet arrière-plan.
                NE PAS inventer un autre décor. Copie fidèlement le fond de l'image fournie.
                Les personnages doivent être placés DEVANT ce décor.

                """
            }
        }

        // Add the scene description (dialogue, speaker, action)
        enhancedPrompt += """
        SCÈNE À ILLUSTRER :
        \(prompt)

        STYLE : Bande dessinée cartoon, couleurs vives, traits expressifs.
        """

        // Only add speech bubble instruction for slide images (when character reference exists)
        // Reference images should NOT have speech bubbles
        if characterRef != nil {
            enhancedPrompt += """

            BULLE DE DIALOGUE : Ajoute une bulle de BD pointant vers le personnage qui parle.
            COMPOSITION : Plan moyen montrant tous les personnages en interaction.
            """
        } else {
            enhancedPrompt += """

            ⚠️ NE PAS AJOUTER de bulle de dialogue, de texte ou d'onomatopée.
            COMPOSITION : Les personnages sont présentés clairement, visibles en entier.
            """
        }

        parts.append(GeminiRequest.GeminiPart(text: enhancedPrompt))

        let geminiRequest = GeminiRequest(
            contents: [
                GeminiRequest.GeminiContent(parts: parts)
            ],
            generationConfig: GeminiRequest.GeminiGenerationConfig(
                responseModalities: ["IMAGE"]
            )
        )

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(geminiRequest)

        // Send request
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180
        config.timeoutIntervalForResource = 300
        let session = URLSession(configuration: config)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.apiError("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }

        // Decode response
        let decoder = JSONDecoder()
        let geminiResponse = try decoder.decode(GeminiResponse.self, from: data)

        // Check for API error
        if let error = geminiResponse.error {
            throw AIServiceError.apiError(error.message)
        }

        // Extract image data
        guard let candidates = geminiResponse.candidates,
              let content = candidates.first?.content,
              let parts = content.parts else {
            throw AIServiceError.invalidResponse
        }

        for part in parts {
            if let inlineData = part.inlineData,
               let imageData = Data(base64Encoded: inlineData.data) {
                return imageData
            }
        }

        throw AIServiceError.invalidResponse
    }
}

// MARK: - Mock Service for Development

final class MockImageGenerationService: ImageGenerationServiceProtocol, Sendable {
    func generateImage(prompt: String, size: CGSize, referenceImages: [ReferenceImage] = []) async throws -> Data {
        // Simulate network delay
        try await Task.sleep(for: .seconds(1))

        // Create a placeholder image
        let image = NSImage(size: size)
        image.lockFocus()

        // Background gradient
        let gradient = NSGradient(colors: [
            NSColor.systemIndigo.withAlphaComponent(0.6),
            NSColor.systemPurple.withAlphaComponent(0.4)
        ])
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: 45)

        // Text
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 20, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]

        let shortPrompt = String(prompt.prefix(50)) + (prompt.count > 50 ? "..." : "")
        let text = "Image Placeholder\n\n\(shortPrompt)"
        let textRect = NSRect(x: 40, y: size.height / 2 - 40, width: size.width - 80, height: 80)
        text.draw(in: textRect, withAttributes: attributes)

        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw AIServiceError.invalidResponse
        }

        return pngData
    }
}
