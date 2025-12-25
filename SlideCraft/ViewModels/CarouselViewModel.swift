//
//  CarouselViewModel.swift
//  SlideCraft
//

import Foundation
import SwiftUI
import SwiftData

@Observable
final class CarouselViewModel {
    // MARK: - State

    var currentCarousel: Carousel?
    var currentSlideIndex: Int = 0
    var isGenerating: Bool = false
    var generationProgress: String = ""
    var errorMessage: String?

    // For text validation
    var feedbackText: String = ""

    // For character selection
    var selectedCharacters: [Character] = []

    // For background selection
    var selectedBackground: Background?

    // For social content
    var socialContent: SocialContent?
    var isGeneratingSocialContent: Bool = false

    // MARK: - Services

    private let aiService: AIServiceProtocol
    private let imageService: ImageGenerationServiceProtocol

    // MARK: - Computed Properties

    var currentSlide: Slide? {
        guard let carousel = currentCarousel,
              currentSlideIndex < carousel.slides.count else { return nil }
        return carousel.sortedSlides[currentSlideIndex]
    }

    var allSlidesValidated: Bool {
        currentCarousel?.allTextsValidated ?? false
    }

    var canExport: Bool {
        currentCarousel?.isComplete ?? false
    }

    var validationProgress: String {
        guard let carousel = currentCarousel else { return "" }
        let validated = carousel.slides.filter { $0.isValidated }.count
        return "\(validated)/\(carousel.slides.count)"
    }

    // MARK: - Initialization

    init(
        aiService: AIServiceProtocol? = nil,
        imageService: ImageGenerationServiceProtocol? = nil
    ) {
        self.aiService = aiService ?? ChatGPTService(apiKey: "")
        self.imageService = imageService ?? MockImageGenerationService()
    }

    // MARK: - Carousel Creation

    func createCarousel(subject: String, context: ModelContext) async {
        isGenerating = true
        errorMessage = nil
        generationProgress = "Génération du scénario..."

        do {
            let characterInfos = selectedCharacters.map { CharacterInfo(name: $0.name, role: $0.role) }
            let scenario = try await aiService.generateScenario(subject: subject, characters: characterInfos)

            let carousel = Carousel(subject: subject)
            carousel.setting = scenario.setting
            carousel.characters = selectedCharacters
            carousel.background = selectedBackground
            context.insert(carousel)

            for (index, generatedSlide) in scenario.slides.enumerated() {
                let slide = Slide(index: index, text: generatedSlide.text)
                carousel.slides.append(slide)
            }

            carousel.updatedAt = Date()
            try context.save()

            currentCarousel = carousel
            currentSlideIndex = 0

            // Générer l'image de référence des personnages
            generationProgress = "Génération de l'image de référence..."
            try await generateReferenceImage(for: carousel, context: context)

            generationProgress = ""
        } catch {
            errorMessage = error.localizedDescription
            generationProgress = ""
        }

        isGenerating = false
    }

    // MARK: - Reference Image Generation

    private func generateReferenceImage(for carousel: Carousel, context: ModelContext) async throws {
        // Extraire les noms des personnages du dialogue
        let characterNames = extractCharacterNames(from: carousel.sortedSlides)

        // Construire le prompt pour l'image de référence
        let prompt = buildReferenceImagePrompt(
            characters: characterNames,
            setting: carousel.setting ?? "Un décor neutre"
        )

        // Charger l'image de fond si disponible
        var referenceImages: [ReferenceImage] = []
        if let backgroundRef = loadBackgroundReferenceImage(from: carousel.background) {
            referenceImages.append(backgroundRef)
        }

        // Générer l'image
        let imageData = try await imageService.generateImage(
            prompt: prompt,
            size: ExportService.slideSize,
            referenceImages: referenceImages
        )

        // Sauvegarder l'image
        let fileName = "reference_\(carousel.id.uuidString).png"
        let imageURL = getImagesDirectory().appendingPathComponent(fileName)
        try imageData.write(to: imageURL)

        carousel.referenceImagePath = imageURL.path
        carousel.updatedAt = Date()
        try context.save()
    }

