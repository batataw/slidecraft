//
//  ChatGPTService.swift
//  SlideCraft
//

import Foundation

final class ChatGPTService: AIServiceProtocol, Sendable {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-4o"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Generate Complete Scenario

    func generateScenario(subject: String, characters: [CharacterInfo]) async throws -> CarouselScenario {
        let charactersList = characters.map { "\($0.name) (\($0.role.displayName) - \($0.role.description))" }.joined(separator: ", ")

        let systemPrompt = """
        Tu es un scénariste créatif spécialisé dans les carrousels éducatifs visuels de style BD/cartoon.

        Tu crées des dialogues entre les personnages fournis pour expliquer un sujet de manière engageante.

        RÈGLES IMPORTANTES :
        1. Utilise UNIQUEMENT les personnages fournis avec leurs rôles
        2. Définis UN lieu/décor unique adapté au sujet
        3. Crée entre 6 et 8 slides de dialogue
        4. Chaque slide contient UN dialogue court (max 15 mots)
        5. Format du dialogue : "Nom: dialogue" (ex: "Marie: C'est fascinant !")
        6. Le dialogue doit raconter une histoire avec début, développement et conclusion
        7. RÔLES DES PERSONNAGES :
           - Le Candide pose les questions naïves (personnage principal, présent dans la majorité des slides)
           - Le Guide explique et répond aux questions (personnage principal, présent dans la majorité des slides)
           - Le Joker apporte l'humour (OPTIONNEL - n'intervient que 1-2 fois si présent, pour détendre l'atmosphère)

        Réponds UNIQUEMENT avec du JSON valide, sans autre texte.
        """

        let userPrompt = """
        Crée un scénario de carrousel sur le sujet suivant : "\(subject)"

        PERSONNAGES À UTILISER : \(charactersList)

        Réponds avec cette structure JSON exacte :
        {
            "setting": "Description détaillée du lieu/décor unique adapté au sujet",
            "characters": "Rappel des personnages utilisés",
            "slides": [
                {"text": "Nom: Premier dialogue..."},
                {"text": "Nom: Deuxième dialogue..."},
                ...
            ]
        }
        """

        let response = try await sendRequest(systemPrompt: systemPrompt, userPrompt: userPrompt)
        return try decodeJSON(CarouselScenario.self, from: response)
    }

    // MARK: - Regenerate Complete Scenario

    func regenerateScenario(subject: String, characters: [CharacterInfo], currentSlides: [String], feedback: String) async throws -> CarouselScenario {
        let charactersList = characters.map { "\($0.name) (\($0.role.displayName))" }.joined(separator: ", ")

        let systemPrompt = """
        Tu es un scénariste créatif spécialisé dans les carrousels éducatifs visuels de style BD/cartoon.

        Tu crées des dialogues entre les personnages fournis pour expliquer un sujet de manière engageante.

        RÈGLES IMPORTANTES :
        1. Utilise UNIQUEMENT les personnages fournis
        2. Définis UN lieu/décor unique adapté au sujet
        3. Crée entre 6 et 8 slides de dialogue
        4. Chaque slide contient UN dialogue court (max 15 mots)
        5. Format du dialogue : "Nom: dialogue"
        6. Le dialogue doit raconter une histoire avec début, développement et conclusion
        7. RÔLES DES PERSONNAGES :
           - Le Candide pose les questions naïves (personnage principal)
           - Le Guide explique et répond (personnage principal)
           - Le Joker apporte l'humour (OPTIONNEL - n'intervient que 1-2 fois si présent)

        Réponds UNIQUEMENT avec du JSON valide, sans autre texte.
        """

        let currentSlidesText = currentSlides.enumerated().map { "Slide \($0 + 1): \($1)" }.joined(separator: "\n")

        let userPrompt = """
        Réécris complètement le scénario du carrousel sur le sujet : "\(subject)"

        PERSONNAGES : \(charactersList)

        Voici le scénario actuel :
        \(currentSlidesText)

        CONSIGNE DE L'UTILISATEUR : "\(feedback)"

        Génère un nouveau scénario qui tient compte de cette consigne.

        Réponds avec cette structure JSON exacte :
        {
            "setting": "Description détaillée du lieu/décor unique",
            "characters": "Rappel des personnages utilisés",
            "slides": [
                {"text": "Nom: Premier dialogue..."},
                {"text": "Nom: Deuxième dialogue..."},
                ...
            ]
        }
        """

        let response = try await sendRequest(systemPrompt: systemPrompt, userPrompt: userPrompt)
        return try decodeJSON(CarouselScenario.self, from: response)
    }

    // MARK: - Regenerate Slide Text

