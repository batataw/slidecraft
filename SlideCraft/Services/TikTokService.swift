//
//  TikTokService.swift
//  SlideCraft
//

import Foundation
import AuthenticationServices
import CommonCrypto

// MARK: - Errors

enum TikTokError: LocalizedError {
    case notAuthenticated
    case authenticationFailed(String)
    case tokenRefreshFailed
    case uploadFailed(String)
    case networkError(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Non connecté à TikTok. Connectez-vous dans les Réglages."
        case .authenticationFailed(let message):
            return "Échec de l'authentification: \(message)"
        case .tokenRefreshFailed:
            return "Session expirée. Reconnectez-vous dans les Réglages."
        case .uploadFailed(let message):
            return "Échec de la publication: \(message)"
        case .networkError(let error):
            return "Erreur réseau: \(error.localizedDescription)"
        case .invalidResponse:
            return "Réponse invalide du serveur TikTok"
        }
    }
}

// MARK: - Protocol

protocol TikTokServiceProtocol: Sendable {
    var isAuthenticated: Bool { get }
    var username: String? { get }
    func authenticate() async throws
    func disconnect()
    func publishCarousel(images: [URL], title: String, description: String) async throws -> String
}

// MARK: - Implementation

final class TikTokService: TikTokServiceProtocol, @unchecked Sendable {

    // TODO: Replace with your TikTok app credentials
    private let clientKey = "YOUR_TIKTOK_CLIENT_KEY"
    private let clientSecret = "YOUR_TIKTOK_CLIENT_SECRET"
    private let redirectURI = "slidecraft://tiktok/callback"

    private let keychain = KeychainService.shared

    var isAuthenticated: Bool {
        keychain.hasKey(.tiktokAccessToken)
    }

    var username: String? {
        isAuthenticated ? "@utilisateur" : nil
    }

    // MARK: - Authentication

    func authenticate() async throws {
        let state = UUID().uuidString
        let codeVerifier = generateCodeVerifier()
        let codeChallenge = generateCodeChallenge(from: codeVerifier)

        var components = URLComponents(string: "https://www.tiktok.com/v2/auth/authorize/")!
        components.queryItems = [
            URLQueryItem(name: "client_key", value: clientKey),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "user.info.basic,video.publish"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]

        guard let authURL = components.url else {
            throw TikTokError.authenticationFailed("URL invalide")
        }

        let callbackURL = try await performOAuth(url: authURL)

        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              let returnedState = components.queryItems?.first(where: { $0.name == "state" })?.value,
              returnedState == state else {
            throw TikTokError.authenticationFailed("Paramètres de callback invalides")
        }

        try await exchangeCodeForToken(code: code, codeVerifier: codeVerifier)
    }

    func disconnect() {
        keychain.delete(key: .tiktokAccessToken)
        keychain.delete(key: .tiktokRefreshToken)
        keychain.delete(key: .tiktokOpenId)
    }

    // MARK: - Publishing

    func publishCarousel(images: [URL], title: String, description: String) async throws -> String {
        guard isAuthenticated else {
            throw TikTokError.notAuthenticated
        }

        try await refreshTokenIfNeeded()

        guard let accessToken = keychain.get(key: .tiktokAccessToken),
              let openId = keychain.get(key: .tiktokOpenId) else {
            throw TikTokError.notAuthenticated
        }

        let postId = try await initializePhotoPost(
            accessToken: accessToken,
            openId: openId,
            title: title,
            description: description,
            photoCount: images.count
        )

        for (index, imageURL) in images.enumerated() {
            try await uploadImage(
                accessToken: accessToken,
                postId: postId,
                imageURL: imageURL,
                index: index
            )
        }

        try await finalizePost(accessToken: accessToken, postId: postId)

        return postId
    }

    // MARK: - Private Helpers