    private func extractCharacterNames(from slides: [Slide]) -> [String] {
        var names = Set<String>()
        for slide in slides {
            if let name = slide.text.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces),
               !name.isEmpty {
                names.insert(name)
            }
        }
        return Array(names)
    }

    private func buildReferenceImagePrompt(characters: [String], setting: String) -> String {
        let characterList = characters.joined(separator: ", ")
        let characterCount = characters.count

        return """
        Image de référence pour bande dessinée.

        PERSONNAGES : \(characterCount) personnages nommés \(characterList).
        Ils sont face à face, debout côte à côte, avec des expressions neutres mais amicales.
        Style cartoon/BD, traits expressifs, couleurs vives.

        DÉCOR : \(setting)

        ⚠️ TRÈS IMPORTANT - À NE PAS INCLURE :
        - AUCUNE bulle de dialogue
        - AUCUN texte
        - AUCUNE onomatopée

        C'est une image de PRÉSENTATION des personnages, pas une scène de dialogue.
        Les personnages doivent être clairement visibles et distincts pour servir de référence visuelle.
        Format paysage 16:9.
        """
    }

    func regenerateReferenceImage(context: ModelContext) async {
        guard let carousel = currentCarousel else { return }

        isGenerating = true
        errorMessage = nil
        generationProgress = "Régénération de l'image de référence..."

        do {
            try await generateReferenceImage(for: carousel, context: context)
            generationProgress = ""
        } catch {
            errorMessage = error.localizedDescription
            generationProgress = ""
        }

        isGenerating = false
    }

    // MARK: - Text Validation

    func validateCurrentSlide() {
        guard let slide = currentSlide else { return }
        slide.isValidated = true
        slide.updatedAt = Date()
        moveToNextUnvalidatedSlide()
    }

    func rejectCurrentSlide(feedback: String, context: ModelContext) async {
        guard let carousel = currentCarousel,
              let slide = currentSlide else { return }

        isGenerating = true
        errorMessage = nil
        generationProgress = "Régénération du texte..."

        do {
            let allTexts = carousel.sortedSlides.map { $0.text }
            let newText = try await aiService.regenerateSlideText(
                subject: carousel.subject,
                currentText: slide.text,
                feedback: feedback,
                allSlides: allTexts,
                slideIndex: currentSlideIndex,
                setting: carousel.setting
            )

            slide.text = newText
            slide.isValidated = false // Reset validation after regeneration
            slide.updatedAt = Date()
            try context.save()

            feedbackText = ""
            generationProgress = ""
        } catch {
            errorMessage = error.localizedDescription
            generationProgress = ""
        }

        isGenerating = false
    }

    func regenerateAllSlides(feedback: String, context: ModelContext) async {
        guard let carousel = currentCarousel else { return }

        isGenerating = true
        errorMessage = nil
        generationProgress = "Régénération du scénario complet..."

        do {
            let currentTexts = carousel.sortedSlides.map { $0.text }
            let characterInfos = selectedCharacters.map { CharacterInfo(name: $0.name, role: $0.role) }
            let newScenario = try await aiService.regenerateScenario(
                subject: carousel.subject,
                characters: characterInfos,
                currentSlides: currentTexts,
                feedback: feedback
            )

            // Update setting
            carousel.setting = newScenario.setting

            // Remove old slides
            for slide in carousel.slides {
                context.delete(slide)
            }
            carousel.slides.removeAll()

            // Add new slides
            for (index, generatedSlide) in newScenario.slides.enumerated() {
                let slide = Slide(index: index, text: generatedSlide.text)
                carousel.slides.append(slide)
            }

            carousel.updatedAt = Date()
            try context.save()

            currentSlideIndex = 0
            feedbackText = ""
            generationProgress = ""
        } catch {
            errorMessage = error.localizedDescription
            generationProgress = ""
        }

        isGenerating = false
    }

    private func moveToNextUnvalidatedSlide() {
        guard let carousel = currentCarousel else { return }
        let slides = carousel.sortedSlides

        // Find next unvalidated slide
        for i in (currentSlideIndex + 1)..<slides.count {
            if !slides[i].isValidated {
                currentSlideIndex = i
                return
            }
        }

        // Check from beginning
        for i in 0..<currentSlideIndex {
            if !slides[i].isValidated {
                currentSlideIndex = i
                return
            }
        }
    }

    func selectSlide(at index: Int) {
        currentSlideIndex = index
    }

    // MARK: - Image Generation (Sequential)

    var imageValidationProgress: String {
        guard let carousel = currentCarousel else { return "" }
        let validated = carousel.slides.filter { $0.isImageValidated }.count
        return "\(validated)/\(carousel.slides.count)"
    }

    var allImagesValidated: Bool {
        currentCarousel?.allImagesValidated ?? false
    }

    var hasNoImages: Bool {
        guard let carousel = currentCarousel else { return true }
        return carousel.slides.allSatisfy { $0.imagePath == nil }
    }

    func generatePromptForCurrentSlide(context: ModelContext) async {
        guard let carousel = currentCarousel,
              let slide = currentSlide else { return }

        isGenerating = true
        errorMessage = nil
        generationProgress = "Génération du prompt visuel..."

        do {
            let setting = carousel.setting ?? "Un décor neutre"
            let visualPrompt = try await aiService.generateVisualPrompt(
                slideText: slide.text,
                slideIndex: currentSlideIndex,
                totalSlides: carousel.slides.count,
                subject: carousel.subject,
                setting: setting
            )

            slide.visualPrompt = visualPrompt
            slide.updatedAt = Date()
            try context.save()

            generationProgress = ""
        } catch {
            errorMessage = error.localizedDescription
            generationProgress = ""
        }

        isGenerating = false
    }

    func generateImageForCurrentSlide(prompt: String, context: ModelContext) async {
        guard let carousel = currentCarousel,
              let slide = currentSlide else { return }

        isGenerating = true
        errorMessage = nil
        generationProgress = "Génération de l'image..."

        do {
            // Save the (potentially edited) prompt
            slide.visualPrompt = prompt

            // Charger l'image de référence des personnages + fond
            var referenceImages: [ReferenceImage] = []

            // Ajouter l'image de référence générée (personnages en discussion)
            if let refImage = loadCarouselReferenceImage(from: carousel) {
                referenceImages.append(refImage)
            }

            // Ajouter le fond si disponible
            if let backgroundRef = loadBackgroundReferenceImage(from: carousel.background) {
                referenceImages.append(backgroundRef)
            }

            var imageData = try await imageService.generateImage(
                prompt: prompt,
                size: ExportService.slideSize,
                referenceImages: referenceImages
            )

            // Add page index badge to the image
            // Use the slide's actual index property, not the UI selection index
            let totalSlides = carousel.slides.count
            let slideIndex = slide.index + 1  // slide.index is 0-based
            imageData = addPageIndex(to: imageData, index: slideIndex, total: totalSlides)

            // Save image
            let fileName = "\(slide.id.uuidString).png"
            let imageURL = getImagesDirectory().appendingPathComponent(fileName)
            try imageData.write(to: imageURL)

            slide.imagePath = imageURL.path
            slide.isImageValidated = false // Reset validation when regenerating
            slide.updatedAt = Date()
            try context.save()

            generationProgress = ""
        } catch {
            errorMessage = error.localizedDescription
            generationProgress = ""
        }

        isGenerating = false
    }

    func validateCurrentImage(context: ModelContext) {
        guard let slide = currentSlide else { return }

        slide.isImageValidated = true
        slide.updatedAt = Date()
        try? context.save()

        moveToNextUnvalidatedImage()
    }

    private func moveToNextUnvalidatedImage() {
        guard let carousel = currentCarousel else { return }
        let slides = carousel.sortedSlides

        // Find next unvalidated image
        for i in (currentSlideIndex + 1)..<slides.count {
            if !slides[i].isImageValidated {
                currentSlideIndex = i
                return
            }
        }

        // Check from beginning
        for i in 0..<currentSlideIndex {
            if !slides[i].isImageValidated {
                currentSlideIndex = i
                return
            }
        }
    }

    // MARK: - Batch Image Generation

    func generateAllImages(context: ModelContext) async {
        guard let carousel = currentCarousel else { return }

        isGenerating = true
        errorMessage = nil

        let slides = carousel.sortedSlides
        let totalSlides = slides.count

        // Load reference images (same as single image generation)
        var referenceImages: [ReferenceImage] = []

        // Add the generated reference image (characters in discussion)
        if let refImage = loadCarouselReferenceImage(from: carousel) {
            referenceImages.append(refImage)
        }

        // Add background if available
        if let backgroundRef = loadBackgroundReferenceImage(from: carousel.background) {
            referenceImages.append(backgroundRef)
        }

        for (index, slide) in slides.enumerated() {
            generationProgress = "Image \(index + 1)/\(totalSlides)..."

            do {
                // Use existing prompt or generate one
                let visualPrompt: String
                if let existingPrompt = slide.visualPrompt, !existingPrompt.isEmpty {
                    visualPrompt = existingPrompt
                } else {
                    visualPrompt = generateDefaultPrompt(for: slide, in: carousel)
                }
                slide.visualPrompt = visualPrompt

                // Generate image with reference images
                var imageData = try await imageService.generateImage(
                    prompt: visualPrompt,
                    size: ExportService.slideSize,
                    referenceImages: referenceImages
                )

                // Add page index badge to the image
                // Use the slide's actual index property for consistency
                let slideIndex = slide.index + 1  // slide.index is 0-based
                imageData = addPageIndex(to: imageData, index: slideIndex, total: totalSlides)

                // Save image
                let fileName = "\(slide.id.uuidString).png"
                let imageURL = getImagesDirectory().appendingPathComponent(fileName)
                try imageData.write(to: imageURL)

                slide.imagePath = imageURL.path
                slide.updatedAt = Date()
                try context.save()
            } catch {
                errorMessage = "Erreur slide \(index + 1): \(error.localizedDescription)"
            }
        }

        carousel.updatedAt = Date()
        generationProgress = ""
        isGenerating = false
    }

    private func generateDefaultPrompt(for slide: Slide, in carousel: Carousel) -> String {
        let speakerName = slide.text.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces) ?? ""
        let dialogueContent = slide.text.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)

        // Get all character names from slides
        var allNames = Set<String>()
        for s in carousel.sortedSlides {
            if let name = s.text.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
                allNames.insert(name)
            }
        }
        let otherCharacters = allNames.filter { $0 != speakerName }

        var prompt = """
        ⚠️ INSTRUCTION CRITIQUE - ATTRIBUTION DU DIALOGUE :

        Le personnage nommé "\(speakerName)" est CELUI QUI PARLE.
        LA BULLE DE DIALOGUE doit pointer UNIQUEMENT vers \(speakerName).

        TEXTE DANS LA BULLE : "\(dialogueContent)"
        """

        if !otherCharacters.isEmpty {
            prompt += """


            AUTRES PERSONNAGES : \(otherCharacters.joined(separator: ", "))
            ⚠️ Ces personnages N'ONT PAS de bulle de dialogue. Ils écoutent et réagissent.
            """
        }

        prompt += """


        COMPOSITION : \(speakerName) est mis en avant, bouche ouverte en train de parler.
        Les autres personnages ont la bouche fermée et écoutent.
        """

        return prompt
    }

    func regenerateImage(for slide: Slide, context: ModelContext) async {
        guard let carousel = currentCarousel,
              let visualPrompt = slide.visualPrompt else { return }

        isGenerating = true
        errorMessage = nil
        generationProgress = "Régénération de l'image..."

        do {
            // Load character reference images
            let referenceImages = loadCharacterReferenceImages(from: carousel.characters)

            let imageData = try await imageService.generateImage(
                prompt: visualPrompt,
                size: ExportService.slideSize,
                referenceImages: referenceImages
            )

            let fileName = "\(slide.id.uuidString).png"
            let imageURL = getImagesDirectory().appendingPathComponent(fileName)
            try imageData.write(to: imageURL)

            slide.imagePath = imageURL.path
            slide.updatedAt = Date()
            carousel.updatedAt = Date()
            try context.save()

            generationProgress = ""
        } catch {
            errorMessage = error.localizedDescription
            generationProgress = ""
        }

        isGenerating = false
    }

    private func loadCharacterReferenceImages(from characters: [Character]) -> [ReferenceImage] {
        var referenceImages: [ReferenceImage] = []

        for character in characters {
            guard let imagePath = character.imagePath,
                  let imageData = FileManager.default.contents(atPath: imagePath) else {
                continue
            }

            let mimeType = getMimeType(for: imagePath)
            referenceImages.append(ReferenceImage(
                data: imageData,
                mimeType: mimeType,
                name: character.name
            ))
        }

        return referenceImages
    }

    private func loadBackgroundReferenceImage(from background: Background?) -> ReferenceImage? {
        guard let background = background,
              let imagePath = background.imagePath,
              let imageData = FileManager.default.contents(atPath: imagePath) else {
            return nil
        }

        let mimeType = getMimeType(for: imagePath)
        return ReferenceImage(
            data: imageData,
            mimeType: mimeType,
            name: "background_\(background.name)"
        )
    }

    private func loadCarouselReferenceImage(from carousel: Carousel) -> ReferenceImage? {
        guard let imagePath = carousel.referenceImagePath,
              let imageData = FileManager.default.contents(atPath: imagePath) else {
            return nil
        }

        let mimeType = getMimeType(for: imagePath)
        return ReferenceImage(
            data: imageData,
            mimeType: mimeType,
            name: "characters_reference"
        )
    }

    private func getMimeType(for path: String) -> String {
        if path.lowercased().hasSuffix(".png") {
            return "image/png"
        } else if path.lowercased().hasSuffix(".jpg") || path.lowercased().hasSuffix(".jpeg") {
            return "image/jpeg"
        } else {
            return "image/png"
        }
    }

    // MARK: - Load Existing Carousel

    func loadCarousel(_ carousel: Carousel) {
        currentCarousel = carousel
        currentSlideIndex = 0
        socialContent = nil
    }

    // MARK: - Social Content

    func generateSocialContent() async {
        guard let carousel = currentCarousel else { return }

        isGeneratingSocialContent = true
        errorMessage = nil

        do {
            let slidesTexts = carousel.sortedSlides.map { $0.text }
            socialContent = try await aiService.generateSocialContent(
                subject: carousel.subject,
                slides: slidesTexts
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isGeneratingSocialContent = false
    }

    // MARK: - File Management

    private func getImagesDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let imagesDir = appSupport.appendingPathComponent("SlideCraft/Images")
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        return imagesDir
    }

    // MARK: - Image Processing

    private func addPageIndex(to imageData: Data, index: Int, total: Int) -> Data {
        guard let nsImage = NSImage(data: imageData) else { return imageData }

        let size = nsImage.size
        let newImage = NSImage(size: size)

        newImage.lockFocus()

        // Draw original image
        nsImage.draw(in: NSRect(origin: .zero, size: size))

        // Badge configuration
        let indexText = "\(index)/\(total)"
        let fontSize: CGFloat = size.height * 0.035 // Proportional to image height
        let padding: CGFloat = fontSize * 0.6
        let cornerRadius: CGFloat = fontSize * 0.5
        let margin: CGFloat = size.width * 0.02

        // Text attributes
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]

        let textSize = indexText.size(withAttributes: textAttributes)

        // Badge dimensions
        let badgeWidth = textSize.width + padding * 2
        let badgeHeight = textSize.height + padding * 1.2

        // Position: bottom right with margin
        let badgeX = size.width - badgeWidth - margin
        let badgeY = margin

        let badgeRect = NSRect(x: badgeX, y: badgeY, width: badgeWidth, height: badgeHeight)

        // Draw badge background with shadow
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.shadowBlurRadius = 4
        shadow.set()

        // Badge background - dark semi-transparent with gradient
        let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: cornerRadius, yRadius: cornerRadius)

        // Gradient for modern look
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.2, alpha: 0.85),
            NSColor(calibratedRed: 0.1, green: 0.1, blue: 0.15, alpha: 0.9)
        ])
        gradient?.draw(in: badgePath, angle: 90)

        // Subtle border
        NSColor.white.withAlphaComponent(0.2).setStroke()
        badgePath.lineWidth = 1
        badgePath.stroke()

        // Reset shadow for text
        NSShadow().set()

        // Draw text centered in badge
        let textX = badgeX + (badgeWidth - textSize.width) / 2
        let textY = badgeY + (badgeHeight - textSize.height) / 2
        indexText.draw(at: NSPoint(x: textX, y: textY), withAttributes: textAttributes)

        newImage.unlockFocus()

        // Convert back to PNG data
        guard let tiffData = newImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return imageData
        }

        return pngData
    }
}