    func regenerateSlideText(subject: String, currentText: String, feedback: String, allSlides: [String], slideIndex: Int, setting: String?) async throws -> String {
        let systemPrompt = """
        Tu es un scénariste créatif spécialisé dans les dialogues de bande dessinée éducative.
        Tu dois réécrire UN dialogue spécifique en tenant compte du feedback utilisateur.

        RÈGLES STRICTES :
        - Maximum 15 mots pour le dialogue
        - Format : "NomPersonnage: dialogue"
        - Garde le même personnage que dans le texte original (sauf si le feedback demande de changer)
        - Le nouveau dialogue doit s'intégrer parfaitement dans l'histoire complète
        - Vocabulaire simple et accessible
        - Maintiens la cohérence narrative avec les slides précédents et suivants

        Réponds UNIQUEMENT avec le nouveau dialogue au format "Nom: texte", rien d'autre.
        """

        let slidesContext = allSlides.enumerated().map { index, text in
            if index == slideIndex {
                return "→ Slide \(index + 1) (À MODIFIER): \(text)"
            } else {
                return "  Slide \(index + 1): \(text)"
            }
        }.joined(separator: "\n")

        var userPrompt = """
        SUJET DU CARROUSEL : "\(subject)"
        """

        if let setting = setting, !setting.isEmpty {
            userPrompt += "\nDÉCOR : \(setting)"
        }

        userPrompt += """


        HISTOIRE COMPLÈTE (le slide à modifier est marqué avec →) :
        \(slidesContext)

        SLIDE À RÉGÉNÉRER : Slide \(slideIndex + 1)
        TEXTE ACTUEL : "\(currentText)"

        DEMANDE DE L'UTILISATEUR : "\(feedback)"

        Génère un nouveau dialogue pour ce slide qui :
        1. Répond à la demande de l'utilisateur
        2. S'intègre parfaitement dans le fil de l'histoire
        3. Reste cohérent avec ce qui précède et ce qui suit
        """

        return try await sendRequest(systemPrompt: systemPrompt, userPrompt: userPrompt)
    }

    // MARK: - Generate Visual Prompt

    func generateVisualPrompt(slideText: String, slideIndex: Int, totalSlides: Int, subject: String, setting: String) async throws -> String {
        // Parse the dialogue to extract speaker and text
        let speakerName = slideText.components(separatedBy: ":").first?.trimmingCharacters(in: .whitespaces) ?? ""
        let dialogueContent = slideText.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)

        // Create a simple, direct prompt for the image generator
        let prompt = """
        Case de bande dessinée.
        Personnage : \(speakerName)
        Bulle de dialogue : "\(dialogueContent)"
        Action : \(speakerName) parle avec expression.
        """

        return prompt
    }

    // MARK: - Generate Social Content

    func generateSocialContent(subject: String, slides: [String]) async throws -> SocialContent {
        let systemPrompt = """
        Tu es un expert en marketing digital et réseaux sociaux, spécialisé dans le contenu viral.
        Tu génères des titres et descriptions pour des publications de carrousels éducatifs.

        RÈGLES POUR LE TITRE (style putaclic/clickbait) :
        1. TRÈS accrocheur, crée de la curiosité ou de l'urgence
        2. Utilise des techniques putaclic : "Ce que personne ne vous dit sur...", "La vérité sur...", "Vous ne devinerez jamais...", "X choses que...", "Pourquoi..."
        3. Peut inclure des chiffres ("5 secrets", "La règle n°1")
        4. Crée un sentiment de FOMO ou de révélation
        5. 1-2 emojis accrocheurs (🔥💡🚨⚡️🤯)
        6. Maximum 15 mots

        RÈGLES POUR LA DESCRIPTION (doit être standalone, indépendante du titre) :
        1. DOIT mentionner/reprendre le sujet clairement (la description se suffit à elle-même)
        2. Engageante, donne envie de scroller le carrousel
        3. 2-3 phrases maximum
        4. Emojis pertinents
        5. Termine avec 5-8 hashtags populaires

        Réponds UNIQUEMENT avec du JSON valide, sans autre texte.
        """

        let slidesText = slides.enumerated().map { "Slide \($0 + 1): \($1)" }.joined(separator: "\n")

        let userPrompt = """
        Génère un titre et une description pour les réseaux sociaux pour ce carrousel éducatif.

        SUJET : "\(subject)"

        CONTENU DES SLIDES :
        \(slidesText)

        Réponds avec cette structure JSON exacte :
        {
            "title": "Le titre accrocheur ici",
            "description": "La description avec emojis... #hashtag1 #hashtag2 ..."
        }
        """

        let response = try await sendRequest(systemPrompt: systemPrompt, userPrompt: userPrompt)
        return try decodeJSON(SocialContent.self, from: response)
    }

    // MARK: - Private Methods

    private func sendRequest(systemPrompt: String, userPrompt: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.7
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.apiError("Status \(httpResponse.statusCode): \(errorMessage)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        var cleanedString = string
        if cleanedString.hasPrefix("```json") {
            cleanedString = String(cleanedString.dropFirst(7))
        }
        if cleanedString.hasPrefix("```") {
            cleanedString = String(cleanedString.dropFirst(3))
        }
        if cleanedString.hasSuffix("```") {
            cleanedString = String(cleanedString.dropLast(3))
        }
        cleanedString = cleanedString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanedString.data(using: .utf8) else {
            throw AIServiceError.invalidResponse
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(type, from: data)
        } catch {
            throw AIServiceError.decodingError(error)
        }
    }
}