    @MainActor
    private func performOAuth(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: "slidecraft"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: TikTokError.authenticationFailed(error.localizedDescription))
                } else if let callbackURL = callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: TikTokError.authenticationFailed("Pas de callback"))
                }
            }

            session.presentationContextProvider = PresentationContextProvider.shared
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }
    }

    private func exchangeCodeForToken(code: String, codeVerifier: String) async throws {
        var request = URLRequest(url: URL(string: "https://open.tiktokapis.com/v2/oauth/token/")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "client_key", value: clientKey),
            URLQueryItem(name: "client_secret", value: clientSecret),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_verifier", value: codeVerifier)
        ]

        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TikTokError.authenticationFailed("Échec de l'échange de token")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let accessToken = json?["access_token"] as? String,
              let refreshToken = json?["refresh_token"] as? String,
              let openId = json?["open_id"] as? String else {
            throw TikTokError.invalidResponse
        }

        _ = keychain.save(key: .tiktokAccessToken, value: accessToken)
        _ = keychain.save(key: .tiktokRefreshToken, value: refreshToken)
        _ = keychain.save(key: .tiktokOpenId, value: openId)
    }

    private func refreshTokenIfNeeded() async throws {
        guard let refreshToken = keychain.get(key: .tiktokRefreshToken) else {
            throw TikTokError.notAuthenticated
        }

        var request = URLRequest(url: URL(string: "https://open.tiktokapis.com/v2/oauth/token/")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "client_key", value: clientKey),
            URLQueryItem(name: "client_secret", value: clientSecret),
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken)
        ]

        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            disconnect()
            throw TikTokError.tokenRefreshFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let accessToken = json?["access_token"] as? String {
            _ = keychain.save(key: .tiktokAccessToken, value: accessToken)
        }
        if let newRefreshToken = json?["refresh_token"] as? String {
            _ = keychain.save(key: .tiktokRefreshToken, value: newRefreshToken)
        }
    }

    private func initializePhotoPost(accessToken: String, openId: String, title: String, description: String, photoCount: Int) async throws -> String {
        var request = URLRequest(url: URL(string: "https://open.tiktokapis.com/v2/post/publish/content/init/")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "post_info": [
                "title": title,
                "description": description,
                "disable_comment": false,
                "privacy_level": "PUBLIC_TO_EVERYONE"
            ],
            "source_info": [
                "source": "FILE_UPLOAD",
                "photo_cover_index": 0,
                "photo_images": (0..<photoCount).map { _ in ["image_type": "JPEG"] }
            ],
            "post_mode": "DIRECT_POST",
            "media_type": "PHOTO"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TikTokError.uploadFailed("Échec de l'initialisation")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let dataDict = json?["data"] as? [String: Any],
              let publishId = dataDict["publish_id"] as? String else {
            throw TikTokError.invalidResponse
        }

        return publishId
    }

    private func uploadImage(accessToken: String, postId: String, imageURL: URL, index: Int) async throws {
        let imageData = try Data(contentsOf: imageURL)

        var request = URLRequest(url: URL(string: "https://open.tiktokapis.com/v2/post/publish/content/upload/")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"publish_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(postId)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image_index\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(index)\r\n".data(using: .utf8)!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"slide_\(index).jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TikTokError.uploadFailed("Échec de l'upload de l'image \(index + 1)")
        }
    }

    private func finalizePost(accessToken: String, postId: String) async throws {
        var request = URLRequest(url: URL(string: "https://open.tiktokapis.com/v2/post/publish/status/fetch/")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = ["publish_id": postId]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        for _ in 0..<30 {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw TikTokError.uploadFailed("Échec de la vérification du statut")
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let dataDict = json?["data"] as? [String: Any],
               let status = dataDict["status"] as? String {
                if status == "PUBLISH_COMPLETE" {
                    return
                } else if status == "FAILED" {
                    let reason = dataDict["fail_reason"] as? String ?? "Raison inconnue"
                    throw TikTokError.uploadFailed(reason)
                }
            }

            try await Task.sleep(nanoseconds: 2_000_000_000)
        }

        throw TikTokError.uploadFailed("Timeout lors de la publication")
    }

    // MARK: - PKCE Helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Presentation Context Provider

private class PresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = PresentationContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow ?? ASPresentationAnchor()
    }
}
